"""Transactional persistence helpers for learner learning records."""

from database import get_connection
from uuid import uuid4


def create_learner(username, language):
    with get_connection() as connection:
        row = connection.execute(
            """
            INSERT INTO resonant.learners (learner_id, username, preferred_language)
            VALUES (%s, %s, %s)
            ON CONFLICT (username) DO UPDATE
            SET preferred_language = EXCLUDED.preferred_language
            RETURNING learner_id, username, preferred_language, created_at
            """,
            (uuid4(), username, language),
        ).fetchone()
        return dict(row)


def get_learner(learner_id):
    with get_connection() as connection:
        row = connection.execute(
            """
            SELECT learner_id, username, preferred_language, created_at
            FROM resonant.learners WHERE learner_id = %s
            """,
            (learner_id,),
        ).fetchone()
        return dict(row) if row else None


def record_practice_attempt(attempt):
    """Insert once by submission UUID and update mastery in the same transaction."""
    with get_connection() as connection:
        row = connection.execute(
            """
            INSERT INTO resonant.practice_attempts (
                submission_id, learner_id, exercise_id, skill_id, language,
                exercise_type, outcome, response_time_ms, hint_used, attempt_number
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (submission_id) DO NOTHING
            RETURNING submission_id, attempt_id, learner_id, exercise_id,
                skill_id, language, exercise_type, outcome, response_time_ms,
                hint_used, attempt_number, created_at
            """,
            (
                attempt.submission_id,
                attempt.learner_id,
                attempt.exercise_id,
                attempt.skill_id,
                attempt.language,
                attempt.exercise_type,
                attempt.outcome,
                attempt.response_time_ms,
                attempt.hint_used,
                attempt.attempt_number,
            ),
        ).fetchone()

        if row is None:
            existing = connection.execute(
                """
                SELECT submission_id, attempt_id, learner_id, exercise_id,
                    skill_id, language, exercise_type, outcome, response_time_ms,
                    hint_used, attempt_number, created_at
                FROM resonant.practice_attempts WHERE submission_id = %s
                """,
                (attempt.submission_id,),
            ).fetchone()
            return {**dict(existing), "duplicate": True}

        if attempt.outcome in {"correct", "incorrect"}:
            correct = int(attempt.outcome == "correct")
            connection.execute(
                """
                INSERT INTO resonant.skill_progress (
                    learner_id, skill_id, language, attempts, correct_count,
                    mastery, average_response_ms, next_review_at, updated_at
                ) VALUES (
                    %s, %s, %s, 1, %s, (%s + 1)::numeric / 3,
                    %s, now() + CASE WHEN %s = 1 THEN interval '1 day'
                        ELSE interval '0 days' END, now()
                )
                ON CONFLICT (learner_id, skill_id) DO UPDATE SET
                    attempts = resonant.skill_progress.attempts + 1,
                    correct_count = resonant.skill_progress.correct_count + EXCLUDED.correct_count,
                    language = EXCLUDED.language,
                    mastery = (
                        resonant.skill_progress.correct_count + EXCLUDED.correct_count + 1
                    )::numeric / (resonant.skill_progress.attempts + 3),
                    average_response_ms = (
                        resonant.skill_progress.average_response_ms
                        * resonant.skill_progress.attempts + EXCLUDED.average_response_ms
                    ) / (resonant.skill_progress.attempts + 1),
                    next_review_at = now() + CASE
                        WHEN (
                            resonant.skill_progress.correct_count + EXCLUDED.correct_count + 1
                        )::numeric / (resonant.skill_progress.attempts + 3) < 0.5
                            THEN interval '0 days'
                        WHEN (
                            resonant.skill_progress.correct_count + EXCLUDED.correct_count + 1
                        )::numeric / (resonant.skill_progress.attempts + 3) < 0.8
                            THEN interval '1 day'
                        ELSE interval '3 days'
                    END,
                    updated_at = now()
                """,
                (
                    attempt.learner_id,
                    attempt.skill_id,
                    attempt.language,
                    correct,
                    correct,
                    attempt.response_time_ms,
                    correct,
                ),
            )
        return {**dict(row), "duplicate": False}


def record_quiz_result(result):
    with get_connection() as connection:
        row = connection.execute(
            """
            INSERT INTO resonant.quiz_results (
                submission_id, learner_id, quiz_id, language,
                score, max_score, duration_ms
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (submission_id) DO NOTHING
            RETURNING submission_id, quiz_result_id, learner_id, quiz_id,
                language, score, max_score, duration_ms, completed_at
            """,
            (
                result.submission_id,
                result.learner_id,
                result.quiz_id,
                result.language,
                result.score,
                result.max_score,
                result.duration_ms,
            ),
        ).fetchone()
        if row is not None:
            return {**dict(row), "duplicate": False}
        existing = connection.execute(
            """
            SELECT submission_id, quiz_result_id, learner_id, quiz_id,
                language, score, max_score, duration_ms, completed_at
            FROM resonant.quiz_results WHERE submission_id = %s
            """,
            (result.submission_id,),
        ).fetchone()
        return {**dict(existing), "duplicate": True}


def get_skill_progress(learner_id):
    with get_connection() as connection:
        rows = connection.execute(
            """
            SELECT skill_id, language, attempts, correct_count, mastery,
                average_response_ms, next_review_at, updated_at
            FROM resonant.skill_progress
            WHERE learner_id = %s
            ORDER BY skill_id
            """,
            (learner_id,),
        ).fetchall()
        return [dict(row) for row in rows]

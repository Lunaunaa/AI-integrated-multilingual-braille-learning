CREATE TABLE IF NOT EXISTS resonant.learners (
    learner_id UUID PRIMARY KEY,
    username TEXT NOT NULL UNIQUE CHECK (length(trim(username)) BETWEEN 1 AND 100),
    preferred_language TEXT NOT NULL CHECK (preferred_language IN ('English', 'Hindi', 'Kannada')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resonant.practice_attempts (
    attempt_id BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    submission_id UUID PRIMARY KEY,
    learner_id UUID NOT NULL REFERENCES resonant.learners(learner_id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL CHECK (length(exercise_id) BETWEEN 1 AND 120),
    skill_id TEXT NOT NULL CHECK (length(skill_id) BETWEEN 1 AND 120),
    language TEXT NOT NULL CHECK (language IN ('English', 'Hindi', 'Kannada')),
    exercise_type TEXT NOT NULL CHECK (length(exercise_type) BETWEEN 1 AND 40),
    outcome TEXT NOT NULL CHECK (outcome IN ('correct', 'incorrect', 'cancelled', 'accidental_touch', 'timeout')),
    response_time_ms INTEGER NOT NULL CHECK (response_time_ms >= 0),
    hint_used BOOLEAN NOT NULL DEFAULT FALSE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS practice_attempts_learner_time_idx
    ON resonant.practice_attempts (learner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS practice_attempts_learner_skill_time_idx
    ON resonant.practice_attempts (learner_id, skill_id, created_at DESC);

CREATE TABLE IF NOT EXISTS resonant.quiz_results (
    quiz_result_id BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    submission_id UUID PRIMARY KEY,
    learner_id UUID NOT NULL REFERENCES resonant.learners(learner_id) ON DELETE CASCADE,
    quiz_id TEXT NOT NULL CHECK (length(quiz_id) BETWEEN 1 AND 120),
    language TEXT NOT NULL CHECK (language IN ('English', 'Hindi', 'Kannada')),
    score INTEGER NOT NULL CHECK (score >= 0),
    max_score INTEGER NOT NULL CHECK (max_score > 0 AND score <= max_score),
    duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS quiz_results_learner_time_idx
    ON resonant.quiz_results (learner_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS resonant.skill_progress (
    learner_id UUID NOT NULL REFERENCES resonant.learners(learner_id) ON DELETE CASCADE,
    skill_id TEXT NOT NULL CHECK (length(skill_id) BETWEEN 1 AND 120),
    language TEXT NOT NULL CHECK (language IN ('English', 'Hindi', 'Kannada')),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    correct_count INTEGER NOT NULL DEFAULT 0 CHECK (correct_count >= 0 AND correct_count <= attempts),
    mastery NUMERIC(6, 5) NOT NULL DEFAULT 0 CHECK (mastery BETWEEN 0 AND 1),
    average_response_ms NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (average_response_ms >= 0),
    next_review_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (learner_id, skill_id)
);

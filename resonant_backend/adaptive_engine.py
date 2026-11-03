
from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class SkillProgress:
    skill_id: str
    attempts: int = 0
    correct: int = 0
    mastery: float = 0.0
    average_response_time: float = 0.0
    next_review: datetime | None = None


@dataclass
class LearnerModel:
    learner_id: str
    skills: dict[str, SkillProgress] = field(default_factory=dict)

    def record_attempt(
        self,
        skill_id: str,
        is_correct: bool,
        response_time: float,
    ) -> SkillProgress:

        if response_time < 0:
            raise ValueError("Response time cannot be negative.")

        skill = self.skills.setdefault(
            skill_id,
            SkillProgress(skill_id=skill_id),
        )

        previous_attempts = skill.attempts
        skill.attempts += 1

        if is_correct:
            skill.correct += 1

        # Update average response time incrementally.
        skill.average_response_time = (
            skill.average_response_time * previous_attempts
            + response_time
        ) / skill.attempts

        # Initial mastery estimate with smoothing.
        skill.mastery = (
            (skill.correct + 1) / (skill.attempts + 2)
        )

        # Schedule another review based on performance.
        if skill.mastery < 0.5:
            days_until_review = 0
        elif skill.mastery < 0.8:
            days_until_review = 1
        else:
            days_until_review = 3

        from datetime import timedelta

        skill.next_review = (
            datetime.now(timezone.utc)
            + timedelta(days=days_until_review)
        )

        return skill


def recommend_next_skill(
    learner: LearnerModel,
) -> str | None:
    if not learner.skills:
        return None

    # Practise the least-mastered skill first.
    skill = min(
        learner.skills.values(),
        key=lambda item: (
            item.mastery,
            item.next_review or datetime.min.replace(
                tzinfo=timezone.utc
            ),
        ),
    )

    return skill.skill_id

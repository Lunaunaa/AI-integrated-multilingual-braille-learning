"""Deterministic recommendation baseline over stored skill progress."""
from datetime import datetime, timezone


def recommend_from_progress(skills):
    """Return a due, lower-mastery skill without consulting the ML demo model."""
    candidates = [skill for skill in skills if int(skill.get("attempts", 0)) > 0]
    if not candidates:
        return {"skill_id": None, "reason": "no_practice_history", "source": "rule_baseline"}

    now = datetime.now(timezone.utc)

    def is_due(review):
        if review is None:
            return False
        if review.tzinfo is None:
            review = review.replace(tzinfo=timezone.utc)
        return review <= now

    def priority(skill):
        review = skill.get("next_review_at")
        if review is not None and review.tzinfo is None:
            review = review.replace(tzinfo=timezone.utc)
        overdue = is_due(review)
        mastery = float(skill.get("mastery", 0.0))
        return (0 if overdue else 1, mastery, review or now, skill["skill_id"])

    selected = min(candidates, key=priority)
    return {
        "skill_id": selected["skill_id"],
        "reason": "review_due" if is_due(selected.get("next_review_at")) else "lowest_mastery",
        "source": "rule_baseline",
    }

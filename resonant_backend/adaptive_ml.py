"""Optional prediction layer for next-attempt skill correctness.

If a compatible trained model is missing or fails validation, callers receive
the supplied rule-based baseline probability instead.
"""

from pathlib import Path
import math

MODEL_VERSION = 1
FEATURE_NAMES = (
    "recent_accuracy",
    "attempt_count",
    "average_response_seconds",
    "hint_rate",
    "days_since_practice",
    "mastery_estimate",
    "exercise_difficulty",
)


def predict_probability(features, fallback_probability, model_path=None):
    """Return a bounded next-correct probability and its source label."""
    if model_path is None:
        model_path = Path(__file__).parent / "artifacts" / "adaptive_v1.joblib"
    try:
        import joblib

        payload = joblib.load(model_path)
        if payload.get("version") != MODEL_VERSION:
            raise ValueError("Unsupported adaptive model version")
        values = [float(features[name]) for name in FEATURE_NAMES]
        if not all(math.isfinite(value) for value in values):
            raise ValueError("Non-finite model feature")
        probability = float(payload["model"].predict_proba([values])[0][1])
        if not 0.0 <= probability <= 1.0:
            raise ValueError("Invalid probability")
        return {"probability": probability, "source": "model", "version": MODEL_VERSION}
    except (OSError, ImportError, KeyError, TypeError, ValueError, AttributeError):
        try:
            fallback = float(fallback_probability)
            if not math.isfinite(fallback):
                fallback = 0.5
            fallback = min(1.0, max(0.0, fallback))
        except (TypeError, ValueError):
            fallback = 0.5
        return {"probability": fallback, "source": "rule_based", "version": None}

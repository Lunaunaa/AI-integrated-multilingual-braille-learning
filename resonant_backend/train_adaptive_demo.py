"""Train a reproducible synthetic demonstration model (never real data)."""

import json
from pathlib import Path
import random

import joblib
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, log_loss
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from adaptive_ml import FEATURE_NAMES, MODEL_VERSION


SEED = 20261101


def sigmoid(value):
    return 1.0 / (1.0 + __import__("math").exp(-value))


def generate_synthetic_examples(learner_count=240, skills_per_learner=6, attempts=8, seed=SEED):
    rng = random.Random(seed)
    rows, targets, groups = [], [], []
    for learner in range(learner_count):
        learner_ability = rng.gauss(0.0, 0.75)
        for skill in range(skills_per_learner):
            skill_ability = rng.gauss(0.0, 0.65)
            history, response_times, hints = [], [], []
            last_practice_day = 0
            difficulty = rng.uniform(0.0, 1.0)
            for attempt in range(attempts):
                gap_days = 0 if attempt == 0 else rng.randint(0, 10)
                last_practice_day += gap_days
                recent = history[-5:]
                row = {
                    "recent_accuracy": sum(recent) / len(recent) if recent else 0.5,
                    "attempt_count": float(attempt),
                    "average_response_seconds": (
                        sum(response_times) / len(response_times) if response_times else 0.0
                    ),
                    "hint_rate": sum(hints) / len(hints) if hints else 0.0,
                    "days_since_practice": float(gap_days),
                    "mastery_estimate": (sum(history) + 1.0) / (len(history) + 2.0),
                    "exercise_difficulty": difficulty,
                }
                ability = learner_ability + skill_ability
                p_correct = sigmoid(
                    -0.15 + ability + 0.28 * row["mastery_estimate"]
                    + 0.08 * min(attempt, 5) - 1.1 * difficulty
                    - 0.08 * row["hint_rate"] - 0.025 * gap_days
                )
                outcome = 1 if rng.random() < p_correct else 0
                hint_used = 1 if rng.random() < max(0.08, 0.58 - 0.35 * ability) else 0
                response_time = max(2.0, rng.gauss(31.0 - 7.0 * ability + 3.0 * hint_used, 8.0))
                rows.append([row[name] for name in FEATURE_NAMES])
                targets.append(outcome)
                groups.append(learner)
                history.append(outcome)
                hints.append(hint_used)
                response_times.append(response_time)
    return rows, targets, groups


def train_and_evaluate(rows, targets, groups, seed=SEED):
    splitter = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=seed)
    train_indices, test_indices = next(splitter.split(rows, targets, groups))
    x_train = [rows[index] for index in train_indices]
    y_train = [targets[index] for index in train_indices]
    x_test = [rows[index] for index in test_indices]
    y_test = [targets[index] for index in test_indices]

    model = make_pipeline(
        StandardScaler(),
        LogisticRegression(max_iter=1000, random_state=seed),
    )
    model.fit(x_train, y_train)
    predictions = model.predict_proba(x_test)[:, 1]
    baseline_probability = sum(y_train) / len(y_train)
    baseline = [baseline_probability] * len(y_test)
    metrics = {
        "brier_score_model": float(brier_score_loss(y_test, predictions)),
        "brier_score_prevalence_baseline": float(brier_score_loss(y_test, baseline)),
        "log_loss_model": float(log_loss(y_test, predictions, labels=[0, 1])),
        "log_loss_prevalence_baseline": float(log_loss(y_test, baseline, labels=[0, 1])),
        "train_rows": len(train_indices),
        "test_rows": len(test_indices),
        "train_learners": len({groups[index] for index in train_indices}),
        "test_learners": len({groups[index] for index in test_indices}),
    }
    return model, metrics


def main():
    rows, targets, groups = generate_synthetic_examples()
    model, metrics = train_and_evaluate(rows, targets, groups)
    artifacts = Path(__file__).parent / "artifacts"
    artifacts.mkdir(exist_ok=True)
    joblib.dump({"version": MODEL_VERSION, "model": model}, artifacts / "adaptive_v1.joblib")
    report = {
        "source": "synthetic demonstration data; not real learner data",
        "seed": SEED,
        "target": "probability of a correct next attempt for a skill",
        "features": list(FEATURE_NAMES),
        "split": "group holdout by synthetic learner; 75% train / 25% test",
        "model": "StandardScaler + LogisticRegression",
        "metrics": metrics,
        "limitations": [
            "Synthetic patterns do not show real-world learning behavior.",
            "Do not use this artifact to personalize real learners.",
            "Train and evaluate on consented, de-identified practice records before deployment.",
        ],
    }
    report_path = Path(__file__).parents[1] / "docs" / "ml-synthetic-demo.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

# Adaptive learning model status

The backend now contains an isolated, reproducible ML demonstration for the
target “probability that a skill is answered correctly on the next attempt.”
The trainer creates synthetic histories only; it does not read learner data.

Run it from `resonant_backend` with the installed requirements:

```powershell
python train_adaptive_demo.py
```

The script groups the split by synthetic learner (75% train, 25% test), fits a
standardized logistic regression, compares it with a training-prevalence
baseline, and writes `artifacts/adaptive_v1.joblib` plus the report at
`docs/ml-synthetic-demo.json`. Features use prior accuracy, attempt count,
response time, hint rate, days since practice, smoothed mastery, and exercise
difficulty. The held-out set does not share learner IDs with training.

`adaptive_ml.predict_probability` checks the version and feature values and
returns the supplied rule-based probability when the model is missing or
invalid. The model is not yet connected to persisted practice history or a
recommendation API. The synthetic metrics are reproducibility evidence for the
training pipeline only; they are not evidence of real learning effectiveness
and must not drive real learner recommendations.

`recommendation_service.recommend_from_progress` is the deterministic
operational baseline: it selects a due skill first, then lower mastery, and
returns no recommendation for a learner with no answer history. It is unit
tested but not exposed as a learner-specific endpoint because authentication
and authorization are not yet present.

Before using ML for learners, the project still needs consented,
de-identified practice records, data-quality review, chronological or
learner-group evaluation, a production recommendation policy, and validated
fallback behavior. The existing rule-based engine remains the operational
recommendation baseline.

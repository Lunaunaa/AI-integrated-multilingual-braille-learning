# PostgreSQL persistence

## Safe schema boundary

The repository did not contain a schema dump or migration history, and this
environment has no `RESONANT_DATABASE_URL`. To avoid changing unknown legacy
tables, Resonant's new tables live under a separate PostgreSQL schema named
`resonant`. The migration does not drop, rename, or alter `public` tables.

The first migration creates:

- `resonant.learners` — UUID learner ID, username, preferred language, and
  creation time.
- `resonant.practice_attempts` — idempotent event records, including correct,
  incorrect, cancelled, accidental-touch, and timeout outcomes.
- `resonant.quiz_results` — idempotent quiz submissions and scores.
- `resonant.skill_progress` — correct-answer counts, mastery estimate, average
  response time, and next review time.
- `resonant.schema_migrations` — applied migration versions.

Each write uses a psycopg connection context, so the event insert and mastery
update commit or roll back together. Submission UUIDs prevent retries from
creating duplicate attempts or quiz results. Only correct and incorrect
answers affect mastery; interrupted and accidental events remain in history
without being counted as lack of knowledge.

## Configure and migrate

Set `RESONANT_DATABASE_URL` in the backend process environment. Keep real
credentials out of source control and logs. From `resonant_backend`, apply
migrations before starting the API:

```powershell
python -m pip install -r requirements.txt
$env:RESONANT_DATABASE_URL = "postgresql://USER:PASSWORD@HOST:5432/DATABASE"
python migrate.py
python -m uvicorn main:app --reload
```

The migration runner takes a transaction-scoped advisory lock and records each
successful version. The SQL is additive and scoped to `resonant`.

## API routes

- `GET /health` checks application availability without touching dependencies.
- `GET /health/database` checks PostgreSQL availability.
- `POST /learners` creates or updates a learner's preferred language.
- `GET /learners/{learner_id}` reads a learner profile.
- `POST /practice/attempts` records an idempotent practice event and updates
  skill progress for correct/incorrect answers.
- `GET /learners/{learner_id}/progress` reads skill mastery.
- `POST /quizzes/results` records an idempotent quiz result.

Request models validate languages, event types, lengths, score bounds, and
durations. SQL values use parameters. Backend tests mock the database
connection; no PostgreSQL server was available here, so migration execution,
constraints, transaction behavior, and SQL compatibility still require a real
database integration run.

The Flutter app also writes a local JSON event log in application documents
for offline English lesson attempts. It assigns a new UUID to each attempt and
keeps events marked pending; the client does not yet upload them or reconcile
conflicts with this PostgreSQL store.

## Privacy limitation

Learner profile and progress endpoints do not have authentication yet. Keep
this API on a trusted local development network. Do not deploy it or use it for
private learner records until authentication and authorization are added.

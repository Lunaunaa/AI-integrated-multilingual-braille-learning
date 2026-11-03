# Changelog

## Unreleased

- Corrected the landscape keyboard's screen layout to the requested mapping:
  left column dots 1–3 and right column dots 4–6.
- Cancelled an active chord when a pointer is interrupted or dragged into a
  different zone, rather than treating it as a completed multi-dot input.
- Replaced the obsolete counter widget test with keyboard lifecycle tests and
  added initial English uncontracted Braille engine tests.
- Added a standards note documenting the engine's limited scope and the
  verification gap for Hindi and Kannada Braille-to-text behavior.
- Added bounded Ollama health/configuration and a safe offline tutor response.
- Added a grouped, synthetic-only ML training demonstration, saved model
  artifact, evaluation report, and rule-based inference fallback.
- Replaced the static English lesson index with six offline multiple-choice
  exercises, hints, retry feedback, and in-session completion tracking.
- Added a versioned PostgreSQL migration in an isolated `resonant` schema,
  persistence routes for learners, practice attempts, quizzes, and progress,
  plus UUID-based duplicate submission handling and mocked database tests.
- Added separate Hindi and Kannada forward Grade 1 mapping subsets from the
  NIEPVD 2025 Unicode chart, with published-cell fixtures and explicit errors
  for unsupported characters.
- Added durable on-device lesson attempt history with retry-stable event IDs;
  automatic server synchronization remains future work.
- Added an accessible English voice tutor with Android speech-to-text,
  typed fallback, contextual follow-ups, TTS replay/stop, private in-memory
  conversation handling, and backend-side verification for exact letter patterns.
- Added local-only Android cleartext networking for `localhost` to support a
  USB-forwarded phone demo without enabling cleartext to arbitrary hosts.

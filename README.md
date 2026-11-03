# Resonant

Resonant is an early Flutter prototype for audio-guided Braille learning. The
repository currently contains a landscape six-dot keyboard, simple navigation
and settings, and a small FastAPI backend. It is not yet a complete learning
system, and device accessibility and physical hand placement have not been
verified.

## Current status

- The keyboard uses the requested screen mapping: left column dots 1, 2, 3;
  right column dots 4, 5, 6. The screen-to-hand relationship still needs a
  guided calibration and testing on the target phone.
- The initial English engine covers only a documented uncontracted subset.
- Hindi and Kannada have separate forward Grade 1 table subsets checked
  against NIEPVD's official 2025 chart; they are not yet wired into the app
  UI, and full 2.1 comparison and reverse translation are outstanding. Lesson
  attempts persist locally for offline use, but backend sync, full lesson
  coverage, teacher tools, production ML recommendations, and device
  accessibility validation remain outstanding.
- A reproducible synthetic ML training demonstration exists, but it is not
  connected to learner recommendations and its metrics are not real-world
  evidence. See [the ML methodology](docs/adaptive-learning.md).
- See [the standards note](docs/braille-standards.md) for language coverage
  and references, and [the changelog](CHANGELOG.md) for current changes.
- See [the implementation status](docs/project-status.md) for verified
  checkpoints and blockers.

See the [voice tutor notes](docs/voice-tutor.md) for privacy behavior, setup,
language limits, and verification status.

## Run the Flutter app

Install Flutter for this repository's Dart SDK constraint, connect an Android
device or start an emulator, then run:

```powershell
flutter pub get
flutter run
```

The current app requests landscape orientation. System speech and haptic
behavior depend on Android device settings and installed services.

## Voice tutor (English only)

Swipe up in the labelled tutor area on the learning screen to start listening.
TalkBack users can invoke the **Talk to Resonant** custom action. Voice input uses
the device speech service; it may require internet and is not guaranteed to be
offline. Typed questions remain available if microphone permission or
recognition fails. The tutor replies with Android TTS, supports replay and
stop, and keeps the open conversation in memory only. Raw audio is not saved.
Only English voice tutoring is enabled; Hindi and Kannada remain disabled
until their recognition, Braille content, reply quality, and TTS pronunciation
are verified. The API receives the question, current lesson context, and recent
turns for follow-up answers. It receives no learner ID or persisted progress;
the service does not save the conversation.

Run the backend and local Ollama on the development computer. For a USB
connected Android phone, forward the local API port with `adb reverse`:

```powershell
cd resonant_backend
$env:RESONANT_OLLAMA_URL = "http://localhost:11434"
$env:RESONANT_OLLAMA_MODEL = "qwen2.5:0.5b"
uvicorn main:app --host 127.0.0.1 --port 8000
```

In a second terminal, run `adb reverse tcp:8000 tcp:8000`, then install the
debug APK. The app permits cleartext tutor traffic only to `localhost`; use an
HTTPS endpoint if configuring a different API host with
`--dart-define=RESONANT_TUTOR_API_BASE=https://...`.

## Run the backend

Install Python 3.10 or newer and PostgreSQL. Create a database and set the
connection string in the current PowerShell session (do not commit real
credentials):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r resonant_backend\requirements.txt
$env:RESONANT_DATABASE_URL = "postgresql://USER:PASSWORD@HOST:5432/DATABASE"
cd resonant_backend
python migrate.py
uvicorn main:app --reload
```

The API includes learner, attempt, quiz-result, progress, health, and tutor
routes. New database tables are isolated in a `resonant` schema; migration
details and API validation are in [database-and-api.md](docs/database-and-api.md).
Learner endpoints do not yet have authentication and are for trusted local
development only. The tutor defaults to `http://localhost:11434` and
`qwen2.5:0.5b`, configurable through environment variables.

## Checks

```powershell
flutter analyze
flutter test
cd resonant_backend
python -m unittest discover -s tests -v
```

Phone, TalkBack, database, and Ollama integration checks require their
respective environments.


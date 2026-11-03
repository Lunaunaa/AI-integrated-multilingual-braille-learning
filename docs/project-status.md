# Resonant 2.0 implementation status

Status reflects repository work in this checkpoint. â€œTestedâ€ refers only to
automated checks listed below; it does not imply user or device validation.

| Area | Status | Evidence / remaining work |
|---|---|---|
| Six-dot screen mapping | Implemented and automated-tested | App is locked to landscape. Per the latest reference, screen-left is dots 4, 5, 6 top-to-bottom and screen-right is dots 1, 2, 3. The pad is fixed in the available practice area without scroll containers, in touch and screen-reader modes. Physical dot targeting remains unverified. |
| Multi-touch chord collection | Partially implemented | Simultaneous pointers tested. Calibration, sensitivity, and full hand-position setup remain. |
| Drag and cancellation recovery | Implemented and automated-tested | Drag/cancel clears the active chord rather than committing it. |
| Accessible dot entry | Implemented and automated-tested; device verification partial | Six-dot semantic controls announce current selection, expose selected state, support deselection and speak deterministic single-cell decoding. TalkBack use has not been tested on Android. |
| Voice tutor and commands | Implemented; online route and offline fallback tested | Swipe up in the labelled header area to launch the tutor; TalkBack has Talk and Replay Welcome actions. USB `adb reverse` connects the phone to the local API. Verified English words, letters, layout questions and hints fall back to the deterministic local engine when the API is unreachable. General conversation still depends on the configured Ollama model. Compact landscape dialog is widget-tested. Phone microphone/TTS/TalkBack remain unverified. |
| Lesson 1 / onboarding | Implemented and automated-tested; welcome replays once after this upgrade | Ten spoken, persisted steps cover lesson flow and keyboard use. This build advances the onboarding version so existing installs see Welcome Step 1 once; saved lesson attempts remain intact. Swipe navigation works across the welcome content and letter lesson. Finishing Welcome resumes the first unfinished curriculum item. Physical TalkBack remains unverified. |
| English curriculum | Implemented as data and automated-tested; later-stage interaction partial | A–E through U–Z stages remain ordered and checked. Existing letter progression and stage mastery are preserved. Later groups have not each been played end-to-end on device. |
| Chapter 3 word learning | Implemented and automated-tested; full device journey unverified | Five ordered lessons cover CAT/BAT/MAT, SUN/DOG/HAT/PEN, keyboard writing, blind-first read-and-identify, and a five-word test requiring 4/5 first-try success. Attempts, hints, response times and mastery-round IDs use the existing offline store. A CAT write/correction/backspace test validates cells and records progress. The complete unlock journey has not been played on device. |
| Primary navigation / dashboard | Simplified; gesture flow automated-tested, device accessibility unverified | Returning learners first receive the revised Lesson 1, then resume their first unfinished course item. The large dashboard list, repeated global navigation row, and visible tutor button are removed. Swipe up in the labelled header area to open the tutor and start listening; TalkBack custom action is provided. App orientation is locked to landscape. Physical TalkBack and phone rotation remain unverified. |
| Responsive keyboard / visual design | Layout fixes implemented; widget-tested and visually checked on Samsung | Large white circular targets with blue dot numbers match the screenshot order: left 4/5/6, right 1/2/3. The pad fills the practice area without scrolling; status and actions use a compact footer. A clean landscape keyboard screenshot was captured from the Samsung. Enlarged-text/narrow-screen tests pass. Physical vibration feel and TalkBack use remain to be checked. |
| English Braille | Partially implemented | Uncontracted alphabet, digits, indicators, spaces, and selected punctuation only; not full UEB. |
| Hindi and Kannada Braille | Partially implemented | Separate code-level forward Grade 1 tables with NIEPVD 2025 fixtures. Not yet wired into the app UI; direct comparison with 2.1, full sign coverage and reverse translation remain. |
| Lesson progress and resume | Implemented locally and automated-tested | Letter results and per-word test submissions persist in the offline event log. App relaunch selects the first incomplete letter, first unfinished word in the current stage, next stage, or cumulative test. This is device-local only; cross-device/PostgreSQL mastery remains separate and unverified. |
| FastAPI/PostgreSQL persistence | Implemented but not fully tested | Versioned isolated schema and learner/attempt/quiz/progress routes; 7 persistence cases use mocked connections. PostgreSQL migration and real transactions remain unverified. |
| AI tutor provider | Existing Ollama integration; OpenAI configuration blocked | The repository has no `openai.json`; current backend still uses Ollama and its verified retrieval/encoding flow. Do not describe OpenAI as configured until the agreed config file is available and its schema/provider behavior are verified. |
| Tutor Braille word answers | Implemented and backend/gateway-tested | Ollama supplies the teaching sentence; the backend supplies authoritative uncontracted A–Z word cells, per-letter dot positions, capital indicators and ICEB references. Timeout fallback retains the verified answer. Contractions, punctuation and numbers remain unsupported; this is not full UEB. |
| Adaptive recommendations | Partially implemented | Tested rule baseline selects due/low-mastery stored skills; no authenticated recommendation endpoint. Synthetic model remains an isolated experiment, not connected to learner records. |
| Offline synchronization | Partially implemented | Offline event log with unique submission IDs and retry-safe local writes; server sync, acknowledgment, reconnection retries and conflict handling remain. |
| Teacher mode | Not yet implemented | No role/authentication or teacher data flow. |
| Android build | Implemented, built and installed | Latest debug APK built and installed on Samsung SM A176B. It launched successfully in landscape and showed Lesson 1, letter A. |
| Samsung device / TalkBack | Partially verified | Latest build launch and clean keyboard layout were captured on device. Physical dot entry accuracy, word chapter journey, TalkBack, speech and haptic behavior still need device testing. |

## Automated checks run

- `flutter analyze` â€” passed with no issues.
- `flutter test` â€” passed (63 tests).
- `python -m unittest discover -s resonant_backend/tests -p 'test_*.py'` â€” passed (33 tests).
- `flutter build apk --debug` â€” passed; installation on the connected Samsung was not verified because ADB could not start.
- ML demo training â€” ran with seed `20261101`; metrics are synthetic-only and
  documented in [ml-synthetic-demo.json](ml-synthetic-demo.json).

## Important references and limitations

- English engine scope and official Bharati reference findings:
  [braille-standards.md](braille-standards.md).
- Synthetic ML methodology and deployment limits:
  [adaptive-learning.md](adaptive-learning.md).
- The tutor retrieval corpus is deliberately small and only supports verified
  English single letters, six-dot layout, project capability scope, and the
  current language limitations. It is not a searchable or complete UEB text.
- The ordered stages, word banks, mastery rule, and resume behavior are in
  [curriculum.md](curriculum.md).
- Database schema and real learner records remain uninspected because no
  `RESONANT_DATABASE_URL` is configured in this environment. The new migration
  uses a separate `resonant` schema to preserve any existing default-schema
  tables; see [database-and-api.md](database-and-api.md). Learner routes still
  need authentication before deployment.


# Resonant Voice Tutor

## Current behavior

- The learning header is a labelled tutor gesture area. Swipe up there to open
  the tutor; it begins listening automatically. TalkBack users can invoke the
  **Talk to Resonant** custom accessibility action, leaving normal one-finger
  TalkBack navigation untouched. Inside the tutor, swipe up on the status area
  to listen again and swipe down to stop listening or speech. Typed questions
  submit with the keyboard's send action.
- Android speech recognition is a short, user-initiated session through
  `speech_to_text`. Runtime microphone permission is requested by the native
  plugin. This can use an online device service; offline recognition is not
  promised.
- Typed questions work if permission is denied, the recognizer is missing, or
  the transcript is empty. If the API connection fails, an on-device rule-based
  tutor still explains the six-dot layout, gives hints, and verifies supported
  uncontracted English letters and words with the deterministic engine. It
  clearly declines unsupported contractions and language mappings.
- Replies use the existing Flutter TTS service and can be replayed or stopped.
  State changes are exposed as a live semantic status; partial transcripts do
  not trigger repeated announcements.
- Follow-up turns and current lesson title/prompt are sent to the configured
  tutor API. Conversation turns remain in memory only and can be cleared.
  Raw audio and learner IDs/progress records are not sent or saved.
- English is the only enabled tutor language. Hindi and Kannada remain visibly
  unavailable until recognition, local Braille content, response quality,
  and pronunciation can be tested end to end.
- Exact single-letter and supported alphabetic-word answers are returned
  directly from the backend's deterministic English table. Word answers
  include the authoritative dot positions, capital indicators, and ICEB
  references, without adding unsupported model claims. Uppercase runs use the
  engine's capital-word indicator. Word support is uncontracted A-Z only;
  punctuation, numbers, and contractions are refused. This is not full UEB.
  Ollama and retrieved evidence still support conceptual tutoring.
- Conceptual answers use a local, traceable retrieval corpus for six-dot
  layout, supported basic letters, the app's current English limitations, and
  language availability. The Flutter response shows the returned references.
  This corpus is not a complete UEB rulebook. The LLM prompt forbids dot
  patterns, and explicit dot-number claims are filtered to a safe explanation.

## Configure a phone demonstration

The backend currently uses the existing Ollama integration. On Android, the
phone's `localhost` is not the development computer. Keep the phone connected
by USB and run `adb reverse tcp:8000 tcp:8000` after starting the API; the app's
existing local API address then reaches the computer. The repository
does not contain the `openai.json` mentioned in the latest project direction,
so OpenAI is not configured or claimed as the active tutor provider. No API
credential is embedded in Flutter. Until the agreed file is present and its
schema is confirmed, tutor requests continue to use the backend's configured
provider and safe deterministic fallback.

Start Ollama and the backend on the development computer. The backend
defaults to `qwen2.5:0.5b` at `http://localhost:11434`; use
`RESONANT_OLLAMA_MODEL` and `RESONANT_OLLAMA_URL` to change those settings.
Then run:

```powershell
cd resonant_backend
uvicorn main:app --host 127.0.0.1 --port 8000
```

In another terminal, run `adb reverse tcp:8000 tcp:8000`. The Android build's
cleartext network policy allows only `localhost`; use HTTPS for a different
host. Build/run the app after configuration. No API credential is embedded in
the client.

## Verification and limits

The Flutter tests cover permission-unavailable typed fallback, empty speech,
transcription submission, response speaking, replay, interruption, clearing,
HTTP payloads, and accessible labels. Backend tests cover timeout fallback,
unsupported languages, verified mapping checks, refusal for forged patterns,
and model-output filtering. These use fakes/mocks; they do not prove the
Samsung's speech recognition quality, TTS pronunciation, actual microphone
permission flow, screen-reader focus order, or live Ollama connection. Backend
retrieval evaluation uses seven fixed query cases and does not assess generated
answer quality.

The prior checkpoint detected a Samsung SM A176B and installed an earlier APK;
that checkpoint did not verify microphone use or TalkBack. The revised
landscape keyboard and swipe-led flow require installation and physical-device
verification. Automated widget tests cannot prove TalkBack gesture behavior,
actual speech recognition, vibration strength, or TTS pronunciation on the
phone.

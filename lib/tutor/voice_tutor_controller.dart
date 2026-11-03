import 'dart:async';

import 'package:flutter/foundation.dart';

enum VoiceTutorState { idle, listening, thinking, speaking, error }

class TutorMessage {
  final String role;
  final String text;
  const TutorMessage(this.role, this.text);
}

class VerifiedBrailleExample {
  final String text;
  final List<int> cells;
  const VerifiedBrailleExample(this.text, this.cells);

  String get spoken => '$text: ${cells.map(_dotsForCell).join(', then ')}';

  static String _dotsForCell(int cell) {
    if (cell == 0) return 'blank cell';
    final dots = [
      for (var bit = 0; bit < 6; bit++)
        if ((cell & (1 << bit)) != 0) '${bit + 1}',
    ];
    return 'dots ${dots.join(', ')}';
  }
}

class TutorLetterExample {
  final String letter;
  final List<int> cells;
  final List<int> dots;
  final String capitalization;
  const TutorLetterExample({
    required this.letter,
    required this.cells,
    required this.dots,
    required this.capitalization,
  });

  String get spoken {
    const positions = {
      1: 'top-left',
      2: 'middle-left',
      3: 'bottom-left',
      4: 'top-right',
      5: 'middle-right',
      6: 'bottom-right',
    };
    final pattern = dots.isEmpty
        ? 'blank cell'
        : dots.map((dot) => 'dot $dot at ${positions[dot]}').join(' and ');
    return '$letter: $pattern';
  }
}

class TutorResponse {
  final String answer;
  final String source;
  final List<VerifiedBrailleExample> verifiedExamples;
  final List<TutorLetterExample> letterExamples;
  final List<TutorSource> sources;
  const TutorResponse(
    this.answer, {
    this.source = 'ollama',
    this.verifiedExamples = const [],
    this.letterExamples = const [],
    this.sources = const [],
  });
}

class TutorSource {
  final String title;
  final String url;
  const TutorSource({required this.title, required this.url});
}

abstract interface class SpeechRecognizer {
  Future<bool> initialize(ValueChanged<String> onError);
  Future<void> listen({
    required String locale,
    required void Function(String, bool) onResult,
  });
  Future<void> stop();
  Future<void> cancel();
}

abstract interface class TutorGateway {
  Future<TutorResponse> ask({
    required String question,
    required List<TutorMessage> history,
    required String lessonContext,
    required List<VerifiedBrailleExample> verifiedExamples,
  });
}

abstract interface class TutorSpeechOutput {
  Future<void> speak(String text);
  Future<void> stop();
}

class VoiceTutorController extends ChangeNotifier {
  VoiceTutorController({
    required SpeechRecognizer speech,
    required TutorGateway gateway,
    required TutorSpeechOutput output,
    required this.lessonContext,
    this.lessonExamples = const [],
    this.locale = 'en-US',
    this.requestTimeout = const Duration(seconds: 26),
    this.localCommandHandler,
    this.offlineTutorHandler,
    this.onLocalCommandComplete,
    this.onStatusAnnouncement,
  }) : _speech = speech,
       _gateway = gateway,
       _output = output;

  final SpeechRecognizer _speech;
  final TutorGateway _gateway;
  final TutorSpeechOutput _output;
  final String lessonContext;
  final List<VerifiedBrailleExample> lessonExamples;
  final String locale;
  final Duration requestTimeout;
  final Future<String?> Function(String question)? localCommandHandler;
  final FutureOr<TutorResponse?> Function(
    String question,
    List<TutorMessage> history,
    String lessonContext,
    List<VerifiedBrailleExample> lessonExamples,
  )?
  offlineTutorHandler;
  final Future<void> Function()? onLocalCommandComplete;
  final Future<void> Function(String message)? onStatusAnnouncement;
  VoiceTutorState state = VoiceTutorState.idle;
  String transcript = '';
  String reply = '';
  String? errorMessage;
  List<VerifiedBrailleExample> verifiedExamples = const [];
  List<TutorLetterExample> letterExamples = const [];
  List<TutorSource> sources = const [];
  final List<TutorMessage> messages = [];
  bool _busy = false;
  bool _disposed = false;
  int _speechGeneration = 0;
  int _requestGeneration = 0;

  String get statusText => switch (state) {
    VoiceTutorState.idle =>
      'Ready. Swipe up in the tutor area to speak, or type a question.',
    VoiceTutorState.listening => 'Listening. Speak now.',
    VoiceTutorState.thinking => 'Resonant is thinking.',
    VoiceTutorState.speaking => 'Resonant is speaking.',
    VoiceTutorState.error =>
      errorMessage ?? 'Voice input is unavailable. You can type instead.',
  };

  Future<void> startListening() async {
    if (_busy || state == VoiceTutorState.listening) return;
    _busy = true;
    errorMessage = null;
    transcript = '';
    state = VoiceTutorState.listening;
    notifyListeners();
    try {
      await _announceStatus(statusText);
      final available = await _speech.initialize((message) {
        _setError(
          'Speech recognition failed: $message. Type your question instead.',
        );
      });
      if (!available) {
        _setError(
          'Microphone permission or speech recognition is unavailable. Type your question instead.',
        );
        return;
      }
      await _speech.listen(
        locale: locale,
        onResult: (text, isFinal) {
          if (_disposed) return;
          transcript = text;
          if (isFinal) {
            if (text.trim().isEmpty) {
              _setError(
                'No speech was recognized. Please try again or type your question.',
              );
            } else {
              unawaited(send(text));
            }
          }
          notifyListeners();
        },
      );
    } catch (_) {
      _setError('Speech input could not start. Type your question instead.');
    } finally {
      _busy = false;
    }
  }

  Future<void> stopListening() async {
    if (state != VoiceTutorState.listening) return;
    try {
      await _speech.stop();
      if (state == VoiceTutorState.listening) {
        final finalText = transcript.trim();
        if (finalText.isEmpty) {
          _setError(
            'No speech was recognized. Please try again or type your question.',
          );
        } else {
          await send(finalText);
        }
      }
    } catch (_) {
      _setError(
        'Speech recognition stopped unexpectedly. Type your question instead.',
      );
    }
  }

  Future<void> send(String text) async {
    if (_disposed) return;
    final question = text.trim();
    final normalized = question.toLowerCase().replaceAll(
      RegExp(r'[.!?]+$'),
      '',
    );
    if ({'stop speaking', 'stop talking'}.contains(normalized) &&
        state == VoiceTutorState.speaking) {
      await stopSpeaking();
      return;
    }
    if (question.isEmpty || _busy) {
      if (question.isEmpty) _setError('Enter or say a question first.');
      return;
    }
    _busy = true;
    await _speech.stop();
    await _output.stop();
    _speechGeneration++;
    errorMessage = null;
    transcript = question;
    final previous = List<TutorMessage>.unmodifiable(messages);
    final requestGeneration = ++_requestGeneration;
    messages.add(TutorMessage('user', question));
    state = VoiceTutorState.thinking;
    notifyListeners();
    await _announceStatus(statusText);
    try {
      final localAnswer = await localCommandHandler?.call(question);
      if (localAnswer != null) {
        reply = localAnswer;
        state = VoiceTutorState.speaking;
        notifyListeners();
        final generation = ++_speechGeneration;
        await _output.speak(localAnswer);
        if (generation == _speechGeneration &&
            state == VoiceTutorState.speaking) {
          state = VoiceTutorState.idle;
          notifyListeners();
          await onLocalCommandComplete?.call();
        }
        return;
      }
      final response = await _gateway
          .ask(
            question: question,
            history: previous,
            lessonContext: lessonContext,
            verifiedExamples: lessonExamples,
          )
          .timeout(requestTimeout);
      if (requestGeneration != _requestGeneration) return;
      await _presentResponse(response, requestGeneration);
    } on TimeoutException {
      if (requestGeneration == _requestGeneration) {
        await _respondOfflineOrExplain(
          question,
          previous,
          requestGeneration,
          'The tutor took too long to respond.',
        );
      }
    } catch (_) {
      if (requestGeneration == _requestGeneration) {
        await _respondOfflineOrExplain(
          question,
          previous,
          requestGeneration,
          'The online tutor could not connect.',
        );
      }
    } finally {
      if (requestGeneration == _requestGeneration) _busy = false;
    }
  }

  Future<void> _respondOfflineOrExplain(
    String question,
    List<TutorMessage> history,
    int requestGeneration,
    String reason,
  ) async {
    try {
      final response = await offlineTutorHandler?.call(
        question,
        history,
        lessonContext,
        lessonExamples,
      );
      if (response != null) {
        await _presentResponse(response, requestGeneration);
        return;
      }
    } catch (_) {
      // Keep typed input available even if the offline helper itself fails.
    }
    if (requestGeneration == _requestGeneration) {
      _setError(
        '$reason Offline help can still cover the six-dot layout and verified English letters and words. You can try again or type your question.',
      );
    }
  }

  Future<void> _presentResponse(
    TutorResponse response,
    int requestGeneration,
  ) async {
    if (_disposed || requestGeneration != _requestGeneration) return;
    reply = response.answer;
    verifiedExamples = response.verifiedExamples;
    letterExamples = response.letterExamples;
    sources = response.sources;
    messages.add(TutorMessage('assistant', response.answer));
    state = VoiceTutorState.speaking;
    notifyListeners();
    final spoken = [
      response.answer,
      ...response.verifiedExamples.map(
        (example) => 'Verified example. ${example.spoken}.',
      ),
    ].join(' ');
    final generation = ++_speechGeneration;
    await _output.speak(spoken);
    if (generation == _speechGeneration && state == VoiceTutorState.speaking) {
      state = VoiceTutorState.idle;
      notifyListeners();
    }
  }

  Future<void> replay() async {
    if (reply.isEmpty) return;
    await _output.stop();
    final spoken = [
      reply,
      ...verifiedExamples.map(
        (example) => 'Verified example. ${example.spoken}.',
      ),
    ].join(' ');
    final generation = ++_speechGeneration;
    state = VoiceTutorState.speaking;
    notifyListeners();
    await _output.speak(spoken);
    if (generation == _speechGeneration && state == VoiceTutorState.speaking) {
      state = VoiceTutorState.idle;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    _speechGeneration++;
    await _output.stop();
    if (state == VoiceTutorState.speaking) {
      state = VoiceTutorState.idle;
      notifyListeners();
    }
  }

  Future<void> clearConversation() async {
    _requestGeneration++;
    _busy = false;
    await _speech.cancel();
    await _output.stop();
    _speechGeneration++;
    messages.clear();
    transcript = '';
    reply = '';
    verifiedExamples = const [];
    letterExamples = const [];
    sources = const [];
    errorMessage = null;
    state = VoiceTutorState.idle;
    notifyListeners();
  }

  void _setError(String message) {
    if (_disposed) return;
    errorMessage = message;
    state = VoiceTutorState.error;
    notifyListeners();
    unawaited(_announceStatus(message));
  }

  Future<void> _announceStatus(String message) async {
    try {
      await onStatusAnnouncement?.call(message);
    } catch (_) {
      // The state remains visible and typed input remains available.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_speech.cancel());
    unawaited(_output.stop());
    super.dispose();
  }
}

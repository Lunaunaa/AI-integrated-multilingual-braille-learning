import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_tutor_controller.dart';

/// Device speech adapter. Android/iOS may use an online recognition service;
/// this adapter does not promise offline speech recognition.
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool? _available;
  void Function(String)? _errorSink;

  @override
  Future<bool> initialize(void Function(String) onError) async {
    _errorSink = onError;
    _available ??= await _speech.initialize(
      onError: (error) => _errorSink?.call(error.errorMsg),
      onStatus: (_) {},
    );
    return _available!;
  }

  @override
  Future<void> listen({required String locale, required void Function(String, bool) onResult}) async {
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (SpeechRecognitionResult result) => onResult(result.recognizedWords, result.finalResult),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/tutor/voice_tutor_controller.dart';
import 'package:resonant_braille/tutor/local_braille_tutor.dart';
import 'package:resonant_braille/tutor/voice_tutor_panel.dart';
import 'package:resonant_braille/tutor/voice_command_parser.dart';

class FakeSpeech implements SpeechRecognizer {
  bool available = true;
  void Function(String, bool)? onResult;
  int starts = 0;
  int cancels = 0;
  @override
  Future<bool> initialize(void Function(String) onError) async => available;
  @override
  Future<void> listen({
    required String locale,
    required void Function(String, bool) onResult,
  }) async {
    starts++;
    this.onResult = onResult;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class FakeGateway implements TutorGateway {
  String? question;
  List<TutorMessage> history = [];
  Object? failure;
  Future<TutorResponse> Function()? pendingResponse;
  @override
  Future<TutorResponse> ask({
    required String question,
    required List<TutorMessage> history,
    required String lessonContext,
    required List<VerifiedBrailleExample> verifiedExamples,
  }) async {
    this.question = question;
    this.history = history;
    if (failure != null) throw failure!;
    if (pendingResponse != null) return pendingResponse!();
    return const TutorResponse(
      'Try the example in your lesson.',
      verifiedExamples: [
        VerifiedBrailleExample('a', [1]),
      ],
    );
  }
}

class FakeOutput implements TutorSpeechOutput {
  final List<String> spoken = [];
  bool holdPlayback = false;
  Completer<void>? playback;
  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (!holdPlayback) return Future<void>.value();
    playback = Completer<void>();
    return playback!.future;
  }

  @override
  Future<void> stop() async {
    if (playback?.isCompleted == false) playback!.complete();
  }
}

VoiceTutorController makeController({
  FakeSpeech? speech,
  FakeGateway? gateway,
  FakeOutput? output,
}) => VoiceTutorController(
  speech: speech ?? FakeSpeech(),
  gateway: gateway ?? FakeGateway(),
  output: output ?? FakeOutput(),
  lessonContext: 'Chapter 2, letter practice',
  lessonExamples: const [
    VerifiedBrailleExample('a', [1]),
  ],
);

void main() {
  test(
    'app voice commands are parsed deterministically while questions are left for the tutor',
    () {
      expect(
        VoiceCommandParser.parse('Teach me the letter B')?.command,
        VoiceCommand.teachLetter,
      );
      expect(VoiceCommandParser.parse('Teach me the letter B')?.letter, 'B');
      expect(
        VoiceCommandParser.parse('Go to the next lesson')?.command,
        VoiceCommand.nextLesson,
      );
      expect(
        VoiceCommandParser.parse('Can you teach me about contractions?'),
        isNull,
      );
    },
  );

  test(
    'handled voice commands bypass the AI gateway and close only after spoken feedback',
    () async {
      final gateway = FakeGateway();
      final output = FakeOutput();
      var completed = false;
      final controller = VoiceTutorController(
        speech: FakeSpeech(),
        gateway: gateway,
        output: output,
        lessonContext: 'Letter practice',
        localCommandHandler: (question) async =>
            question.toLowerCase() == 'start learning'
            ? 'Opening your next lesson.'
            : null,
        onLocalCommandComplete: () async => completed = true,
      );
      await controller.send('Start learning');
      expect(gateway.question, isNull);
      expect(output.spoken.single, 'Opening your next lesson.');
      expect(completed, isTrue);
      controller.dispose();
    },
  );

  test('speech permission failure leaves typed questions available', () async {
    final speech = FakeSpeech()..available = false;
    final controller = makeController(speech: speech);
    await controller.startListening();
    expect(controller.state, VoiceTutorState.error);
    await controller.send('Explain a Braille cell');
    expect(controller.reply, 'Try the example in your lesson.');
    expect(controller.state, VoiceTutorState.idle);
    controller.dispose();
  });

  test('speech transcript submits a question and speaks the reply', () async {
    final speech = FakeSpeech();
    final gateway = FakeGateway();
    final output = FakeOutput();
    final controller = makeController(
      speech: speech,
      gateway: gateway,
      output: output,
    );
    await controller.startListening();
    expect(controller.state, VoiceTutorState.listening);
    speech.onResult!('Can you give me a hint?', true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.question, 'Can you give me a hint?');
    expect(output.spoken.single, contains('dots 1'));
    expect(controller.messages.map((message) => message.role), [
      'user',
      'assistant',
    ]);
    controller.dispose();
  });

  test(
    'listening, thinking, and recognition errors produce spoken status messages',
    () async {
      final speech = FakeSpeech();
      final status = <String>[];
      final controller = VoiceTutorController(
        speech: speech,
        gateway: FakeGateway(),
        output: FakeOutput(),
        lessonContext: 'Current lesson',
        onStatusAnnouncement: (message) async {
          status.add(message);
        },
      );
      await controller.startListening();
      expect(speech.starts, 1);
      expect(status.first, 'Listening. Speak now.');
      speech.onResult!('What is Braille?', true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(status, contains('Resonant is thinking.'));
      controller.dispose();

      final deniedStatus = <String>[];
      final denied = VoiceTutorController(
        speech: FakeSpeech()..available = false,
        gateway: FakeGateway(),
        output: FakeOutput(),
        lessonContext: 'Current lesson',
        onStatusAnnouncement: (message) async {
          deniedStatus.add(message);
        },
      );
      await denied.startListening();
      expect(
        deniedStatus.last,
        contains('permission or speech recognition is unavailable'),
      );
      denied.dispose();
    },
  );

  test(
    'empty speech results are announced as errors without sending',
    () async {
      final speech = FakeSpeech();
      final gateway = FakeGateway();
      final controller = makeController(speech: speech, gateway: gateway);
      await controller.startListening();
      speech.onResult!('', true);
      expect(controller.state, VoiceTutorState.error);
      expect(controller.errorMessage, contains('No speech was recognized'));
      expect(gateway.question, isNull);
      controller.dispose();
    },
  );

  test('typed follow-up, reply replay, stop, and clear work', () async {
    final output = FakeOutput();
    final controller = makeController(output: output);
    await controller.send('Explain the six dot positions');
    expect(controller.reply, isNotEmpty);
    await controller.replay();
    expect(output.spoken, hasLength(2));
    await controller.stopSpeaking();
    expect(controller.state, VoiceTutorState.idle);
    await controller.clearConversation();
    expect(controller.messages, isEmpty);
    expect(controller.reply, isEmpty);
    controller.dispose();
  });

  test('stop speaking interrupts active playback', () async {
    final output = FakeOutput()..holdPlayback = true;
    final controller = makeController(output: output);
    final request = controller.send('Explain Braille');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, VoiceTutorState.speaking);
    await controller.stopSpeaking();
    await request;
    expect(output.playback!.isCompleted, isTrue);
    expect(controller.state, VoiceTutorState.idle);
    controller.dispose();
  });

  test('typed stop speaking command interrupts tutor playback', () async {
    final output = FakeOutput()..holdPlayback = true;
    final controller = makeController(output: output);
    final response = controller.send('Explain Braille');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, VoiceTutorState.speaking);
    await controller.send('Stop speaking');
    await response;
    expect(output.playback!.isCompleted, isTrue);
    expect(controller.state, VoiceTutorState.idle);
    controller.dispose();
  });

  test(
    'backend failure preserves the question and shows typed retry guidance',
    () async {
      final gateway = FakeGateway()
        ..failure = StateError('network unavailable');
      final controller = makeController(gateway: gateway);
      await controller.send('What is a Braille cell?');
      expect(controller.state, VoiceTutorState.error);
      expect(controller.messages.first.text, 'What is a Braille cell?');
      expect(controller.errorMessage, contains('try again'));
      controller.dispose();
    },
  );

  test(
    'backend failure falls back to verified offline word teaching',
    () async {
      final gateway = FakeGateway()
        ..failure = StateError('network unavailable');
      final output = FakeOutput();
      final controller = VoiceTutorController(
        speech: FakeSpeech(),
        gateway: gateway,
        output: output,
        lessonContext: 'Word lesson CAT',
        offlineTutorHandler: (question, history, context, examples) =>
            LocalBrailleTutor.answer(
              question: question,
              history: history,
              lessonContext: context,
              lessonExamples: examples,
            ),
      );
      await controller.send('How do I write CAT in Braille?');
      expect(controller.state, VoiceTutorState.idle);
      expect(controller.errorMessage, isNull);
      expect(controller.reply, contains('capital-word indicator'));
      expect(controller.verifiedExamples.single.cells, [32, 32, 9, 1, 30]);
      expect(output.spoken.single, contains('dot 1'));
      controller.dispose();
    },
  );

  test('tutor network timeout returns a usable retry state', () async {
    final gateway = FakeGateway()
      ..pendingResponse = () => Completer<TutorResponse>().future;
    final controller = VoiceTutorController(
      speech: FakeSpeech(),
      gateway: gateway,
      output: FakeOutput(),
      lessonContext: 'Current lesson',
      requestTimeout: const Duration(milliseconds: 5),
    );
    await controller.send('Please explain');
    expect(controller.state, VoiceTutorState.error);
    expect(controller.errorMessage, contains('too long'));
    controller.dispose();
  });

  testWidgets(
    'voice tutor starts by gesture and offers accessible typed input',
    (tester) async {
      final controller = makeController();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VoiceTutorPanel(controller: controller)),
        ),
      );
      expect(find.byKey(const ValueKey('tutor-talk-button')), findsNothing);
      expect(find.byKey(const ValueKey('tutor-state-gesture')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tutor-typed-question')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Raw audio and this conversation are not saved'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('tutor-typed-question')),
        'Tell me about Braille',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Resonant: Try the example'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'opening tutor for voice begins listening without a talk button',
    (tester) async {
      final speech = FakeSpeech();
      final controller = makeController(speech: speech);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceTutorPanel(
              controller: controller,
              startListeningOnOpen: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(speech.starts, 1);
      expect(controller.state, VoiceTutorState.listening);
      expect(find.byKey(const ValueKey('tutor-talk-button')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('tutor dialog fits a short landscape phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = makeController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceTutorPanel(controller: controller)),
      ),
    );
    expect(find.byKey(const ValueKey('tutor-typed-question')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

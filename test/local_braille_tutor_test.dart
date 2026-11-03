import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/tutor/local_braille_tutor.dart';
import 'package:resonant_braille/tutor/voice_tutor_controller.dart';

void main() {
  TutorResponse answer(
    String question, {
    List<TutorMessage> history = const [],
  }) => LocalBrailleTutor.answer(
    question: question,
    history: history,
    lessonContext: 'Letter lesson A',
    lessonExamples: const [
      VerifiedBrailleExample('A', [32, 1]),
    ],
  );

  test('offline tutor uses the deterministic engine for a word', () {
    final response = answer('How do I write CAT in Braille?');
    expect(response.source, 'offline_verified_engine');
    expect(response.verifiedExamples.single.cells, [32, 32, 9, 1, 30]);
    expect(response.answer, contains('capital-word indicator'));
    expect(response.letterExamples.map((letter) => letter.letter), [
      'C',
      'A',
      'T',
    ]);
    expect(response.letterExamples[1].dots, [1]);
  });

  test('offline tutor explains A without asking a model', () {
    final response = answer('What dots make letter A?');
    expect(response.verifiedExamples.single.cells, [32, 1]);
    expect(response.answer, contains('dot 1 at top-left'));
  });

  test('offline tutor answers lesson hints and Braille basics', () {
    expect(answer('Give me a hint').answer, contains('current lesson'));
    expect(
      answer('What is the six-dot layout?').answer,
      contains('screen-left'),
    );
    expect(answer('What is Braille?').answer, contains('tactile reading'));
  });

  test('offline tutor refuses unsupported contraction rules explicitly', () {
    final response = answer('How do UEB contractions work?');
    expect(response.answer, contains('not implemented'));
    expect(response.verifiedExamples, isEmpty);
  });
}

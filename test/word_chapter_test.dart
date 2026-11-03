import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/core/braille/english_grade1_engine.dart';
import 'package:resonant_braille/main.dart';

void main() {
  testWidgets(
    'word-writing lesson validates every cell and persists attempts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = <Map<String, Object?>>[];
      final spoken = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordChapterScreen(
              initialLesson: 2,
              completedWords: const {},
              onSpeak: (text) async => spoken.add(text),
              onFeedback: () {},
              audioEnabled: false,
              hapticsEnabled: false,
              onAttempt:
                  ({
                    required lessonIndex,
                    required word,
                    required correct,
                    required attemptNumber,
                    required hintUsed,
                    groupId,
                    finalAttempt = true,
                    responseTimeMs = 0,
                  }) async {
                    events.add({
                      'lesson': lessonIndex,
                      'word': word,
                      'correct': correct,
                      'attempt': attemptNumber,
                      'hint': hintUsed,
                      'group': groupId,
                      'final': finalAttempt,
                      'duration': responseTimeMs,
                    });
                  },
              onLessonChanged: (_) {},
              onMasteryPassed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Let us write CAT'), findsNothing);
      expect(spoken.any((text) => text.contains('Current word: CAT')), isTrue);
      await tester.tap(find.byTooltip('Switch to accessible dot controls'));
      await tester.pumpAndSettle();

      Future<void> enterCell(int cell) async {
        for (final dot in EnglishGrade1Engine.dotsForCell(cell)) {
          await tester.tap(find.bySemanticsLabel('Braille dot $dot'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Check pattern'));
        await tester.pumpAndSettle();
      }

      // A wrong first cell is corrected without advancing the learner.
      await enterCell(1);
      expect(
        find.textContaining('That cell was not quite right'),
        findsNothing,
      );
      expect(
        spoken.any((text) => text.contains('That cell was not quite right')),
        isTrue,
      );
      expect(events.single['correct'], false);

      await enterCell(32);
      await tester.tap(find.byTooltip('Backspace previous Braille cell'));
      await tester.pumpAndSettle();
      expect(
        spoken.any((text) => text.contains('Previous cell removed')),
        isTrue,
      );

      for (final cell in EnglishGrade1Engine.encode('CAT')) {
        await enterCell(cell);
      }

      expect(find.textContaining('Let us write BAT'), findsNothing);
      expect(spoken.any((text) => text.contains('Next word: BAT')), isTrue);
      expect(events.last['word'], 'CAT');
      expect(events.last['correct'], true);
      expect(events.last['final'], true);
      expect(events.last['attempt'], 7);
      expect(
        spoken.any((text) => text.contains('Capital-word sign cell 1')),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

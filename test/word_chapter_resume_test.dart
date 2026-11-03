import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/learning/lesson_catalog.dart';
import 'package:resonant_braille/learning/lesson_progress_store.dart';
import 'package:resonant_braille/learning/onboarding_store.dart';
import 'package:resonant_braille/main.dart';

class _CompletedOnboarding implements OnboardingProgress {
  @override
  Future<bool> isComplete() async => true;
  @override
  Future<void> markComplete() async {}
  @override
  Future<int> currentStep() async => 10;
  @override
  Future<void> saveStep(int step) async {}
}

class _SavedEvents extends LessonProgressStore {
  _SavedEvents(this.events) : super(File('unused-word-resume.json'));
  final List<Map<String, dynamic>> events;

  @override
  Future<List<Map<String, dynamic>>> readEvents() async => events;

  @override
  Future<void> record({
    required String exerciseId,
    required String skillId,
    required String exerciseType,
    required bool correct,
    required int attemptNumber,
    required bool hintUsed,
    required int responseTimeMs,
    String? groupId,
  }) async {}
}

void main() {
  testWidgets(
    'saved letter and mastery events resume in the unlocked word chapter',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      void add(String id, {bool correct = true, String? groupId}) {
        events.add({
          'exercise_id': id,
          'outcome': correct ? 'correct' : 'incorrect',
          if (groupId != null) 'group_id': groupId,
          'attempt_number': 1,
        });
      }

      for (final letter in LessonCatalog.alphabet) {
        add('letter-${letter.toLowerCase()}');
      }
      for (final stage in LessonCatalog.curriculum) {
        for (var index = 0; index < stage.words.length; index++) {
          add('word-stage-${stage.id}-word-$index');
        }
      }
      for (
        var index = 0;
        index < LessonCatalog.cumulativeWords.length;
        index++
      ) {
        add('word-stage-cumulative-word-$index');
      }
      for (var lessonIndex = 0; lessonIndex < 4; lessonIndex++) {
        for (final word in LessonCatalog.wordLessons[lessonIndex].words) {
          add('word-chapter-lesson-${lessonIndex + 1}-${word.toLowerCase()}');
        }
      }
      final mastery = LessonCatalog.wordLessons[4].words;
      for (var index = 0; index < mastery.length; index++) {
        add(
          'word-chapter-lesson-5-${mastery[index].toLowerCase()}',
          correct: index < 4,
          groupId: 'word-mastery-round-passed',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ResonantHome(
            onboardingProgress: _CompletedOnboarding(),
            lessonProgressStore: _SavedEvents(events),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WordChapterScreen), findsOneWidget);
      expect(
        find.textContaining('Lesson 5: Word mastery test'),
        findsWidgets,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
    },
  );
}

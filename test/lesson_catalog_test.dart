import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/learning/lesson_catalog.dart';
import 'package:resonant_braille/core/braille/english_grade1_engine.dart';

void main() {
  test('lesson questions have a valid answer and unique skill identifiers', () {
    final exercises = LessonCatalog.english
        .expand((chapter) => chapter.exercises)
        .toList();
    final skillIds = exercises.map((exercise) => exercise.skillId).toSet();

    expect(exercises, isNotEmpty);
    expect(skillIds.length, exercises.length);
    for (final exercise in exercises) {
      expect(exercise.options, contains(exercise.answer));
      expect(exercise.isCorrect(exercise.answer), isTrue);
      expect(
        exercise.options
            .where((option) => option != exercise.answer)
            .every((option) => !exercise.isCorrect(option)),
        isTrue,
      );
    }
  });

  test(
    'curriculum defines the required letter groups and valid stage words',
    () {
      expect(LessonCatalog.curriculum.map((stage) => stage.title), [
        'Letters A through E',
        'Letters F through J',
        'Letters K through O',
        'Letters P through T',
        'Letters U through Z',
      ]);
      expect(LessonCatalog.alphabet.join(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(
        LessonCatalog.curriculum.map((stage) => [stage.first, stage.last]),
        [
          [0, 4],
          [5, 9],
          [10, 14],
          [15, 19],
          [20, 25],
        ],
      );
      for (final stage in LessonCatalog.curriculum) {
        for (final word in stage.words) {
          expect(
            stage.allows(word),
            isTrue,
            reason: '$word must use ${stage.allowedLetters}',
          );
          expect(
            EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(word)),
            word,
          );
        }
      }
      expect(
        LessonCatalog.curriculum.first.words,
        containsAll(['BAD', 'CAB', 'BED', 'ACE', 'DECADE']),
      );
      expect(LessonCatalog.cumulativeWords.map((word) => word.length), [
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(
        LessonCatalog.cumulativeWords.every(
          (word) =>
              LessonCatalog.wordUsesOnly(word, 'abcdefghijklmnopqrstuvwxyz'),
        ),
        isTrue,
      );
    },
  );

  test(
    'English word chapter has five ordered lessons and stable unique exercises',
    () {
      expect(LessonCatalog.english, hasLength(3));
      expect(LessonCatalog.english.last.title, 'Chapter 3: English Words');
      expect(LessonCatalog.wordLessons.map((lesson) => lesson.title), [
        'Lesson 1: Build your first words',
        'Lesson 2: Read familiar words',
        'Lesson 3: Write the word',
        'Lesson 4: Read and identify',
        'Lesson 5: Word mastery test',
      ]);
      expect(LessonCatalog.wordLessons.first.words, ['CAT', 'BAT', 'MAT']);
      expect(LessonCatalog.wordLessons[1].words, ['SUN', 'DOG', 'HAT', 'PEN']);
      final chapterExercises = LessonCatalog.english.last.exercises;
      expect(
        chapterExercises.map((exercise) => exercise.id).toSet().length,
        chapterExercises.length,
      );
      for (final lesson in LessonCatalog.wordLessons) {
        for (final word in lesson.words) {
          expect(
            EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(word)),
            word,
          );
        }
      }
    },
  );
}

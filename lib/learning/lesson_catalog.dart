import '../core/braille/english_grade1_engine.dart';

class LessonExercise {
  final String id;
  final String skillId;
  final String prompt;
  final List<String> options;
  final String answer;
  final String hint;
  final String explanation;
  final String exerciseType;

  const LessonExercise({
    required this.id,
    required this.skillId,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.hint,
    required this.explanation,
    this.exerciseType = 'letter_recognition',
  });

  bool isCorrect(String choice) => choice == answer;
}

class LessonChapter {
  final String title;
  final List<LessonExercise> exercises;

  const LessonChapter({required this.title, required this.exercises});
}

class WordLearningLesson {
  final String id;
  final String title;
  final String description;
  final List<String> words;
  const WordLearningLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.words,
  });
}

class LessonCatalog {
  static const List<String> cumulativeWords = [
    'AB',
    'BAD',
    'FEED',
    'AMAZE',
    'DECADE',
  ];
  static const List<WordLearningLesson> wordLessons = [
    WordLearningLesson(
      id: 'word-build',
      title: 'Lesson 1: Build your first words',
      description:
          'Review the letters you learned. A word places one Braille cell after another. Hear each word and explore its cells.',
      words: ['CAT', 'BAT', 'MAT'],
    ),
    WordLearningLesson(
      id: 'word-read',
      title: 'Lesson 2: Read familiar words',
      description:
          'Hear each familiar word aloud, follow its letters and cells, then identify it.',
      words: ['SUN', 'DOG', 'HAT', 'PEN'],
    ),
    WordLearningLesson(
      id: 'word-write',
      title: 'Lesson 3: Write the word',
      description: 'Write each spoken word one Braille cell at a time.',
      words: ['CAT', 'BAT', 'MAT'],
    ),
    WordLearningLesson(
      id: 'word-identify',
      title: 'Lesson 4: Read and identify',
      description:
          'Explore Braille cells and identify the word they spell without seeing its printed name.',
      words: ['SUN', 'DOG', 'HAT', 'PEN'],
    ),
    WordLearningLesson(
      id: 'word-mastery',
      title: 'Lesson 5: Word mastery test',
      description: 'Show what you know across familiar words.',
      words: ['CAT', 'SUN', 'BAT', 'DOG', 'HAT'],
    ),
  ];

  /// Ordered, uncontracted cumulative spelling stages required by the course.
  /// Each bank contains only words composed of letters taught by that stage.
  static const List<CurriculumStage> curriculum = [
    CurriculumStage(
      id: 'a-e',
      title: 'Letters A through E',
      first: 0,
      last: 4,
      allowedLetters: 'abcde',
      words: ['BAD', 'CAB', 'BED', 'ACE', 'DECADE'],
    ),
    CurriculumStage(
      id: 'a-j',
      title: 'Letters F through J',
      first: 5,
      last: 9,
      allowedLetters: 'abcdefghij',
      words: ['FEED', 'DECAF', 'JAB', 'FACE', 'CAB'],
    ),
    CurriculumStage(
      id: 'a-o',
      title: 'Letters K through O',
      first: 10,
      last: 14,
      allowedLetters: 'abcdefghijklmno',
      words: ['JAM', 'MOON', 'FAD', 'MAKE', 'CODE'],
    ),
    CurriculumStage(
      id: 'a-t',
      title: 'Letters P through T',
      first: 15,
      last: 19,
      allowedLetters: 'abcdefghijklmnopqrst',
      words: ['TASTE', 'MARKET', 'STEAM', 'THREAD', 'MIST'],
    ),
    CurriculumStage(
      id: 'a-z',
      title: 'Letters U through Z',
      first: 20,
      last: 25,
      allowedLetters: 'abcdefghijklmnopqrstuvwxyz',
      words: ['AMAZE', 'BELL', 'FIZZ', 'WAVE', 'QUIZ'],
    ),
  ];

  static const List<String> alphabet = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  static bool wordUsesOnly(String word, String allowedLetters) =>
      word.isNotEmpty &&
      word.toLowerCase().split('').every(allowedLetters.contains);

  static CurriculumStage stageForIndex(int index) => curriculum.firstWhere(
    (stage) => index >= stage.first && index <= stage.last,
  );

  static final List<LessonChapter> english = [
    LessonChapter(
      title: 'Chapter 1: Braille Basics',
      exercises: [
        LessonExercise(
          id: 'dot-top-left',
          skillId: 'dot-position-1',
          exerciseType: 'dot_recognition',
          prompt: 'Which dot is at the top of the left column?',
          options: ['Dot 1', 'Dot 2', 'Dot 4', 'Dot 5'],
          answer: 'Dot 1',
          hint: 'The standard numbering starts at the top of the left column.',
          explanation: 'Dot 1 is at the top of the left column.',
        ),
        LessonExercise(
          id: 'dot-top-right',
          skillId: 'dot-position-4',
          exerciseType: 'dot_recognition',
          prompt: 'Which dot is at the top of the right column?',
          options: ['Dot 1', 'Dot 3', 'Dot 4', 'Dot 6'],
          answer: 'Dot 4',
          hint: 'The right column uses dots 4, 5, and 6 from top to bottom.',
          explanation: 'Dot 4 is at the top of the right column.',
        ),
        LessonExercise(
          id: 'cell-count',
          skillId: 'braille-cell',
          exerciseType: 'dot_recognition',
          prompt: 'How many dots are in one standard Braille cell?',
          options: ['Four', 'Five', 'Six', 'Eight'],
          answer: 'Six',
          hint: 'A standard cell has two columns with three positions each.',
          explanation: 'A standard Braille cell has six dot positions.',
        ),
      ],
    ),
    LessonChapter(
      title: 'Chapter 2: English Letters',
      exercises: [for (final letter in alphabet) _letterExercise(letter)],
    ),
    LessonChapter(
      title: 'Chapter 3: English Words',
      exercises: [
        for (
          var lessonIndex = 0;
          lessonIndex < wordLessons.length;
          lessonIndex++
        )
          for (final word in wordLessons[lessonIndex].words)
            LessonExercise(
              id: 'word-chapter-lesson-${lessonIndex + 1}-${word.toLowerCase()}',
              skillId: 'word-chapter-${lessonIndex + 1}-${word.toLowerCase()}',
              exerciseType: lessonIndex == 2 || lessonIndex == 4
                  ? 'word_transcription'
                  : 'listening',
              prompt: wordLessons[lessonIndex].description,
              options: [
                word,
                ...wordLessons[lessonIndex].words
                    .where((other) => other != word)
                    .take(3),
              ],
              answer: word,
              hint:
                  'Listen to the word again and explore each Braille cell in order.',
              explanation:
                  '$word is spelled as separate uncontracted English Braille letter cells.',
            ),
      ],
    ),
  ];

  static LessonExercise _letterExercise(String letter) {
    final dots = EnglishGrade1Engine.dotsForCell(
      EnglishGrade1Engine.encode(letter.toLowerCase()).single,
    );
    final answer = letter.toLowerCase();
    return LessonExercise(
      id: 'letter-$answer',
      skillId: 'english-letter-$answer',
      exerciseType: 'letter_recognition',
      prompt:
          'Which letter uses ${dots.length == 1 ? 'dot' : 'dots'} ${dots.join(', ')}?',
      options: [
        answer,
        ...alphabet
            .map((item) => item.toLowerCase())
            .where((item) => item != answer)
            .take(3),
      ],
      answer: answer,
      hint:
          'Explore the active dots in the lesson explanation, then choose the matching letter.',
      explanation:
          '${dots.length == 1 ? 'Dot' : 'Dots'} ${dots.join(', ')} ${dots.length == 1 ? 'is' : 'are'} the uncontracted letter $answer.',
    );
  }
}

class CurriculumStage {
  final String id;
  final String title;
  final int first;
  final int last;
  final String allowedLetters;
  final List<String> words;
  const CurriculumStage({
    required this.id,
    required this.title,
    required this.first,
    required this.last,
    required this.allowedLetters,
    required this.words,
  });
  bool allows(String word) => LessonCatalog.wordUsesOnly(word, allowedLetters);
}

import '../core/braille/english_grade1_engine.dart';
import 'voice_tutor_controller.dart';

/// Offline teaching fallback. Exact cells always come from the deterministic
/// English engine; this helper never asks a language model for Braille facts.
class LocalBrailleTutor {
  static const _positions = {
    1: 'top-left',
    2: 'middle-left',
    3: 'bottom-left',
    4: 'top-right',
    5: 'middle-right',
    6: 'bottom-right',
  };

  static TutorResponse answer({
    required String question,
    required List<TutorMessage> history,
    required String lessonContext,
    required List<VerifiedBrailleExample> lessonExamples,
  }) {
    final lower = question.toLowerCase();
    if (RegExp(
      r'\b(hindi|kannada|bharati)\b',
      caseSensitive: false,
    ).hasMatch(question)) {
      return _response(
        'I cannot verify that language’s Braille through the English tutor yet. I can still help with verified uncontracted English letters and words.',
      );
    }

    final word = _requestedWord(question);
    if (word != null) return _wordResponse(word);

    if (_isHintQuestion(lower) && lessonExamples.isNotEmpty) {
      final example = lessonExamples.first;
      final lessonHint = lessonContext.toLowerCase().contains('word')
          ? 'Enter one Braille cell for each letter, then check the whole word.'
          : 'Say the letter ${example.text} and listen to its dot numbers, then select those dots on the keyboard.';
      return _response(
        'Here is a hint for your current lesson: $lessonHint You can clear a dot by selecting it again.',
      );
    }

    final previousQuestions = history
        .where((turn) => turn.role == 'user')
        .map((turn) => turn.text)
        .toList(growable: false);
    final isShortFollowUp = lower.trim().split(RegExp(r'\s+')).length <= 2;
    if (isShortFollowUp && previousQuestions.isNotEmpty) {
      final previousWord = _requestedWord(previousQuestions.last);
      if (previousWord != null) return _wordResponse(previousWord);
    }
    final letter =
        _requestedLetter(question) ??
        (isShortFollowUp && previousQuestions.isNotEmpty
            ? _requestedLetter(previousQuestions.last)
            : null) ??
        (RegExp(
                  r'\b(this letter|current letter|explain it)\b',
                ).hasMatch(lower) &&
                lessonExamples.length == 1 &&
                lessonExamples.single.text.length == 1
            ? lessonExamples.single.text
            : null);
    if (letter != null && RegExp(r'^[A-Za-z]$').hasMatch(letter)) {
      return _wordResponse(letter);
    }

    if (RegExp(
      r'\b(contractions?|grade\s*2|full\s+ueb|shortforms?)\b',
    ).hasMatch(lower)) {
      return _response(
        'Resonant verifies uncontracted English letters and selected indicators. Full UEB contractions and shortforms are not implemented here, so I will not guess their patterns.',
      );
    }

    if (RegExp(
      r'\b(six[- ]dot|dots?|cell|layout|numbering|positions?)\b',
    ).hasMatch(lower)) {
      return _response(
        'A standard Braille cell has six positions in two columns. Standard numbering runs down the left as dots 1, 2, 3, then down the right as dots 4, 5, 6. Resonant’s practice keyboard places dots 1, 2, 3 on screen-left and dots 4, 5, 6 on screen-right.',
      );
    }

    if (RegExp(
      r'\bwhat is braille\b|\bwhat does braille mean\b',
    ).hasMatch(lower)) {
      return _response(
        'Braille is a tactile reading and writing system. People read its raised-dot patterns by touch. Resonant teaches its six-dot English cells through listening, touch, and practice.',
      );
    }

    return _response(
      'I’m offline from the conversational tutor right now, but I can still help with your lesson. Ask me for the six-dot layout, a verified English letter or word, a hint, or which rules Resonant supports. I will say when a Braille rule is outside the verified subset.',
    );
  }

  static bool _isHintQuestion(String question) => RegExp(
    r'\b(hint|help me|what should i do|how do i start)\b',
  ).hasMatch(question);

  static String? _requestedLetter(String question) {
    final patterns = [
      RegExp(r'\b(?:letter|character)\s+([A-Za-z])\b', caseSensitive: false),
      RegExp(
        r'\b(?:pattern|dots?)\s+for\s+(?:the\s+)?(?:letter\s+)?([A-Za-z])\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\bwhat\s+does\s+([A-Za-z])\s+look\s+like\b',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(question);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String? _requestedWord(String question) {
    final patterns = [
      RegExp(
        r'''\b(?:write|spell|encode|transcribe|translate|convert)\s+(?:the\s+)?(?:word\s+)?["']?([A-Za-z]{2,16})["']?\s+(?:in|to)\s+braille\b''',
        caseSensitive: false,
      ),
      RegExp(
        r'''\b(?:braille|pattern|dots?|cells?)\s+(?:for|of)\s+(?:the\s+)?(?:word\s+)?["']?([A-Za-z]{2,16})["']?\b''',
        caseSensitive: false,
      ),
      RegExp(
        r'''\b(?:show|give|tell\s+me)\s+(?:the\s+)?(?:word\s+)?["']?([A-Za-z]{2,16})["']?\s+in\s+braille\b''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(question);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static TutorResponse _wordResponse(String text) {
    try {
      final cells = EnglishGrade1Engine.encode(text);
      final examples = <TutorLetterExample>[];
      final isCapitalWord = text.length > 1 && text == text.toUpperCase();
      for (final character in text.split('')) {
        final isUpper = character.toUpperCase() == character;
        final cell = EnglishGrade1Engine.encode(character.toLowerCase()).single;
        examples.add(
          TutorLetterExample(
            letter: character,
            cells: [cell],
            dots: EnglishGrade1Engine.dotsForCell(cell),
            capitalization: isUpper
                ? isCapitalWord
                      ? 'capital word; shared indicator precedes this run'
                      : 'capital letter'
                : 'lowercase',
          ),
        );
      }
      final descriptions = examples
          .map((example) {
            final dots = example.dots;
            final location = dots.isEmpty
                ? 'no raised dots'
                : dots
                      .map((dot) => 'dot $dot at ${_positions[dot]}')
                      .join(' and ');
            return '${example.letter}: $location';
          })
          .join('; ');
      final capitalNote = text.length > 1 && text == text.toUpperCase()
          ? ' Start with the capital-word indicator, dot 6 twice.'
          : text != text.toLowerCase()
          ? ' Each capital letter has a capital sign, dot 6, before its letter cell.'
          : '';
      final answer = text.length == 1
          ? 'In uncontracted English Braille, ${text.toUpperCase()} uses $descriptions.'
          : 'The verified uncontracted English spelling of $text uses ${cells.length} cells: $descriptions.$capitalNote Each letter is a separate cell; contractions are not used.';
      return TutorResponse(
        answer,
        source: 'offline_verified_engine',
        verifiedExamples: [VerifiedBrailleExample(text, cells)],
        letterExamples: examples,
      );
    } on Object {
      return _response(
        'I cannot verify that text with Resonant’s English Braille subset. I will not invent a Braille pattern. Try an English letter or word using A to Z.',
      );
    }
  }

  static TutorResponse _response(String answer) =>
      TutorResponse(answer, source: 'offline_lesson_fallback');
}

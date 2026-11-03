/// Deterministic six-dot English Braille subset for uncontracted text.
///
/// Cell bit 0 is dot 1, through bit 5 for dot 6. Physical screen positions
/// are deliberately handled by the keyboard and never affect these patterns.
/// This implementation covers letters, basic punctuation, capitals, digits,
/// and number mode; it does not implement contractions or technical notation.
class EnglishGrade1Engine {
  static const int numberSign = 60; // dots 3456
  static const int capitalSign = 32; // dot 6
  static const int gradeOneSign = 48; // dots 56

  static const Map<String, int> _letters = {
    'a': 1,
    'b': 3,
    'c': 9,
    'd': 25,
    'e': 17,
    'f': 11,
    'g': 27,
    'h': 19,
    'i': 10,
    'j': 26,
    'k': 5,
    'l': 7,
    'm': 13,
    'n': 29,
    'o': 21,
    'p': 15,
    'q': 31,
    'r': 23,
    's': 14,
    't': 30,
    'u': 37,
    'v': 39,
    'w': 58,
    'x': 45,
    'y': 61,
    'z': 53,
  };

  // Unambiguous basic punctuation subset. Exclamation shares a pattern with
  // the letter s in UEB and needs additional context-sensitive disambiguation.
  static const Map<String, int> _punctuation = {
    ',': 2,
    ';': 6,
    ':': 18,
    '.': 50,
    '?': 22,
    "'": 4,
    '-': 36,
  };

  static const Map<String, String> _digitLetter = {
    '1': 'a',
    '2': 'b',
    '3': 'c',
    '4': 'd',
    '5': 'e',
    '6': 'f',
    '7': 'g',
    '8': 'h',
    '9': 'i',
    '0': 'j',
  };

  static final Map<int, String> _lettersByCell = {
    for (final entry in _letters.entries) entry.value: entry.key,
  };
  static final Map<int, String> _punctuationByCell = {
    for (final entry in _punctuation.entries) entry.value: entry.key,
  };
  static final Map<String, String> _letterDigit = {
    for (final entry in _digitLetter.entries) entry.value: entry.key,
  };

  static int cell(Iterable<int> dots) {
    var value = 0;
    for (final dot in dots) {
      if (dot < 1 || dot > 6) {
        throw FormatException('Braille dot must be between 1 and 6: $dot');
      }
      value |= 1 << (dot - 1);
    }
    return value;
  }

  /// Returns the Braille dot numbers represented by one six-bit cell mask.
  static List<int> dotsForCell(int value) {
    if (value < 0 || value > 63) {
      throw FormatException('Braille cell must be between 0 and 63: $value');
    }
    return [for (var bit = 0; bit < 6; bit++) if ((value & (1 << bit)) != 0) bit + 1];
  }

  static List<int> encode(String text) {
    final cells = <int>[];
    var index = 0;
    var numericMode = false;
    while (index < text.length) {
      final char = text[index];
      if (char == ' ') {
        cells.add(0);
        numericMode = false;
        index++;
        continue;
      }

      if (_isDigit(char)) {
        if (!numericMode) cells.add(numberSign);
        numericMode = true;
        while (index < text.length && _isDigit(text[index])) {
          final letter = _digitLetter[text[index]]!;
          cells.add(_letters[letter]!);
          index++;
        }
        continue;
      }

      if (numericMode && _isLowercaseAscii(char)) {
        final previous = text[index - 1];
        if (_letterDigit.containsKey(char) &&
            (_isDigit(previous) || previous == '.' || previous == ',')) {
          // UEB 6.5.2: distinguish a-j following a digit, period or comma.
          cells.add(gradeOneSign);
        }
        numericMode = false;
      }

      if (_isUppercaseAscii(char)) {
        numericMode = false;
        var end = index + 1;
        while (end < text.length && _isUppercaseAscii(text[end])) {
          end++;
        }
        if (end - index > 1) {
          cells
            ..add(capitalSign)
            ..add(capitalSign);
        } else {
          cells.add(capitalSign);
        }
        for (; index < end; index++) {
          cells.add(_letters[text[index].toLowerCase()]!);
        }
        continue;
      }

      final letterCell = _letters[char];
      final punctuationCell = _punctuation[char];
      if (letterCell != null) {
        numericMode = false;
        cells.add(letterCell);
      } else if (punctuationCell != null) {
        final startsDecimal =
            (char == '.' || char == ',') &&
            !numericMode &&
            index + 1 < text.length &&
            _isDigit(text[index + 1]) &&
            (index == 0 || text[index - 1] == ' ' || text[index - 1] == '(');
        if (startsDecimal) {
          // UEB 6.4.1 places the numeric indicator before a decimal point.
          cells.add(numberSign);
          numericMode = true;
        }
        if (char != ',' && char != '.') numericMode = false;
        cells.add(punctuationCell);
      } else {
        throw UnsupportedError('Unsupported English character: $char');
      }
      index++;
    }
    return cells;
  }

  static String decode(Iterable<int> cells) {
    final input = cells.toList(growable: false);
    final output = StringBuffer();
    var numericMode = false;
    var capitalNext = false;
    var capitalWord = false;
    var forceLetter = false;

    for (var index = 0; index < input.length; index++) {
      final current = input[index];
      if (current < 0 || current > 63) {
        throw FormatException('Invalid six-dot Braille cell: $current');
      }
      if (current == 0) {
        output.write(' ');
        numericMode = false;
        capitalNext = false;
        capitalWord = false;
        continue;
      }
      if (current == numberSign) {
        numericMode = true;
        capitalNext = false;
        continue;
      }
      if (current == gradeOneSign) {
        numericMode = false;
        forceLetter = true;
        continue;
      }
      if (current == capitalSign) {
        numericMode = false;
        if (index + 1 < input.length && input[index + 1] == capitalSign) {
          capitalWord = true;
          capitalNext = false;
          index++;
        } else {
          capitalNext = true;
        }
        continue;
      }

      if (numericMode &&
          (current == _punctuation[','] || current == _punctuation['.'])) {
        output.write(_punctuationByCell[current]);
        continue;
      }
      if (numericMode && !forceLetter && _lettersByCell.containsKey(current)) {
        final letter = _lettersByCell[current]!;
        final digit = _letterDigit[letter];
        if (digit != null) {
          output.write(digit);
          continue;
        }
      }

      numericMode = false;
      final letter = _lettersByCell[current];
      final punctuation = _punctuationByCell[current];
      if (letter != null) {
        final uppercase = capitalNext || capitalWord;
        output.write(uppercase ? letter.toUpperCase() : letter);
        capitalNext = false;
      } else if (punctuation != null) {
        output.write(punctuation);
        capitalNext = false;
      } else {
        throw FormatException('Unsupported English Braille cell: $current');
      }
      forceLetter = false;
    }
    return output.toString();
  }

  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  static bool _isUppercaseAscii(String char) =>
      char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90;

  static bool _isLowercaseAscii(String char) =>
      char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/core/braille/english_grade1_engine.dart';

void main() {
  test('round trips the uncontracted English alphabet', () {
    const text = 'abcdefghijklmnopqrstuvwxyz';
    expect(EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(text)), text);
  });

  test('uses the explicit W mapping rather than an alphabetic pattern formula', () {
    expect(EnglishGrade1Engine.encode('w'), [58]);
    expect(EnglishGrade1Engine.dotsForCell(58), [2, 4, 5, 6]);
    expect(EnglishGrade1Engine.encode('W'), [32, 58]);
  });

  test('supports number mode and the following letter indicator', () {
    for (final text in [
      '0123456789',
      '24, 3.14',
      '12a',
      '12A',
      '3b',
      '3B',
      '3m',
      '4.2',
      '4.b',
      '4.B',
      '4.m',
      '1-800',
      '.375',
      'No.16',
    ]) {
      expect(
        EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(text)),
        text,
      );
    }
  });

  test('matches ICEB UEB 2024 numeric mode examples', () {
    expect(EnglishGrade1Engine.encode('32'), [60, 9, 3]);
    expect(EnglishGrade1Engine.encode('3b'), [60, 9, 48, 3]);
    expect(EnglishGrade1Engine.encode('3B'), [60, 9, 32, 3]);
    expect(EnglishGrade1Engine.encode('3m'), [60, 9, 13]);
    expect(EnglishGrade1Engine.encode('4.2'), [60, 25, 50, 3]);
    expect(EnglishGrade1Engine.encode('4.b'), [60, 25, 50, 48, 3]);
    expect(EnglishGrade1Engine.encode('4.B'), [60, 25, 50, 32, 3]);
    expect(EnglishGrade1Engine.encode('4.m'), [60, 25, 50, 13]);
    expect(EnglishGrade1Engine.encode('.375'), [60, 50, 9, 27, 17]);
    expect(
      EnglishGrade1Engine.encode('No.16'),
      [32, 29, 21, 50, 60, 1, 11],
    );
  });

  test('supports single and word capitalization', () {
    for (final text in ['a Z', 'HELLO world', 'I can']) {
      expect(
        EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(text)),
        text,
      );
    }
  });

  test('supports the documented basic punctuation subset', () {
    const text = "a,b;c:d.ef?g-h'";
    expect(EnglishGrade1Engine.decode(EnglishGrade1Engine.encode(text)), text);
  });

  test('rejects unsupported characters and invalid cells explicitly', () {
    expect(() => EnglishGrade1Engine.encode('é'), throwsUnsupportedError);
    expect(() => EnglishGrade1Engine.encode('!'), throwsUnsupportedError);
    expect(() => EnglishGrade1Engine.decode([64]), throwsFormatException);
    expect(() => EnglishGrade1Engine.decode([63]), throwsFormatException);
  });
}

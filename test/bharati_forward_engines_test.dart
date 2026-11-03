import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/core/braille/bharati_hindi_engine.dart';
import 'package:resonant_braille/core/braille/bharati_kannada_engine.dart';

void main() {
  group('NIEPVD Bharati Hindi forward fixtures', () {
    test('Devanagari consonant and vowel sign match published chart', () {
      expect(BharatiHindiEngine.encode('कि'), [13, 24]);
      expect(BharatiHindiEngine.encode('क्ष'), [12345]);
      expect(BharatiHindiEngine.encode('ज्ञ'), [156]);
      expect(BharatiHindiEngine.encode('१२'), [60, 1, 60, 12]);
    });

    test('does not silently accept unsupported print characters', () {
      expect(() => BharatiHindiEngine.encode('🙂'), throwsUnsupportedError);
      expect(() => BharatiHindiEngine.decode([13]), throwsUnsupportedError);
    });
  });

  group('NIEPVD Bharati Kannada forward fixtures', () {
    test('Kannada letters, matras, conjunct and digits match published chart', () {
      expect(BharatiKannadaEngine.encode('ಕಿ'), [13, 24]);
      expect(BharatiKannadaEngine.encode('ಕ್ಷ'), [12345]);
      expect(BharatiKannadaEngine.encode('ಜ್ಞ'), [156]);
      expect(BharatiKannadaEngine.encode('೫'), [60, 15]);
      expect(BharatiKannadaEngine.encode('ಅ'), [1]);
    });

    test('does not silently accept unsupported print characters', () {
      expect(() => BharatiKannadaEngine.encode('🙂'), throwsUnsupportedError);
      expect(() => BharatiKannadaEngine.decode([13]), throwsUnsupportedError);
    });
  });
}

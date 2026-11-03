import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/tutor/voice_command_parser.dart';

void main() {
  test('commands cover lesson navigation, word tests, hints and accessibility', () {
    expect(VoiceCommandParser.parse('Start the test')?.command, VoiceCommand.startTest);
    expect(VoiceCommandParser.parse('Repeat the word')?.command, VoiceCommand.repeatWord);
    expect(VoiceCommandParser.parse('Clear my pattern')?.command, VoiceCommand.clearPattern);
    expect(VoiceCommandParser.parse('Give me a hint')?.command, VoiceCommand.giveHint);
    expect(VoiceCommandParser.parse('What is my progress')?.command, VoiceCommand.showProgress);
    expect(VoiceCommandParser.parse('Review my mistakes')?.command, VoiceCommand.reviewDifficult);
    expect(VoiceCommandParser.parse('Accessibility settings')?.command, VoiceCommand.openSettings);
  });
}

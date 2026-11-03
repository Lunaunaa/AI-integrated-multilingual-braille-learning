enum VoiceCommand {
  startLearning,
  teachLetter,
  repeat,
  explainDots,
  startPractice,
  checkAnswer,
  nextLesson,
  goBack,
  home,
  openTutor,
  stopSpeaking,
  repeatWord,
  clearPattern,
  giveHint,
  showProgress,
  reviewDifficult,
  openSettings,
  startTest,
  help,
}

class ParsedVoiceCommand {
  final VoiceCommand command;
  final String? letter;

  const ParsedVoiceCommand(this.command, {this.letter});
}

/// Exact, deterministic app commands. Questions that do not match stay with
/// the tutor and are never interpreted as navigation by the Braille engine.
class VoiceCommandParser {
  static ParsedVoiceCommand? parse(String input) {
    final text = input.toLowerCase().trim().replaceAll(RegExp(r'[.!?]+$'), '');
    if ({'start learning', 'continue learning', 'start lesson'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.startLearning);
    }
    final letter = RegExp(r'^(?:teach me|teach|learn|start lesson on) (?:the )?letter ([a-z])$').firstMatch(text);
    if (letter != null) return ParsedVoiceCommand(VoiceCommand.teachLetter, letter: letter.group(1)!.toUpperCase());
    if ({'repeat that', 'repeat', 'say that again', 'repeat the explanation'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.repeat);
    }
    if ({'explain the six dots', 'explain six dots', 'what are the six dots'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.explainDots);
    }
    if ({'start practice', 'begin practice', 'practice now'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.startPractice);
    }
    if ({'check my answer', 'check answer', 'submit answer'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.checkAnswer);
    }
    if ({'repeat the word', 'repeat word', 'say the word again'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.repeatWord);
    }
    if ({'clear my pattern', 'clear the dots', 'clear pattern'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.clearPattern);
    }
    if ({'give me a hint', 'give a hint', 'hint'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.giveHint);
    }
    if ({'what is my progress', 'tell me my progress', 'my progress'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.showProgress);
    }
    if ({'review difficult letters', 'review my mistakes', 'review mistakes'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.reviewDifficult);
    }
    if ({'settings', 'open settings', 'accessibility settings'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.openSettings);
    }
    if ({'start the test', 'start test', 'begin the test'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.startTest);
    }
    if ({'go to the next lesson', 'next lesson', 'next letter'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.nextLesson);
    }
    if ({'go back', 'back', 'previous screen'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.goBack);
    }
    if ({'go home', 'home', 'open home'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.home);
    }
    if ({'open the tutor', 'open tutor', 'open talk to resonant'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.openTutor);
    }
    if ({'stop speaking', 'stop talking'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.stopSpeaking);
    }
    if ({'help', 'help me', 'what can i say'}.contains(text)) {
      return const ParsedVoiceCommand(VoiceCommand.help);
    }
    return null;
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/learning/lesson_progress_store.dart';

void main() {
  late Directory directory;
  late File file;
  late LessonProgressStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resonant-progress-');
    file = File('${directory.path}${Platform.pathSeparator}progress.json');
    store = LessonProgressStore(file);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('lesson attempts survive reopening the local store', () async {
    await store.record(
      exerciseId: 'letter-a',
      skillId: 'english-letter-a',
      exerciseType: 'letter_recognition',
      correct: false,
      attemptNumber: 1,
      hintUsed: true,
      responseTimeMs: 1200,
    );
    await store.record(
      exerciseId: 'letter-a',
      skillId: 'english-letter-a',
      exerciseType: 'letter_recognition',
      correct: true,
      attemptNumber: 2,
      hintUsed: true,
      responseTimeMs: 1800,
    );

    final reopened = LessonProgressStore(file);
    final events = await reopened.readEvents();
    expect(events, hasLength(2));
    expect(events[0]['outcome'], 'incorrect');
    expect(events[1]['outcome'], 'correct');
    expect(events[0]['submission_id'], isNot(events[1]['submission_id']));
    expect(events.every((event) => event['synced_at'] == null), isTrue);
    expect(events[1]['attempt_number'], 2);
  });

  test('word mastery attempt groups persist for retry-safe scoring', () async {
    await store.record(
      exerciseId: 'word-chapter-lesson-5-cat',
      skillId: 'english-word-word-mastery',
      exerciseType: 'braille_writing',
      correct: true,
      attemptNumber: 5,
      hintUsed: false,
      responseTimeMs: 3000,
      groupId: 'word-mastery-round-1',
    );

    final events = await LessonProgressStore(file).readEvents();
    expect(events.single['group_id'], 'word-mastery-round-1');
    expect(events.single['exercise_id'], 'word-chapter-lesson-5-cat');
  });
}

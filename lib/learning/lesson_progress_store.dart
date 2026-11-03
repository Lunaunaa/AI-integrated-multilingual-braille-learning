import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// Small durable offline event log. Events stay pending until a future sync
/// client acknowledges their idempotent submission IDs.
class LessonProgressStore {
  final File file;
  Future<void> _writes = Future<void>.value();

  LessonProgressStore(this.file);

  static Future<LessonProgressStore> forApplication() async {
    final directory = await getApplicationDocumentsDirectory();
    return LessonProgressStore(
      File('${directory.path}${Platform.pathSeparator}lesson-progress.json'),
    );
  }

  Future<List<Map<String, dynamic>>> readEvents() async {
    final temporary = File('${file.path}.tmp');
    final source = await file.exists() ? file : temporary;
    if (!await source.exists()) return [];
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! List) {
      throw const FormatException('Invalid lesson progress file.');
    }
    return decoded
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
  }

  Future<void> record({
    required String exerciseId,
    required String skillId,
    required String exerciseType,
    required bool correct,
    required int attemptNumber,
    required bool hintUsed,
    required int responseTimeMs,
    String? groupId,
  }) {
    final task = _writes.catchError((_) {}).then((_) async {
      final events = await readEvents();
      events.add({
        'submission_id': _newId(),
        'exercise_id': exerciseId,
        'skill_id': skillId,
        'language': 'English',
        'exercise_type': exerciseType,
        'outcome': correct ? 'correct' : 'incorrect',
        'response_time_ms': responseTimeMs,
        'hint_used': hintUsed,
        'attempt_number': attemptNumber,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'synced_at': null,
        if (groupId != null) 'group_id': groupId,
      });
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(events), flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    });
    _writes = task;
    return task;
  }

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

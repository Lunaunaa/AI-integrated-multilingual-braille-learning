import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/api_config.dart';
import 'learner_account_store.dart';

/// Small durable offline event log. Events stay pending until synced
/// to the backend /practice/attempts endpoint.
class LessonProgressStore {
  final File file;
  final http.Client? httpClient;
  final Uri? baseUri;
  Future<void> _writes = Future<void>.value();
  bool _syncing = false;

  LessonProgressStore(this.file, {this.httpClient, this.baseUri});

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
    String? learnerId,
  }) {
    final task = _writes.catchError((_) {}).then((_) async {
      final events = await readEvents();
      events.add({
        'submission_id': _newId(),
        if (learnerId != null) 'learner_id': learnerId,
        'exercise_id': exerciseId,
        'skill_id': skillId,
        'language': 'English',
        'exercise_type': _mapExerciseType(exerciseType),
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

  /// Attempts to upload pending events (synced_at == null) when a learner
  /// account exists and the backend is reachable.
  Future<int> syncPending({LearnerAccountStorage? accountStore}) async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      final store = accountStore ?? await LearnerAccountStore.forApplication();
      final account = await store.load();
      if (account == null) return 0;

      final events = await readEvents();
      final pendingIndices = <int>[];
      for (var i = 0; i < events.length; i++) {
        if (events[i]['synced_at'] == null) {
          pendingIndices.add(i);
        }
      }
      if (pendingIndices.isEmpty) return 0;

      final client = httpClient ?? http.Client();
      final uri = (baseUri ?? Uri.parse(apiBaseUrl)).resolve('/practice/attempts');
      var syncedCount = 0;

      for (final idx in pendingIndices) {
        final ev = events[idx];
        final body = jsonEncode({
          'submission_id': ev['submission_id'],
          'learner_id': ev['learner_id'] ?? account.learnerId,
          'exercise_id': ev['exercise_id'],
          'skill_id': ev['skill_id'],
          'language': ev['language'] ?? 'English',
          'exercise_type': ev['exercise_type'] ?? 'letter_recognition',
          'outcome': ev['outcome'] ?? 'incorrect',
          'response_time_ms': ev['response_time_ms'] ?? 0,
          'hint_used': ev['hint_used'] ?? false,
          'attempt_number': ev['attempt_number'] ?? 1,
        });

        try {
          final res = await client
              .post(uri, headers: {'content-type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 5));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            events[idx]['synced_at'] = DateTime.now().toUtc().toIso8601String();
            events[idx]['learner_id'] = account.learnerId;
            syncedCount++;
          }
        } catch (_) {
          // If network failed, stop syncing this batch and retry next time
          break;
        }
      }

      if (syncedCount > 0) {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(jsonEncode(events), flush: true);
        if (await file.exists()) await file.delete();
        await temporary.rename(file.path);
      }
      return syncedCount;
    } finally {
      _syncing = false;
    }
  }

  static String _mapExerciseType(String type) {
    const valid = {
      'dot_recognition',
      'letter_recognition',
      'listening',
      'braille_writing',
      'transcription',
      'quiz',
    };
    if (valid.contains(type)) return type;
    if (type == 'word_transcription') return 'transcription';
    return 'letter_recognition';
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


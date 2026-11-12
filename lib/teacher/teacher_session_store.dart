import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A teacher's locally persisted auth session.
class TeacherSession {
  final String teacherId;
  final String name;
  final String email;
  final String? organization;
  final String token;

  const TeacherSession({
    required this.teacherId,
    required this.name,
    required this.email,
    this.organization,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'teacher_id': teacherId,
        'name': name,
        'email': email,
        'organization': organization,
        'token': token,
      };

  factory TeacherSession.fromJson(Map<String, dynamic> json) => TeacherSession(
        teacherId: json['teacher_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        organization: json['organization'] as String?,
        token: json['token'] as String,
      );
}

abstract interface class TeacherSessionStorage {
  Future<TeacherSession?> load();
  Future<void> save(TeacherSession session);
  Future<void> clear();
}

/// Atomic-write JSON persistence following the [OnboardingStore] pattern.
class TeacherSessionStore implements TeacherSessionStorage {
  final File file;

  TeacherSessionStore(this.file);

  static Future<TeacherSessionStore> forApplication() async {
    final directory = await getApplicationDocumentsDirectory();
    return TeacherSessionStore(
      File('${directory.path}${Platform.pathSeparator}teacher_session.json'),
    );
  }

  @override
  Future<TeacherSession?> load() async {
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return null;
      return TeacherSession.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(TeacherSession session) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(session.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}


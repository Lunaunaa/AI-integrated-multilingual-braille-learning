import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A registered learner account saved locally after teacher-assisted
/// registration (or account restore).
class LearnerAccount {
  final String learnerId;
  final String learnerCode; // 6-digit code, kept locally for display/restore
  final String name;
  final String? phone;
  final String? email;
  final String? batch;
  final String preferredLanguage;

  const LearnerAccount({
    required this.learnerId,
    required this.learnerCode,
    required this.name,
    this.phone,
    this.email,
    this.batch,
    this.preferredLanguage = 'English',
  });

  Map<String, dynamic> toJson() => {
        'learner_id': learnerId,
        'learner_code': learnerCode,
        'name': name,
        'phone': phone,
        'email': email,
        'batch': batch,
        'preferred_language': preferredLanguage,
      };

  factory LearnerAccount.fromJson(Map<String, dynamic> json) => LearnerAccount(
        learnerId: json['learner_id'] as String,
        learnerCode: json['learner_code'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        batch: json['batch'] as String?,
        preferredLanguage:
            json['preferred_language'] as String? ?? 'English',
      );
}

abstract interface class LearnerAccountStorage {
  /// Returns the locally saved learner account, or null if none exists.
  Future<LearnerAccount?> load();

  /// Persists the account atomically (write-then-rename).
  Future<void> save(LearnerAccount account);

  /// Removes the saved account (e.g., on sign-out).
  Future<void> clear();
}

/// Atomic-write JSON persistence following the [OnboardingStore] pattern.
class LearnerAccountStore implements LearnerAccountStorage {
  final File file;

  LearnerAccountStore(this.file);

  static Future<LearnerAccountStore> forApplication() async {
    final directory = await getApplicationDocumentsDirectory();
    return LearnerAccountStore(
      File('${directory.path}${Platform.pathSeparator}learner_account.json'),
    );
  }

  @override
  Future<LearnerAccount?> load() async {
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return null;
      return LearnerAccount.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LearnerAccount account) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(account.toJson()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}


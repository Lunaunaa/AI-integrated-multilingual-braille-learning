import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class DashboardSummary {
  final int totalLearners;
  final int activeThisWeek;
  final int struggling;

  const DashboardSummary({
    required this.totalLearners,
    required this.activeThisWeek,
    required this.struggling,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        totalLearners: json['total_learners'] as int? ?? 0,
        activeThisWeek: json['active_this_week'] as int? ?? 0,
        struggling: json['struggling'] as int? ?? 0,
      );
}

class LearnerProgressItem {
  final String id;
  final String name;
  final String? batch;
  final String? lastActiveAt;
  final String currentStage;
  final String currentLetter;
  final double accuracyPct;
  final int attempts7d;
  final List<String> topWeakLetters;
  final String status; // 'active', 'inactive', 'struggling'

  const LearnerProgressItem({
    required this.id,
    required this.name,
    this.batch,
    this.lastActiveAt,
    required this.currentStage,
    required this.currentLetter,
    required this.accuracyPct,
    required this.attempts7d,
    required this.topWeakLetters,
    required this.status,
  });

  factory LearnerProgressItem.fromJson(Map<String, dynamic> json) =>
      LearnerProgressItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        batch: json['batch'] as String?,
        lastActiveAt: json['last_active_at'] as String?,
        currentStage: json['current_stage'] as String? ?? '',
        currentLetter: json['current_letter'] as String? ?? '',
        accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
        attempts7d: json['attempts_7d'] as int? ?? 0,
        topWeakLetters: (json['top_weak_letters'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        status: json['status'] as String? ?? 'inactive',
      );
}

class TeacherDashboardData {
  final DashboardSummary summary;
  final List<LearnerProgressItem> learners;

  const TeacherDashboardData({
    required this.summary,
    required this.learners,
  });

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) =>
      TeacherDashboardData(
        summary: DashboardSummary.fromJson(
            json['summary'] as Map<String, dynamic>? ?? {}),
        learners: (json['learners'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(LearnerProgressItem.fromJson)
                .toList() ??
            const [],
      );
}

class AttemptRecord {
  final String submissionId;
  final String exerciseId;
  final String skillId;
  final String exerciseType;
  final String outcome;
  final int responseTimeMs;
  final bool hintUsed;
  final int attemptNumber;
  final String? createdAt;

  const AttemptRecord({
    required this.submissionId,
    required this.exerciseId,
    required this.skillId,
    required this.exerciseType,
    required this.outcome,
    required this.responseTimeMs,
    required this.hintUsed,
    required this.attemptNumber,
    this.createdAt,
  });

  factory AttemptRecord.fromJson(Map<String, dynamic> json) => AttemptRecord(
        submissionId: json['submission_id'] as String? ?? '',
        exerciseId: json['exercise_id'] as String? ?? '',
        skillId: json['skill_id'] as String? ?? '',
        exerciseType: json['exercise_type'] as String? ?? '',
        outcome: json['outcome'] as String? ?? '',
        responseTimeMs: json['response_time_ms'] as int? ?? 0,
        hintUsed: json['hint_used'] as bool? ?? false,
        attemptNumber: json['attempt_number'] as int? ?? 1,
        createdAt: json['created_at'] as String?,
      );
}

class LearnerDetailData {
  final String id;
  final String name;
  final String? batch;
  final String? phone;
  final String? email;
  final String preferredLanguage;
  final String? createdAt;
  final String? lastActiveAt;
  final String currentStage;
  final String currentLetter;
  final double accuracyPct;
  final int totalAttempts;
  final int attempts7d;
  final List<String> topWeakLetters;
  final String status;
  final List<AttemptRecord> recentAttempts;

  const LearnerDetailData({
    required this.id,
    required this.name,
    this.batch,
    this.phone,
    this.email,
    required this.preferredLanguage,
    this.createdAt,
    this.lastActiveAt,
    required this.currentStage,
    required this.currentLetter,
    required this.accuracyPct,
    required this.totalAttempts,
    required this.attempts7d,
    required this.topWeakLetters,
    required this.status,
    required this.recentAttempts,
  });

  factory LearnerDetailData.fromJson(Map<String, dynamic> json) =>
      LearnerDetailData(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        batch: json['batch'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        preferredLanguage: json['preferred_language'] as String? ?? 'English',
        createdAt: json['created_at'] as String?,
        lastActiveAt: json['last_active_at'] as String?,
        currentStage: json['current_stage'] as String? ?? '',
        currentLetter: json['current_letter'] as String? ?? '',
        accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
        totalAttempts: json['total_attempts'] as int? ?? 0,
        attempts7d: json['attempts_7d'] as int? ?? 0,
        topWeakLetters: (json['top_weak_letters'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        status: json['status'] as String? ?? 'inactive',
        recentAttempts: (json['recent_attempts'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(AttemptRecord.fromJson)
                .toList() ??
            const [],
      );
}

class DashboardApi {
  final http.Client _client;
  final Uri _baseUri;
  final String teacherToken;

  DashboardApi({
    required this.teacherToken,
    http.Client? client,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.parse(apiBaseUrl);

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer $teacherToken',
      };

  Future<TeacherDashboardData> fetchDashboard() async {
    final uri = _baseUri.resolve('/teachers/me/dashboard');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _check(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return TeacherDashboardData.fromJson(json);
  }

  Future<LearnerDetailData> fetchLearnerDetail(String learnerId) async {
    final uri = _baseUri.resolve('/teachers/me/learners/$learnerId');
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _check(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return LearnerDetailData.fromJson(json);
  }

  Future<void> deleteLearner(String learnerId) async {
    final uri = _baseUri.resolve('/learners/$learnerId');
    final res = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode == 401) {
      throw const DashboardApiException('Session expired. Please log in again.');
    }
    if (res.statusCode == 404) {
      throw const DashboardApiException('Learner not found.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'Server error (${res.statusCode})';
      try {
        final b = jsonDecode(res.body);
        if (b is Map && b['detail'] is String) detail = b['detail'] as String;
      } catch (_) {}
      throw DashboardApiException(detail);
    }
  }
}

class DashboardApiException implements Exception {
  final String message;
  const DashboardApiException(this.message);
  @override
  String toString() => message;
}


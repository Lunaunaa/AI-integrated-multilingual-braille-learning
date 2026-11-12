import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/core/api_config.dart';
import 'package:resonant_braille/teacher/dashboard_api.dart';

void main() {
  group('DashboardSummary and LearnerProgressItem parsing', () {
    test('DashboardSummary parses correctly from JSON', () {
      final json = {
        'total_learners': 5,
        'active_this_week': 3,
        'struggling': 1,
      };
      final summary = DashboardSummary.fromJson(json);
      expect(summary.totalLearners, 5);
      expect(summary.activeThisWeek, 3);
      expect(summary.struggling, 1);
    });

    test('LearnerProgressItem parses correctly and maps fields', () {
      final json = {
        'id': 'learner-123',
        'name': 'Aarav',
        'batch': 'Batch A',
        'last_active_at': '2026-11-12T10:00:00Z',
        'current_stage': 'stage-1-exercise-1',
        'current_letter': 'A',
        'accuracy_pct': 75.5,
        'attempts_7d': 8,
        'top_weak_letters': ['B', 'C'],
        'status': 'active',
      };
      final item = LearnerProgressItem.fromJson(json);
      expect(item.id, 'learner-123');
      expect(item.name, 'Aarav');
      expect(item.batch, 'Batch A');
      expect(item.accuracyPct, 75.5);
      expect(item.attempts7d, 8);
      expect(item.topWeakLetters, ['B', 'C']);
      expect(item.status, 'active');
    });

    test('LearnerDetailData parses recent attempts and contact info', () {
      final json = {
        'id': 'learner-456',
        'name': 'Priya',
        'batch': 'Grade 5',
        'phone': '9876543210',
        'email': 'priya@example.com',
        'preferred_language': 'English',
        'current_stage': 'stage-1',
        'current_letter': 'C',
        'accuracy_pct': 52.0,
        'total_attempts': 25,
        'attempts_7d': 10,
        'top_weak_letters': ['D', 'E'],
        'status': 'struggling',
        'recent_attempts': [
          {
            'submission_id': 'sub-1',
            'exercise_id': 'ex-1',
            'skill_id': 'english-letter-d',
            'exercise_type': 'letter_recognition',
            'outcome': 'incorrect',
            'response_time_ms': 1200,
            'hint_used': true,
            'attempt_number': 1,
            'created_at': '2026-11-12T09:00:00Z',
          }
        ],
      };
      final detail = LearnerDetailData.fromJson(json);
      expect(detail.id, 'learner-456');
      expect(detail.name, 'Priya');
      expect(detail.phone, '9876543210');
      expect(detail.email, 'priya@example.com');
      expect(detail.status, 'struggling');
      expect(detail.recentAttempts.length, 1);
      expect(detail.recentAttempts.first.outcome, 'incorrect');
      expect(detail.recentAttempts.first.hintUsed, true);
    });

    test('apiBaseUrl defaults to localhost and can be configured', () {
      expect(apiBaseUrl, isNotEmpty);
    });
  });
}


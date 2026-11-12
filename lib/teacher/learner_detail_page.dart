import 'package:flutter/material.dart';

import 'dashboard_api.dart';

class LearnerDetailPage extends StatefulWidget {
  final String learnerId;
  final DashboardApi api;

  const LearnerDetailPage({
    super.key,
    required this.learnerId,
    required this.api,
  });

  @override
  State<LearnerDetailPage> createState() => _LearnerDetailPageState();
}

class _LearnerDetailPageState extends State<LearnerDetailPage> {
  bool _loading = true;
  String? _error;
  LearnerDetailData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.fetchLearnerDetail(widget.learnerId);
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmDeleteLearner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF303134),
        title: const Text('Delete Learner?', style: TextStyle(color: Color(0xFFE8EAED))),
        content: Text(
          'Are you sure you want to permanently delete ${_data?.name ?? 'this learner'} and all their practice records? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF9AA0A6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9AA0A6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _loading = true);
      try {
        await widget.api.deleteLearner(widget.learnerId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learner deleted successfully.'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
        Navigator.of(context).pop(true); // Return true so dashboard can refresh
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to delete learner: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202124),
        foregroundColor: const Color(0xFFE8EAED),
        title: Text(_data?.name ?? 'Learner Detail'),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: 'Delete Learner',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDeleteLearner,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8AB4F8)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF8AB4F8),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildProfileCard(data),
          const SizedBox(height: 16),
          _buildStatsRow(data),
          const SizedBox(height: 16),
          _buildWeakLettersCard(data),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: const Text(
              'Recent Attempts',
              style: TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAttemptsList(data),
        ],
      ),
    );
  }

  Widget _buildProfileCard(LearnerDetailData data) {
    return Card(
      color: const Color(0xFF303134),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.name,
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(data.status),
              ],
            ),
            const SizedBox(height: 12),
            if (data.batch != null && data.batch!.isNotEmpty)
              _infoRow(Icons.group, 'Batch', data.batch!),
            if (data.phone != null && data.phone!.isNotEmpty)
              _infoRow(Icons.phone, 'Phone', data.phone!),
            if (data.email != null && data.email!.isNotEmpty)
              _infoRow(Icons.email, 'Email', data.email!),
            _infoRow(Icons.language, 'Language', data.preferredLanguage),
            if (data.lastActiveAt != null)
              _infoRow(
                Icons.access_time,
                'Last Active',
                _formatDate(data.lastActiveAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9AA0A6)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(LearnerDetailData data) {
    return Row(
      children: [
        Expanded(
          child: _statBox(
            'Accuracy',
            '${data.accuracyPct}%',
            data.accuracyPct >= 80
                ? const Color(0xFF34A853)
                : data.accuracyPct < 60
                    ? Colors.redAccent
                    : const Color(0xFFFBBC04),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statBox(
            '7d Attempts',
            '${data.attempts7d}',
            const Color(0xFF8AB4F8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statBox(
            'Total',
            '${data.totalAttempts}',
            const Color(0xFFE8EAED),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303134),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakLettersCard(LearnerDetailData data) {
    return Card(
      color: const Color(0xFF303134),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Weak Letters / Skills',
              style: TextStyle(
                color: Color(0xFF9AA0A6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (data.topWeakLetters.isEmpty)
              const Text(
                'None detected yet — great progress!',
                style: TextStyle(color: Color(0xFF34A853), fontSize: 14),
              )
            else
              Wrap(
                spacing: 8,
                children: data.topWeakLetters
                    .map(
                      (letter) => Chip(
                        backgroundColor: const Color(0xFF3C4043),
                        label: Text(
                          letter,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptsList(LearnerDetailData data) {
    if (data.recentAttempts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No attempts recorded yet.',
            style: TextStyle(color: Color(0xFF9AA0A6)),
          ),
        ),
      );
    }

    return Column(
      children: data.recentAttempts.map((att) {
        final isCorrect = att.outcome == 'correct';
        return Card(
          color: const Color(0xFF303134),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? const Color(0xFF34A853) : Colors.redAccent,
            ),
            title: Text(
              att.skillId.isNotEmpty ? att.skillId : att.exerciseId,
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${att.exerciseType} • ${att.responseTimeMs}ms'
              '${att.hintUsed ? ' • hint used' : ''}',
              style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 12),
            ),
            trailing: att.createdAt != null
                ? Text(
                    _formatDate(att.createdAt!),
                    style:
                        const TextStyle(color: Color(0xFF9AA0A6), fontSize: 12),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'struggling':
        bg = Colors.redAccent.withOpacity(0.2);
        fg = Colors.redAccent;
        label = 'Struggling';
        break;
      case 'active':
        bg = const Color(0xFF34A853).withOpacity(0.2);
        fg = const Color(0xFF34A853);
        label = 'Active';
        break;
      case 'inactive':
      default:
        bg = const Color(0xFF5F6368).withOpacity(0.2);
        fg = const Color(0xFF9AA0A6);
        label = 'Inactive';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}


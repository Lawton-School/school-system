import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/ai_tutor_floating_button.dart';

/// Shows a student's own attendance calendar color-coded by daily status.
class StudentAttendanceScreen extends ConsumerWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    return Scaffold(
      floatingActionButton: const AiTutorFloatingButton(),
      appBar: AppBar(title: const Text('My Attendance')),
      body: _AttendanceCalendarView(
        schoolId: session.schoolId,
        studentProfileId: session.profileId,
        studentName: 'My',
      ),
    );
  }
}

/// Shows attendance for each child linked to this parent profile.
class ParentAttendanceScreen extends ConsumerWidget {
  const ParentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final relationshipsAsync = ref.watch(parentRelationshipsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Children\'s Attendance')),
      body: relationshipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (relationships) {
          if (relationships.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No children linked to your account.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            );
          }

          return DefaultTabController(
            length: relationships.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: relationships.length > 2,
                  tabs: relationships.map((r) {
                    final name = r.student?.fullName ?? 'Child';
                    return Tab(text: name);
                  }).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: relationships.map((r) {
                      return _AttendanceCalendarView(
                        schoolId: session.schoolId,
                        studentProfileId: r.studentId,
                        studentName: r.student?.fullName ?? 'Child',
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceCalendarView extends ConsumerStatefulWidget {
  final String schoolId;
  final String studentProfileId;
  final String studentName;

  const _AttendanceCalendarView({
    required this.schoolId,
    required this.studentProfileId,
    required this.studentName,
  });

  @override
  ConsumerState<_AttendanceCalendarView> createState() =>
      _AttendanceCalendarViewState();
}

class _AttendanceCalendarViewState
    extends ConsumerState<_AttendanceCalendarView> {
  List<AttendanceEntryModel>? _records;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AttendanceCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.studentProfileId != widget.studentProfileId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final records = await SchoolOperationsService(client).getAttendanceEntries(
        widget.schoolId,
        studentProfileId: widget.studentProfileId,
      );
      records.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    final records = _records ?? [];
    final total = records.length;
    final present = records.where((r) => r.status == 'present').length;
    final absent = records.where((r) => r.status == 'absent').length;
    final late = records.where((r) => r.status == 'late').length;

    // Keep the UI definition aligned with the backend attendance reports:
    // present + late are counted as attended; excused is reported separately.
    final pct = total > 0
        ? ((present + late) / total * 100).toStringAsFixed(1)
        : '—';

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatCard(
                  label: 'Present',
                  value: '$present',
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: 'Absent',
                  value: '$absent',
                  color: AppTheme.danger,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: 'Late',
                  value: '$late',
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: 'Rate',
                  value: '$pct%',
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Attendance History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No attendance records found.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ...records.map((entry) {
                final color = _statusColor(entry.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(10),
                    border: Border(left: BorderSide(color: color, width: 4)),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.dateLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (entry.sectionName.isNotEmpty)
                              Text(
                                entry.sectionName,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.status.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppTheme.success;
      case 'late':
        return AppTheme.warning;
      case 'excused':
        return AppTheme.secondary;
      case 'absent':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

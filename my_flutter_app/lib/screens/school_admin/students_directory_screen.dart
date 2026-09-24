import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/students_directory_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 24 — Students Directory.
///
/// Read-only directory backed by `get_students_directory()`. Enrollment
/// mutations remain in the dedicated enrollment workflow.
class StudentsDirectoryScreen extends ConsumerStatefulWidget {
  const StudentsDirectoryScreen({super.key});

  @override
  ConsumerState<StudentsDirectoryScreen> createState() =>
      _StudentsDirectoryScreenState();
}

class _StudentsDirectoryScreenState
    extends ConsumerState<StudentsDirectoryScreen> {
  final _searchController = TextEditingController();
  String? _selectedYearId;
  String _feeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final yearsAsync = ref.watch(academicYearsProvider(session.schoolId));

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCHOOL ADMIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Students Directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load academic years: $error',
          onRetry: () => ref.invalidate(academicYearsProvider(session.schoolId)),
        ),
        data: (years) {
          if (years.isEmpty) {
            return const _EmptyState(
              message: 'No academic years are configured yet.',
            );
          }

          final resolvedYearId = _resolveYearId(years);
          final studentsAsync =
              ref.watch(studentsDirectoryProvider(resolvedYearId));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: StitchCard(
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final yearField = DropdownButtonFormField<String>(
                            initialValue: resolvedYearId,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                              isDense: true,
                            ),
                            items: years
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year.id,
                                    child: Text(year.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedYearId = value);
                            },
                          );

                          final searchField = TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Search students',
                              hintText: 'Name, admission number, class or guardian',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          );

                          if (constraints.maxWidth < 700) {
                            return Column(
                              children: [
                                yearField,
                                const SizedBox(height: 10),
                                searchField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              SizedBox(width: 240, child: yearField),
                              const SizedBox(width: 12),
                              Expanded(child: searchField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('All')),
                            ButtonSegment(value: 'paid', label: Text('Paid')),
                            ButtonSegment(value: 'balance', label: Text('Balance')),
                            ButtonSegment(value: 'due_soon', label: Text('Due Soon')),
                            ButtonSegment(value: 'overdue', label: Text('Overdue')),
                            ButtonSegment(value: 'no_invoice', label: Text('No Invoice')),
                          ],
                          selected: {_feeFilter},
                          onSelectionChanged: (values) {
                            setState(() => _feeFilter = values.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: studentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(
                    message: 'Unable to load students: $error',
                    onRetry: () =>
                        ref.invalidate(studentsDirectoryProvider(resolvedYearId)),
                  ),
                  data: (students) {
                    final visible = _filter(students);
                    if (students.isEmpty) {
                      return const _EmptyState(
                        message: 'No students are enrolled for this academic year.',
                      );
                    }
                    if (visible.isEmpty) {
                      return const _EmptyState(
                        message: 'No students match the current filters.',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          studentsDirectoryProvider(resolvedYearId),
                        );
                        await ref.read(
                          studentsDirectoryProvider(resolvedYearId).future,
                        );
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _StudentDirectoryCard(
                          student: visible[index],
                          onTap: () => _showDetails(context, visible[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _resolveYearId(List<AcademicYearModel> years) {
    final selected = _selectedYearId;
    if (selected != null && years.any((year) => year.id == selected)) {
      return selected;
    }
    for (final year in years) {
      if (year.isCurrent) return year.id;
    }
    return years.first.id;
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> students) {
    final query = _searchController.text.trim().toLowerCase();
    return students.where((student) {
      final feeStatus = student['fee_status']?.toString() ?? 'no_invoice';
      if (_feeFilter != 'all' && feeStatus != _feeFilter) return false;
      if (query.isEmpty) return true;

      final haystack = [
        student['student_name'],
        student['student_id'],
        student['class_name'],
        student['section_name'],
        student['guardian_name'],
      ].where((value) => value != null).join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void _showDetails(BuildContext context, Map<String, dynamic> student) {
    final attendance = (student['attendance_rate'] as num?)?.toDouble();
    final balance = (student['fee_balance'] as num?)?.toDouble() ?? 0;
    final currency = student['currency']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(student['student_name']?.toString() ?? 'Student'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Admission Number', student['student_id']),
              _detail(
                'Class',
                [student['class_name'], student['section_name']]
                    .where((value) => value != null && value.toString().isNotEmpty)
                    .join(' · '),
              ),
              _detail('Enrollment Status', student['enrollment_status']),
              _detail('Curriculum', student['curriculum']),
              _detail(
                'Attendance',
                attendance == null ? 'No attendance records' : '${attendance.toStringAsFixed(1)}%',
              ),
              _detail('Guardian', student['guardian_name']),
              _detail('Guardian Phone', student['guardian_phone']),
              _detail('Guardian Email', student['guardian_email']),
              _detail(
                'Fee Balance',
                '$currency ${balance.toStringAsFixed(2)}'.trim(),
              ),
              _detail('Fee Status', student['fee_status']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = value?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.stitchMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              style: const TextStyle(
                color: AppTheme.stitchHeading,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDirectoryCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  const _StudentDirectoryCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final attendance = (student['attendance_rate'] as num?)?.toDouble();
    final feeBalance = (student['fee_balance'] as num?)?.toDouble() ?? 0;
    final currency = student['currency']?.toString() ?? '';
    final feeStatus = student['fee_status']?.toString() ?? 'no_invoice';

    return StitchCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primarySoft,
            child: Text(
              _initial(student['student_name']?.toString()),
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['student_name']?.toString() ?? 'Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.stitchHeading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    student['student_id'],
                    student['class_name'],
                    student['section_name'],
                  ].where((value) => value != null && value.toString().isNotEmpty).join(' • '),
                  style: const TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      attendance == null
                          ? 'Attendance: no records'
                          : 'Attendance: ${attendance.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Balance: $currency ${feeBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if ((student['guardian_name']?.toString() ?? '').isNotEmpty)
                      Text(
                        'Guardian: ${student['guardian_name']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StitchChip(
            label: feeStatus.replaceAll('_', ' '),
            variant: _feeVariant(feeStatus),
          ),
        ],
      ),
    );
  }

  static String _initial(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'S' : value.substring(0, 1).toUpperCase();
  }

  static StitchChipVariant _feeVariant(String status) {
    switch (status) {
      case 'paid':
        return StitchChipVariant.success;
      case 'overdue':
      case 'due_soon':
        return StitchChipVariant.warn;
      default:
        return StitchChipVariant.neutral;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 50,
              color: AppTheme.stitchMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.stitchMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

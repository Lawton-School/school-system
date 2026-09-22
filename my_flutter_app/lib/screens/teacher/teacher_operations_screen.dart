import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../controllers/teacher_controllers.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/teacher_ai_floating_button.dart';

// ─────────────────────────────────────────────────────────────────
// TEACHER OPERATIONS (Teacher role tabs)
// ─────────────────────────────────────────────────────────────────

class TeacherOperationsScreen extends ConsumerWidget {
  const TeacherOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        floatingActionButton: const TeacherAiFloatingButton(),
        appBar: AppBar(
          title: const Text('Operations & Leave'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.checklist_rounded), text: 'Attendance'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'Announcements'),
              Tab(icon: Icon(Icons.event_busy_rounded), text: 'Leave'),
              Tab(icon: Icon(Icons.access_time_rounded), text: 'Clock In/Out'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AttendanceTab(session: session),
            _AnnouncementsTab(session: session),
            _LeaveTab(session: session),
            _ClockInOutTab(session: session),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SCHOOL ADMIN OPERATIONS (Admin role tabs)
// ─────────────────────────────────────────────────────────────────

class SchoolAdminOperationsPage extends ConsumerWidget {
  const SchoolAdminOperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Operations & Leave'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_busy_rounded), text: 'Leave Review'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'Announcements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LeaveReviewTab(session: session),
            _AnnouncementsTab(session: session),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB: ATTENDANCE (Teacher)
// ─────────────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerStatefulWidget {
  final ActiveSession session;
  const _AttendanceTab({required this.session});

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();
  ClassSectionModel? _selectedSection;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _markAttendance(
    List<ClassSectionModel> sections,
    List<AttendanceEntryModel> existing,
  ) async {
    if (_selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a section first.')),
      );
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final service = SchoolOperationsService(client);

    // Get students enrolled in section
    final enrollments = await AcademicStructureService(client)
        .getEnrollments(widget.session.schoolId, classSectionId: _selectedSection!.id);

    if (!mounted) return;
    if (enrollments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students enrolled in this section.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MarkAttendanceSheet(
        session: widget.session,
        service: service,
        section: _selectedSection!,
        date: _selectedDate,
        enrollments: enrollments,
        existing: existing,
        onSaved: () {
          setState(() {}); // trigger refresh
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(
      teacherSectionsProvider((widget.session.schoolId, widget.session.profileId)),
    );

    return sectionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sections) {
        return FutureBuilder<List<AttendanceEntryModel>>(
          future: SchoolOperationsService(ref.read(supabaseClientProvider))
              .getAttendanceEntries(
            widget.session.schoolId,
            date: _selectedDate,
            classSectionId: _selectedSection?.id,
          ),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Scaffold(
              body: Column(
                children: [
                  // Filter bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderDark),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<ClassSectionModel>(
                            initialValue: _selectedSection,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                              hintText: 'All Sections',
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Sections')),
                              ...sections.map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))),
                            ],
                            onChanged: (v) => setState(() => _selectedSection = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : entries.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.checklist_rounded, size: 48, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    const Text('No attendance records for this date.', style: TextStyle(color: AppTheme.textMuted)),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _markAttendance(sections, entries),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Mark Attendance'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: entries.length,
                                separatorBuilder: (_, i) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _attendanceColor(entry.status).withAlpha(25),
                                      child: Text(
                                        entry.studentName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(color: _attendanceColor(entry.status), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(entry.studentName),
                                    subtitle: Text('${entry.sectionName} • ${entry.dateLabel}'),
                                    trailing: _StatusChip(status: entry.status),
                                  );
                                },
                              ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _markAttendance(sections, entries),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Mark Attendance'),
              ),
            );
          },
        );
      },
    );
  }

  Color _attendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return AppTheme.success;
      case 'late': return AppTheme.warning;
      case 'excused': return AppTheme.secondary;
      case 'absent': return AppTheme.danger;
      default: return AppTheme.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// SHEET: MARK ATTENDANCE
// ─────────────────────────────────────────────────────────────────

class _MarkAttendanceSheet extends ConsumerStatefulWidget {
  final ActiveSession session;
  final SchoolOperationsService service;
  final ClassSectionModel section;
  final DateTime date;
  final List<StudentEnrollmentModel> enrollments;
  final List<AttendanceEntryModel> existing;
  final VoidCallback onSaved;

  const _MarkAttendanceSheet({
    required this.session,
    required this.service,
    required this.section,
    required this.date,
    required this.enrollments,
    required this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_MarkAttendanceSheet> createState() => _MarkAttendanceSheetState();
}

class _MarkAttendanceSheetState extends ConsumerState<_MarkAttendanceSheet> {
  final Map<String, String> _statuses = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill existing statuses
    for (final entry in widget.existing) {
      _statuses[entry.studentProfileId] = entry.status;
    }
    // Default absent for unentered students
    for (final e in widget.enrollments) {
      _statuses.putIfAbsent(e.studentProfileId, () => 'present');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(teacherRepositoryProvider);
      final records = widget.enrollments.map((enrollment) {
        return {
          'student_id': enrollment.studentProfileId,
          'status': _statuses[enrollment.studentProfileId] ?? 'present',
          'remarks': null,
        };
      }).toList();

      await repo.submitAttendanceRollCall(
        schoolId: widget.session.schoolId,
        classSectionId: widget.section.id,
        date: widget.date,
        records: records,
      );

      widget.onSaved();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance roll call recorded ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mark Attendance — ${widget.section.displayName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save All'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: widget.enrollments.length,
                itemBuilder: (context, i) {
                  final e = widget.enrollments[i];
                  final name = e.student?.fullName ?? e.studentProfileId;
                  final current = _statuses[e.studentProfileId] ?? 'present';
                  return ListTile(
                    title: Text(name),
                    subtitle: e.rollNumber != null ? Text('Roll: ${e.rollNumber}') : null,
                    trailing: DropdownButton<String>(
                      value: current,
                      underline: const SizedBox(),
                      items: ['present', 'absent', 'late', 'excused'].map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: _StatusChip(status: s),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _statuses[e.studentProfileId] = v);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB: ANNOUNCEMENTS
// ─────────────────────────────────────────────────────────────────

class _AnnouncementsTab extends ConsumerWidget {
  final ActiveSession session;
  const _AnnouncementsTab({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider(session.schoolId));

    return Scaffold(
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_rounded, size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('No announcements yet.', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(item.audience, style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item.message, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(item.createdBy, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          const Spacer(),
                          Text(item.createdAtLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostAnnouncementSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Post'),
      ),
    );
  }

  void _showPostAnnouncementSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostAnnouncementSheet(session: session, ref: ref),
    );
  }
}

class _PostAnnouncementSheet extends ConsumerStatefulWidget {
  final ActiveSession session;
  final WidgetRef ref;

  const _PostAnnouncementSheet({required this.session, required this.ref});

  @override
  ConsumerState<_PostAnnouncementSheet> createState() => _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState extends ConsumerState<_PostAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _targetRole = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await SchoolOperationsService(client).createAnnouncement(
        schoolId: widget.session.schoolId,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        targetRole: _targetRole,
        authorProfileId: widget.session.profileId,
      );
      ref.invalidate(announcementsProvider(widget.session.schoolId));
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Post Announcement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _targetRole,
            decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Everyone')),
              DropdownMenuItem(value: 'teachers', child: Text('Teachers')),
              DropdownMenuItem(value: 'parents', child: Text('Parents')),
              DropdownMenuItem(value: 'students', child: Text('Students')),
            ],
            onChanged: (v) => setState(() => _targetRole = v ?? 'all'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post Announcement'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB: LEAVE (Teacher — my requests)
// ─────────────────────────────────────────────────────────────────

class _LeaveTab extends ConsumerWidget {
  final ActiveSession session;
  const _LeaveTab({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveAsync = ref.watch(myLeaveRequestsProvider((session.schoolId, session.profileId)));

    return Scaffold(
      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('No leave requests yet.', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _LeaveCard(item: item, showActions: false, session: session, ref: ref);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request Leave'),
      ),
    );
  }

  void _showRequestSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LeaveRequestSheet(session: session, ref: ref),
    );
  }
}

class _LeaveRequestSheet extends ConsumerStatefulWidget {
  final ActiveSession session;
  final WidgetRef ref;
  const _LeaveRequestSheet({required this.session, required this.ref});

  @override
  ConsumerState<_LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends ConsumerState<_LeaveRequestSheet> {
  final _reasonCtrl = TextEditingController();
  String _leaveType = 'annual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate.add(const Duration(days: 1));
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await SchoolOperationsService(client).submitLeaveRequest(
        schoolId: widget.session.schoolId,
        staffProfileId: widget.session.profileId,
        leaveType: _leaveType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonCtrl.text.trim(),
      );
      ref.invalidate(myLeaveRequestsProvider((widget.session.schoolId, widget.session.profileId)));
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Request Leave', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _leaveType,
            decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'annual', child: Text('Annual Leave')),
              DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Leave')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _leaveType = v ?? 'annual'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text('From: ${fmt(_startDate)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text('To: ${fmt(_endDate)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB: LEAVE REVIEW (School Admin)
// ─────────────────────────────────────────────────────────────────

class _LeaveReviewTab extends ConsumerWidget {
  final ActiveSession session;
  const _LeaveReviewTab({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveAsync = ref.watch(leaveRequestsProvider(session.schoolId));

    return leaveAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No requests to review.', style: TextStyle(color: AppTheme.textMuted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _LeaveCard(item: item, showActions: item.status == 'pending', session: session, ref: ref);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED: LEAVE CARD (with optional approve/reject buttons)
// ─────────────────────────────────────────────────────────────────

class _LeaveCard extends ConsumerStatefulWidget {
  final StaffLeaveRequestModel item;
  final bool showActions;
  final ActiveSession session;
  final WidgetRef ref;

  const _LeaveCard({
    required this.item,
    required this.showActions,
    required this.session,
    required this.ref,
  });

  @override
  ConsumerState<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends ConsumerState<_LeaveCard> {
  bool _acting = false;

  Future<void> _act(String status) async {
    setState(() => _acting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await SchoolOperationsService(client).updateLeaveStatus(
        widget.item.id,
        status,
        widget.session.profileId,
      );
      ref.invalidate(leaveRequestsProvider(widget.session.schoolId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $status ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.employeeName, style: Theme.of(context).textTheme.titleMedium)),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item.leaveType} • ${item.dateRange}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            if (item.reason != null && item.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.reason!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (widget.showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _acting ? null : () => _act('approved'),
                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                      label: const Text('Approve', style: TextStyle(color: AppTheme.success)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _acting ? null : () => _act('rejected'),
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
                      label: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB: CLOCK IN / OUT (Teacher)
// ─────────────────────────────────────────────────────────────────

class _ClockInOutTab extends ConsumerStatefulWidget {
  final ActiveSession session;
  const _ClockInOutTab({required this.session});

  @override
  ConsumerState<_ClockInOutTab> createState() => _ClockInOutTabState();
}

class _ClockInOutTabState extends ConsumerState<_ClockInOutTab> {
  bool _loading = false;
  StaffAttendanceModel? _todayRecord;

  @override
  void initState() {
    super.initState();
    _fetchToday();
  }

  Future<void> _fetchToday() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final records = await SchoolOperationsService(client)
          .getStaffAttendance(widget.session.schoolId, date: DateTime.now());
      final mine = records.where((r) => r.staffProfileId == widget.session.profileId).toList();
      if (mounted) setState(() => _todayRecord = mine.isNotEmpty ? mine.first : null);
    } catch (_) {}
  }

  Future<void> _clockIn() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final record = await SchoolOperationsService(client)
          .clockIn(widget.session.schoolId, widget.session.profileId);
      setState(() => _todayRecord = record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked in ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clockOut() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final record = await SchoolOperationsService(client)
          .clockOut(widget.session.schoolId, widget.session.profileId);
      setState(() => _todayRecord = record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clocked out ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasClockIn = _todayRecord?.clockIn != null;
    final hasClockOut = _todayRecord?.clockOut != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withAlpha(20),
              ),
              child: const Icon(Icons.access_time_rounded, size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              '${now.day}/${now.month}/${now.year}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_todayRecord != null) ...[
              Text(
                'Clock In: ${_todayRecord!.clockInLabel}',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
              ),
              if (hasClockOut)
                Text(
                  'Clock Out: ${_todayRecord!.clockOutLabel}',
                  style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
                ),
            ] else ...[
              const Text('Not clocked in today.', style: TextStyle(color: AppTheme.textMuted)),
            ],
            const SizedBox(height: 32),
            if (!hasClockIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _clockIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Clock In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              )
            else if (!hasClockOut)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _clockOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Clock Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.success),
                      SizedBox(width: 8),
                      Text('Attendance complete for today.'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED: STATUS CHIP
// ─────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
    switch (status.toLowerCase()) {
      case 'present': return AppTheme.success;
      case 'approved': return AppTheme.success;
      case 'late': return AppTheme.warning;
      case 'pending': return AppTheme.warning;
      case 'excused': return AppTheme.secondary;
      case 'absent': return AppTheme.danger;
      case 'rejected': return AppTheme.danger;
      default: return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

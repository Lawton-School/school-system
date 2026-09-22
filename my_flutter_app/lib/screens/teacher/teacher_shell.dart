import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../controllers/teacher_controllers.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';
import '../../widgets/teacher_ai_floating_button.dart';
import '../operations/sync_diagnostics_screen.dart';
import 'course_builder_screen.dart';
import 'teacher_gradebook_screen.dart';

// ─────────────────────────────────────────────────────────────────
// TEACHER SHELL
// ─────────────────────────────────────────────────────────────────

class TeacherShell extends ConsumerWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      floatingActionButton: const TeacherAiFloatingButton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TEACHER DASHBOARD (STITCH VISUAL FIDELITY - 03_teacher_dashboard)
// ─────────────────────────────────────────────────────────────────

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final dataAsync = ref.watch(teacherDashboardControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      floatingActionButton: const TeacherAiFloatingButton(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF8B7EF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Text('Z', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session?.schoolName ?? 'ZivoConnect EMS',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.stitchHeading),
                ),
                Text(
                  'Teacher Workspace · ${session?.role ?? "Teacher"}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const StitchChip(label: 'Term 1 · 2026', variant: StitchChipVariant.primary, icon: Icons.calendar_today_rounded),
          const SizedBox(width: 8),
          const Center(child: SyncStatusBadge()),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.stitchMuted),
            tooltip: 'Sync Diagnostics',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncDiagnosticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.stitchMuted),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(activeSessionProvider.notifier).clearSession();
              await AuthService(ref.read(supabaseClientProvider)).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
        data: (data) => _buildDashboardContent(context, ref, session, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    ActiveSession? session,
    TeacherDashboardMetrics data,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. PAGE TITLE & HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TEACHER WORKSPACE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Good morning, Teacher',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.stitchHeading,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here is what needs your attention today at ${session?.schoolName ?? "Your School"}.',
                          style: const TextStyle(fontSize: 13.5, color: AppTheme.stitchMuted),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CourseBuilderScreen()),
                        ),
                        icon: const Icon(Icons.auto_stories_rounded, size: 16),
                        label: const Text('Course Builder'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.stitchHeading,
                          side: const BorderSide(color: AppTheme.stitchBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TeacherGradebookScreen()),
                        ),
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('Gradebook'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.stitchHeading,
                          side: const BorderSide(color: AppTheme.stitchBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/teacher/operations'),
                        icon: const Icon(Icons.fact_check_rounded, size: 16, color: Colors.white),
                        label: const Text('Take Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. OFFLINE SYNC BANNER
              const StitchSyncBanner(),
              const SizedBox(height: 20),

              // 3. 4 KPI METRIC CARDS
              GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.6 : 1.4,
                children: [
                  StitchKpiCard(
                    label: 'Classes Today',
                    value: '${data.classesToday}',
                    hint: '${data.classesCompleted} completed · ${data.classesRemaining} remaining',
                    icon: Icons.groups_rounded,
                  ),
                  StitchKpiCard(
                    label: 'Attendance',
                    value: '${data.attendancePending}',
                    hint: data.attendancePending > 0 ? 'Classes pending · Due today' : 'All classes recorded',
                    statusColor: data.attendancePending > 0 ? StitchChipVariant.warn : StitchChipVariant.success,
                    icon: Icons.fact_check_rounded,
                  ),
                  StitchKpiCard(
                    label: 'To Mark',
                    value: '${data.submissionsToMark}',
                    hint: 'Submissions · ${data.assignmentsToMark} assignments',
                    statusColor: data.submissionsToMark > 0 ? StitchChipVariant.warn : StitchChipVariant.neutral,
                    icon: Icons.grading_rounded,
                  ),
                  StitchKpiCard(
                    label: 'Messages',
                    value: '${data.unreadMessages}',
                    hint: 'Unread · ${data.unreadParentSenders} parents',
                    statusColor: data.unreadMessages > 0 ? StitchChipVariant.info : StitchChipVariant.neutral,
                    icon: Icons.forum_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. MAIN LAYOUT: SCHEDULE & WORKLOAD (LEFT) + ACTIONS & CLASSES (RIGHT)
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildScheduleCard(data.schedule, context),
                          const SizedBox(height: 18),
                          _buildAssignmentsTable(data.assignments, context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildPriorityActions(data.priorityActions, context),
                          const SizedBox(height: 18),
                          _buildMyClasses(data.classes, context),
                          const SizedBox(height: 18),
                          _buildAnnouncements(data.announcements),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildPriorityActions(data.priorityActions, context),
                    const SizedBox(height: 16),
                    _buildScheduleCard(data.schedule, context),
                    const SizedBox(height: 16),
                    _buildAssignmentsTable(data.assignments, context),
                    const SizedBox(height: 16),
                    _buildMyClasses(data.classes, context),
                    const SizedBox(height: 16),
                    _buildAnnouncements(data.announcements),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ── SCHEDULE TIMELINE ──────────────────────────────────────────
  Widget _buildScheduleCard(List<TeacherScheduleItem> schedule, BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: "Today's Schedule",
            subtitle: '${schedule.length} teaching periods today',
            trailing: TextButton(
              onPressed: () => context.go('/teacher/operations'),
              child: const Text('Open roll call →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 14),
          if (schedule.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No classes scheduled for today', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedule.length,
              separatorBuilder: (_, _) => const Divider(height: 20, color: Color(0xFFF0F2F6)),
              itemBuilder: (context, index) {
                final item = schedule[index];
                final statusVariant = item.statusVariant == 'success'
                    ? StitchChipVariant.success
                    : item.statusVariant == 'primary'
                        ? StitchChipVariant.primary
                        : StitchChipVariant.neutral;

                final isNext = item.statusVariant == 'primary';

                return Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        item.time,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.stitchMuted),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isNext ? AppTheme.primary : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isNext ? AppTheme.primarySoft : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calculate_rounded,
                        size: 18,
                        color: isNext ? AppTheme.primaryDark : AppTheme.stitchMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.subject.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryDark, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.classSectionName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading),
                          ),
                          Text(
                            '${item.room.isNotEmpty ? item.room : "No room"} · ${item.studentCount} students',
                            style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted),
                          ),
                        ],
                      ),
                    ),
                    StitchChip(label: item.status, variant: statusVariant),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── ASSIGNMENTS & MARKING TABLE ─────────────────────────────────
  Widget _buildAssignmentsTable(List<Map<String, dynamic>> assignments, BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: 'Assignments & Marking',
            subtitle: 'Current assessment workload and submissions',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherGradebookScreen())),
              child: const Text('Open gradebook →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 12),
          if (assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No active assignments or submissions to mark', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 46,
                horizontalMargin: 8,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('ASSIGNMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('DUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('SUBMITTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('MARKED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                ],
                rows: assignments.map((a) {
                  final variant = a['variant'] == 'warn'
                      ? StitchChipVariant.warn
                      : a['variant'] == 'info'
                          ? StitchChipVariant.info
                          : StitchChipVariant.neutral;

                  return DataRow(cells: [
                    DataCell(Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                    DataCell(Text(a['class']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a['due']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.stitchMuted))),
                    DataCell(Text(a['sub']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text(a['marked']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(StitchChip(label: a['status']?.toString() ?? '', variant: variant)),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── PRIORITY ACTIONS ───────────────────────────────────────────
  Widget _buildPriorityActions(List<TeacherPriorityActionItem> actions, BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Priority Actions',
            subtitle: 'Items needing attention today',
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('All tasks are up to date. No pending actions.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF0F2F6)),
              itemBuilder: (context, index) {
                final a = actions[index];
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: a.type == 'attendance'
                            ? AppTheme.stitchWarnSoft
                            : a.type == 'gradebook'
                                ? AppTheme.stitchInfoSoft
                                : AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        a.type == 'attendance'
                            ? Icons.fact_check_rounded
                            : a.type == 'gradebook'
                                ? Icons.grading_rounded
                                : Icons.notifications_rounded,
                        size: 18,
                        color: a.type == 'attendance'
                            ? AppTheme.stitchWarnText
                            : a.type == 'gradebook'
                                ? AppTheme.stitchInfoText
                                : AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(a.meta, style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        if (a.type == 'attendance') {
                          context.go('/teacher/operations');
                        } else if (a.type == 'gradebook') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherGradebookScreen()));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Opening ${a.title}...')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.stitchBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(a.action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── MY CLASSES ────────────────────────────────────────────────
  Widget _buildMyClasses(List<Map<String, dynamic>> classes, BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: 'My Classes',
            subtitle: 'Current teaching assignments',
            trailing: TextButton(
              onPressed: () => context.go('/teacher/operations'),
              child: const Text('All classes →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 12),
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No classes assigned to this profile', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF0F2F6)),
              itemBuilder: (context, index) {
                final c = classes[index];
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c['code']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.primaryDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(c['subjects']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                        ],
                      ),
                    ),
                    StitchChip(label: '${c["count"] ?? 0} students', variant: StitchChipVariant.primary),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── ANNOUNCEMENTS ─────────────────────────────────────────────
  Widget _buildAnnouncements(List<Map<String, dynamic>> announcements) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Recent Announcements',
            subtitle: 'School-wide staff notices',
          ),
          const SizedBox(height: 12),
          if (announcements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No recent announcements', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF0F2F6)),
              itemBuilder: (context, index) {
                final item = announcements[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_rounded, size: 18, color: AppTheme.stitchMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title']?.toString() ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(item['meta']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';
import '../finance/parent_fees_screen.dart';
import '../operations/bus_tracking_screen.dart';
import '../operations/marketplace_screen.dart';
import '../operations/sync_diagnostics_screen.dart';
import 'parent_academics_screen.dart';
import 'parent_messages_screen.dart';

// ─────────────────────────────────────────────────────────────────
// PARENT SHELL
// ─────────────────────────────────────────────────────────────────

class ParentShell extends ConsumerWidget {
  final Widget child;
  const ParentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(body: child);
  }
}

// ─────────────────────────────────────────────────────────────────
// PARENT DASHBOARD (STITCH VISUAL FIDELITY - 06_parent_dashboard)
// ─────────────────────────────────────────────────────────────────

class ParentDashboardPage extends ConsumerWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final childrenAsync = ref.watch(parentChildrenProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);
    final selectedChildIndex = ref.watch(selectedChildIndexProvider);
    final dataAsync = ref.watch(parentDashboardDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
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
                const Text(
                  'Parent Workspace · Family Portal',
                  style: TextStyle(fontSize: 11, color: AppTheme.stitchMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const Center(child: SyncStatusBadge()),
          IconButton(
            icon: const Icon(Icons.forum_rounded, color: AppTheme.primaryDark),
            tooltip: 'Messages',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentMessagesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.stitchMuted),
            tooltip: 'Sync Diagnostics',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncDiagnosticsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.stitchMuted),
            tooltip: 'Switch Profile',
            onPressed: () async {
              await ref.read(activeSessionProvider.notifier).clearSession();
            },
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
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading authorized children: $err')),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.family_restroom_rounded, size: 36, color: AppTheme.primaryDark),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Enrolled Children Linked',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.stitchHeading),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No student profiles are linked to your guardian account yet.\nPlease contact the school administration office to verify and link your child.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.stitchMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => ref.refresh(parentChildrenProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Check for Updates'),
                    ),
                  ],
                ),
              ),
            );
          }

          final currentChild = activeChild ?? children.first;
          final dashboardData = dataAsync.asData?.value;

          return _buildParentContent(
            context,
            ref,
            children,
            currentChild,
            selectedChildIndex,
            dashboardData,
            dataAsync.isLoading,
          );
        },
      ),
    );
  }

  Widget _buildParentContent(
    BuildContext context,
    WidgetRef ref,
    List<AuthorizedChild> children,
    AuthorizedChild activeChild,
    int selectedChildIndex,
    ParentDashboardData? data,
    bool isLoading,
  ) {
    final currencySummary = (data?.currencySummaries.isNotEmpty ?? false)
        ? data!.currencySummaries.first
        : null;

    final attendanceStr = data?.attendanceRate != null ? '${data!.attendanceRate!.toStringAsFixed(1)}%' : '—';
    final academicStr = data?.academicAverage != null ? '${data!.academicAverage!.toStringAsFixed(1)}%' : '—';
    final feesStr = currencySummary != null
        ? currencySummary.formattedOutstanding
        : 'All Clear';
    final feesHint = currencySummary != null
        ? '${currencySummary.currency} · ${currencySummary.settledPercent.toStringAsFixed(0)}% settled'
        : 'No pending invoices';

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
                          'PARENT WORKSPACE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Parent Dashboard',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.stitchHeading,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A calm overview focused on ${activeChild.fullName}, school communication, and fees.',
                          style: const TextStyle(fontSize: 13, color: AppTheme.stitchMuted),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentMessagesScreen()),
                        ),
                        icon: const Icon(Icons.forum_rounded, size: 16, color: Colors.white),
                        label: const Text('Message Teacher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

              // 3. 4 KPI METRICS
              GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.6 : 1.4,
                children: [
                  StitchKpiCard(
                    label: 'Attendance',
                    value: attendanceStr,
                    hint: data?.attendanceHint ?? 'Recorded attendance',
                    statusColor: StitchChipVariant.success,
                    icon: Icons.event_available_rounded,
                  ),
                  StitchKpiCard(
                    label: 'Academic Average',
                    value: academicStr,
                    hint: data?.academicHint ?? 'Term average',
                    icon: Icons.school_rounded,
                  ),
                  StitchKpiCard(
                    label: 'Outstanding Fees',
                    value: feesStr,
                    hint: feesHint,
                    statusColor: currencySummary != null && currencySummary.outstanding > 0
                        ? StitchChipVariant.warn
                        : StitchChipVariant.success,
                    icon: Icons.receipt_long_rounded,
                  ),
                  StitchKpiCard(
                    label: 'Assignments',
                    value: '${data?.assignmentsDueCount ?? 0} Due',
                    hint: data?.assignmentsHint ?? '0 overdue',
                    icon: Icons.assignment_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. MAIN LAYOUT: CHILD PROFILE & ACADEMIC ACTIVITY (LEFT) + CHILDREN & ANNOUNCEMENTS (RIGHT)
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildChildSummaryCard(context, activeChild, data),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildChildrenSwitcher(children, selectedChildIndex, ref),
                          const SizedBox(height: 18),
                          _buildAnnouncementCard(data?.announcements ?? []),
                          const SizedBox(height: 18),
                          _buildQuickModuleGrid(context),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildChildrenSwitcher(children, selectedChildIndex, ref),
                    const SizedBox(height: 16),
                    _buildChildSummaryCard(context, activeChild, data),
                    const SizedBox(height: 16),
                    _buildAnnouncementCard(data?.announcements ?? []),
                    const SizedBox(height: 16),
                    _buildQuickModuleGrid(context),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
  // ── CHILD SUMMARY CARD ─────────────────────────────────────────
  Widget _buildChildSummaryCard(
    BuildContext context,
    AuthorizedChild activeChild,
    ParentDashboardData? data,
  ) {
    final recentLessons = [
      {
        'title': 'Next Lesson',
        'meta': data?.nextLesson ?? 'No upcoming lesson scheduled',
        'badge': 'Schedule',
        'variant': 'primary',
      },
      {
        'title': 'Latest Result',
        'meta': data?.latestResult ?? 'No grades published yet',
        'badge': 'Academic',
        'variant': 'success',
      },
      {
        'title': 'Next Fee Date',
        'meta': data?.nextFeeDate ?? 'All installments up to date',
        'badge': 'Finance',
        'variant': 'warn',
      },
    ];

    final activities = data?.recentActivity ?? const [];

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: '${activeChild.fullName} · ${activeChild.className}',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentAcademicsScreen())),
              child: const Text('View Full Profile →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Quick Items (Next Lesson, Latest Result, Next Fee Date)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return GridView.count(
                crossAxisCount: isSmall ? 1 : 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isSmall ? 4.5 : 1.9,
                children: recentLessons.map((item) {
                  final variant = item['variant'] == 'success'
                      ? StitchChipVariant.success
                      : item['variant'] == 'warn'
                          ? StitchChipVariant.warn
                          : StitchChipVariant.primary;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.stitchBorder),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(item['meta'] ?? '', style: const TextStyle(fontSize: 10.5, color: AppTheme.stitchMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        StitchChip(label: item['badge'] ?? '', variant: variant),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // Recent Academic Activity
          StitchSectionHeader(
            title: 'Recent Academic Activity',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentAcademicsScreen())),
              child: const Text('Academics →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 10),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No recent academic activity recorded for this student', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final act = activities[index];
                final variant = act.variant == 'success' ? StitchChipVariant.success : StitchChipVariant.primary;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.stitchBorder),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            const SizedBox(height: 2),
                            Text(act.meta, style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                          ],
                        ),
                      ),
                      StitchChip(label: act.badge, variant: variant),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── CHILDREN SWITCHER CARD ────────────────────────────────────
  Widget _buildChildrenSwitcher(List<AuthorizedChild> children, int selectedIndex, WidgetRef ref) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(title: 'Children Enrolled'),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = children[index];
              final isSelected = index == selectedIndex;

              return InkWell(
                onTap: () => ref.read(selectedChildIndexProvider.notifier).state = index,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.stitchBorder, width: isSelected ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? const Color(0xFFFBFBFF) : Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            '${c.className}${c.campus != null ? " · ${c.campus}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted),
                          ),
                        ],
                      ),
                      StitchChip(
                        label: isSelected ? 'Selected' : 'Switch',
                        variant: isSelected ? StitchChipVariant.success : StitchChipVariant.neutral,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── ANNOUNCEMENT CARD ─────────────────────────────────────────
  Widget _buildAnnouncementCard(List<Map<String, dynamic>> announcements) {
    final first = announcements.isNotEmpty ? announcements.first : null;

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(title: first?['title']?.toString() ?? 'Latest Announcement'),
          const SizedBox(height: 8),
          Text(
            first?['body']?.toString() ?? 'No active announcements for your enrolled children.',
            style: const TextStyle(fontSize: 12, color: AppTheme.stitchMuted, height: 1.5),
          ),
          if (first != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Open announcement →',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  // ── QUICK MODULE ACCESS ───────────────────────────────────────
  Widget _buildQuickModuleGrid(BuildContext context) {
    final modules = [
      _ModuleLink(
        icon: Icons.bar_chart_rounded,
        label: 'Academics & Reports',
        color: AppTheme.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentAcademicsScreen())),
      ),
      _ModuleLink(
        icon: Icons.receipt_long_rounded,
        label: 'Fees & Payments',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentFeesScreen())),
      ),
      _ModuleLink(
        icon: Icons.forum_rounded,
        label: 'School Messages',
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentMessagesScreen())),
      ),
      _ModuleLink(
        icon: Icons.directions_bus_rounded,
        label: 'Bus Tracking & Fleet',
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusTrackingScreen())),
      ),
      _ModuleLink(
        icon: Icons.storefront_rounded,
        label: 'School Marketplace',
        color: const Color(0xFF14B8A6),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
      ),
      _ModuleLink(
        icon: Icons.sync_rounded,
        label: 'Sync Status',
        color: const Color(0xFF64748B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncDiagnosticsScreen())),
      ),
    ];

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(title: 'Portal Services'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: modules.map((m) {
              return Material(
                borderRadius: BorderRadius.circular(10),
                color: m.color.withAlpha(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: m.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Icon(m.icon, size: 20, color: m.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.label,
                            style: TextStyle(color: m.color, fontWeight: FontWeight.w700, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ModuleLink {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _ModuleLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}


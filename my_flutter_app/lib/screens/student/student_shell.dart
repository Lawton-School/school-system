import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../auth/profile_picker_screen.dart';
import '../finance/parent_fees_screen.dart';
import '../school_admin/report_cards_screen.dart';
import '../../widgets/ai_tutor_floating_button.dart';
import 'ai_tutor_screen.dart';
import 'student_attendance_screen.dart';
import 'student_lms_screen.dart';

// ─────────────────────────────────────────────────────────────────
// STUDENT SHELL
// ─────────────────────────────────────────────────────────────────

class StudentShell extends ConsumerWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String location = '';
    try {
      location = GoRouterState.of(context).uri.toString();
    } catch (_) {}
    final isAiTutor = location.contains('/student/ai-tutor');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: child,
      floatingActionButton: isAiTutor ? null : const AiTutorFloatingButton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STUDENT DASHBOARD (RESPONSIVE: MOBILE, TABLET & DESKTOP)
// ─────────────────────────────────────────────────────────────────

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  static const Color primary = Color(0xFF6557F5);
  static const Color primaryDark = Color(0xFF5142E8);
  static const Color background = Color(0xFFF6F7FB);
  static const Color text = Color(0xFF172033);
  static const Color muted = Color(0xFF74809A);
  static const Color green = Color(0xFF18B77A);
  static const Color pink = Color(0xFFF04F8A);
  static const Color orange = Color(0xFFF5A623);
  static const Color blue = Color(0xFF3985F7);

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _activeNav = 0;

  void _onNavTap(int index) {
    setState(() => _activeNav = index);
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()));
    } else if (index == 3) {
      _showProfileSheet(context);
    }
  }

  void _showProfileSheet(BuildContext context) {
    final session = ref.read(activeSessionProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E2FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded, color: StudentDashboardPage.primaryDark, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session?.schoolName ?? 'Student Profile',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: StudentDashboardPage.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Role: Student • Online',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: StudentDashboardPage.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFEDEFF5)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: StudentDashboardPage.primary, size: 20),
              ),
              title: Text('Switch Profile / School', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded, color: StudentDashboardPage.muted),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePickerScreen()));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFFF4D67), size: 20),
              ),
              title: Text('Log Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFFFF4D67))),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(activeSessionProvider.notifier).clearSession();
                await AuthService(ref.read(supabaseClientProvider)).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final schoolId = session?.schoolId ?? '';

    final coursesAsync = ref.watch(coursesProvider(schoolId));
    final assignmentsAsync = ref.watch(assignmentsProvider((schoolId, null)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1024;
        final isTablet = screenWidth >= 640 && screenWidth < 1024;
        final isMobile = screenWidth < 640;

        return Scaffold(
          backgroundColor: StudentDashboardPage.background,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 68 : 14),
            child: const AiTutorFloatingButton(),
          ),
          body: SafeArea(
            child: Row(
              children: [
                // Desktop left navigation rail/sidebar
                if (isDesktop)
                  _StudentDesktopSidebar(
                    activeIndex: _activeNav,
                    onTap: _onNavTap,
                    onProfileTap: () => _showProfileSheet(context),
                  ),

                // Main Dashboard Body
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1160 : (isTablet ? 780 : 540),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 18 : (isTablet ? 24 : 32),
                                vertical: isMobile ? 16 : 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TopBar(
                                    schoolName: session?.schoolName ?? 'Greenwood High School',
                                    onProfileTap: () => _showProfileSheet(context),
                                  ),
                                  const SizedBox(height: 24),
                                  const _WelcomeHeader(),
                                  const SizedBox(height: 22),
                                  _StatsGrid(
                                    coursesCount: coursesAsync.valueOrNull?.length ?? 2,
                                    pendingCount: assignmentsAsync.valueOrNull?.length ?? 1,
                                    isTabletOrDesktop: !isMobile,
                                  ),
                                  const SizedBox(height: 20),

                                  // Two-column responsive section for Tablet and Desktop
                                  if (!isMobile)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left primary column: Continue Learning & Assignments
                                        Expanded(
                                          flex: 6,
                                          child: Column(
                                            children: [
                                              _ContinueLearningCard(
                                                courses: coursesAsync.valueOrNull ?? [],
                                                onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                              ),
                                              const SizedBox(height: 20),
                                              _AssignmentsCard(
                                                assignments: assignmentsAsync.valueOrNull ?? [],
                                                onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        // Right secondary column: Today's Schedule & Quick Actions
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            children: [
                                              _ScheduleCard(
                                                onViewCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
                                              ),
                                              const SizedBox(height: 20),
                                              _QuickActionsCard(
                                                onOpenCourses: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                                onOpenAttendance: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
                                                onOpenResults: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCardsScreen())),
                                                onOpenFees: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentFeesScreen())),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    // Mobile single column layout
                                    Column(
                                      children: [
                                        _ContinueLearningCard(
                                          courses: coursesAsync.valueOrNull ?? [],
                                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                        ),
                                        const SizedBox(height: 18),
                                        _ScheduleCard(
                                          onViewCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
                                        ),
                                        const SizedBox(height: 18),
                                        _AssignmentsCard(
                                          assignments: assignmentsAsync.valueOrNull ?? [],
                                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                        ),
                                        const SizedBox(height: 18),
                                        _QuickActionsCard(
                                          onOpenCourses: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLmsScreen())),
                                          onOpenAttendance: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
                                          onOpenResults: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCardsScreen())),
                                          onOpenFees: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentFeesScreen())),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                          ),
                          // Floating Bottom Nav shown on Mobile & Tablet
                          if (!isDesktop)
                            _BottomNav(
                              activeIndex: _activeNav,
                              onTap: _onNavTap,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR
// ─────────────────────────────────────────────────────────────────

class _StudentDesktopSidebar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onProfileTap;

  const _StudentDesktopSidebar({
    required this.activeIndex,
    required this.onTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEDEFF5))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: StudentDashboardPage.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'ZivoConnect',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: StudentDashboardPage.text,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDEFF5)),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _SidebarNavButton(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: activeIndex == 0,
                  onTap: () => onTap(0),
                ),
                _SidebarNavButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Courses',
                  active: activeIndex == 1,
                  onTap: () => onTap(1),
                ),
                _SidebarNavButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  active: activeIndex == 2,
                  onTap: () => onTap(2),
                ),
                _SidebarNavButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Tutor',
                  active: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiTutorScreen()),
                  ),
                ),
                _SidebarNavButton(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  active: activeIndex == 3,
                  onTap: onProfileTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarNavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: active,
        selectedTileColor: const Color(0xFFEDEAFF),
        leading: Icon(
          icon,
          color: active ? StudentDashboardPage.primary : const Color(0xFF74809A),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? StudentDashboardPage.primary : StudentDashboardPage.text,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String schoolName;
  final VoidCallback onProfileTap;

  const _TopBar({
    required this.schoolName,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // School pill badge
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEAFF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: StudentDashboardPage.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    schoolName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Notification bell with unread badge
        _NotificationButton(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have 3 new notifications')),
            );
          },
        ),
        const SizedBox(width: 10),
        // Online pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F9F1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 4.5,
                backgroundColor: StudentDashboardPage.green,
              ),
              const SizedBox(width: 7),
              Text(
                'Online',
                style: GoogleFonts.inter(
                  color: const Color(0xFF138A5E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Avatar button
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E2FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: StudentDashboardPage.primaryDark,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: StudentDashboardPage.text,
            ),
          ),
        ),
        Positioned(
          right: -2,
          top: -3,
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D67),
              shape: BoxShape.circle,
            ),
            child: Text(
              '3',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WELCOME HEADER
// ─────────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Stack(
      children: [
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 130,
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEFF),
              borderRadius: BorderRadius.circular(34),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Student Portal 👋',
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.text,
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Learn. Grow. Achieve. Together.',
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 112,
                child: Text(
                  '“A brighter future starts today.”',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.inter(
                    color: StudentDashboardPage.primaryDark,
                    fontSize: 13,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final int coursesCount;
  final int pendingCount;
  final bool isTabletOrDesktop;

  const _StatsGrid({
    required this.coursesCount,
    required this.pendingCount,
    this.isTabletOrDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      const _StatData(
        icon: Icons.star_rounded,
        iconColor: StudentDashboardPage.orange,
        value: '3.8',
        label: 'GPA',
      ),
      const _StatData(
        icon: Icons.groups_2_rounded,
        iconColor: StudentDashboardPage.green,
        value: '96%',
        label: 'Attendance',
      ),
      _StatData(
        icon: Icons.menu_book_rounded,
        iconColor: StudentDashboardPage.primary,
        value: coursesCount > 0 ? '$coursesCount' : '2',
        label: 'Courses',
      ),
      _StatData(
        icon: Icons.assignment_rounded,
        iconColor: StudentDashboardPage.pink,
        value: pendingCount > 0 ? '$pendingCount' : '1',
        label: 'Pending',
      ),
    ];

    return Row(
      children: List.generate(stats.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == stats.length - 1 ? 0 : (isTabletOrDesktop ? 14 : 8)),
            child: _StatCard(
              data: stats[index],
              isTabletOrDesktop: isTabletOrDesktop,
            ),
          ),
        );
      }),
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  final bool isTabletOrDesktop;

  const _StatCard({
    required this.data,
    this.isTabletOrDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isTabletOrDesktop ? 18 : 16,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(data.icon, color: data.iconColor, size: isTabletOrDesktop ? 28 : 25),
          SizedBox(height: isTabletOrDesktop ? 11 : 9),
          Text(
            data.value,
            style: GoogleFonts.inter(
              color: StudentDashboardPage.text,
              fontSize: isTabletOrDesktop ? 22 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: StudentDashboardPage.muted,
              fontSize: isTabletOrDesktop ? 12 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CONTINUE LEARNING CARD
// ─────────────────────────────────────────────────────────────────

class _ContinueLearningCard extends StatelessWidget {
  final List<CourseModel> courses;
  final VoidCallback onViewAll;

  const _ContinueLearningCard({
    required this.courses,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final activeCourseName = courses.isNotEmpty ? courses.first.name : 'Biology';
    final activeUnit = courses.isNotEmpty && courses.first.description != null
        ? courses.first.description!
        : 'Unit 4: Cell Structure and Function';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            StudentDashboardPage.primaryDark,
            Color(0xFF7B5CF5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: StudentDashboardPage.primary.withValues(alpha: .23),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -35,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Continue Learning',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: StudentDashboardPage.primaryDark,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeCourseName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activeUnit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE8E3FF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 11),
                        const _ProgressLine(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onViewAll,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Continue',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: StudentDashboardPage.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: .60,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .20),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF63E0AA),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '60%',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TODAY'S SCHEDULE CARD
// ─────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final VoidCallback onViewCalendar;

  const _ScheduleCard({required this.onViewCalendar});

  @override
  Widget build(BuildContext context) {
    return _WhiteSectionCard(
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.calendar_month_rounded,
            title: "Today's Schedule",
            actionText: 'View Calendar',
            onTap: onViewCalendar,
          ),
          const SizedBox(height: 10),
          _ScheduleRow(
            start: '8:00 AM',
            end: '9:00 AM',
            dotColor: StudentDashboardPage.primary,
            title: 'English Literature',
            subtitle: 'Room 101 • Mr. Carter',
            onTap: onViewCalendar,
          ),
          const Divider(height: 1, color: Color(0xFFEDEFF5)),
          _ScheduleRow(
            start: '10:00 AM',
            end: '11:00 AM',
            dotColor: StudentDashboardPage.green,
            title: 'Mathematics',
            subtitle: 'Room 204 • Ms. Patel',
            onTap: onViewCalendar,
          ),
          const Divider(height: 1, color: Color(0xFFEDEFF5)),
          _ScheduleRow(
            start: '1:00 PM',
            end: '2:00 PM',
            dotColor: StudentDashboardPage.blue,
            title: 'Biology',
            subtitle: 'Room 303 • Dr. Wilson',
            onTap: onViewCalendar,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// UPCOMING ASSIGNMENTS CARD
// ─────────────────────────────────────────────────────────────────

class _AssignmentsCard extends StatelessWidget {
  final List<AssignmentModel> assignments;
  final VoidCallback onViewAll;

  const _AssignmentsCard({
    required this.assignments,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteSectionCard(
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.assignment_rounded,
            title: 'Upcoming Assignments',
            actionText: 'View All',
            onTap: onViewAll,
          ),
          const SizedBox(height: 10),
          _AssignmentRow(
            icon: Icons.description_rounded,
            iconColor: StudentDashboardPage.pink,
            iconBg: const Color(0xFFFFE8EF),
            title: assignments.isNotEmpty ? assignments.first.title : 'Essay: Modern Literature',
            subject: 'English Literature',
            due: 'Due Apr 25',
            status: 'Pending',
            statusBg: const Color(0xFFFFE5EA),
            statusColor: const Color(0xFFE84461),
            onTap: onViewAll,
          ),
          const Divider(height: 1, color: Color(0xFFEDEFF5)),
          _AssignmentRow(
            icon: Icons.science_rounded,
            iconColor: StudentDashboardPage.green,
            iconBg: const Color(0xFFE8F8F0),
            title: assignments.length > 1 ? assignments[1].title : 'Lab Report: Cell Structure',
            subject: 'Biology',
            due: 'Due Apr 27',
            status: 'In Progress',
            statusBg: const Color(0xFFE6F7EF),
            statusColor: const Color(0xFF138A5E),
            onTap: onViewAll,
          ),
          const Divider(height: 1, color: Color(0xFFEDEFF5)),
          _AssignmentRow(
            icon: Icons.calculate_rounded,
            iconColor: StudentDashboardPage.blue,
            iconBg: const Color(0xFFEAF2FF),
            title: assignments.length > 2 ? assignments[2].title : 'Problem Set 6',
            subject: 'Mathematics',
            due: 'Due May 1',
            status: 'Not Started',
            statusBg: const Color(0xFFF0F2F6),
            statusColor: const Color(0xFF637089),
            onTap: onViewAll,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// QUICK ACTIONS CARD
// ─────────────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenResults;
  final VoidCallback onOpenFees;

  const _QuickActionsCard({
    required this.onOpenCourses,
    required this.onOpenAttendance,
    required this.onOpenResults,
    required this.onOpenFees,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        icon: Icons.menu_book_rounded,
        label: 'My Courses',
        color: StudentDashboardPage.primary,
        onTap: onOpenCourses,
      ),
      _QuickActionData(
        icon: Icons.event_available_rounded,
        label: 'Attendance',
        color: StudentDashboardPage.green,
        onTap: onOpenAttendance,
      ),
      _QuickActionData(
        icon: Icons.bar_chart_rounded,
        label: 'Results',
        color: StudentDashboardPage.pink,
        onTap: onOpenResults,
      ),
      _QuickActionData(
        icon: Icons.credit_card_rounded,
        label: 'Fees',
        color: StudentDashboardPage.blue,
        onTap: onOpenFees,
      ),
    ];

    return _WhiteSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: StudentDashboardPage.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  color: StudentDashboardPage.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(actions.length, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == actions.length - 1 ? 0 : 8,
                  ),
                  child: _QuickActionTile(
                    data: actions[index],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7EAF0)),
        ),
        child: Column(
          children: [
            Icon(data.icon, color: data.color, size: 27),
            const SizedBox(height: 7),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: StudentDashboardPage.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// HELPER COMPONENTS
// ─────────────────────────────────────────────────────────────────

class _WhiteSectionCard extends StatelessWidget {
  const _WhiteSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.actionText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: StudentDashboardPage.primary,
          size: 23,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: StudentDashboardPage.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: StudentDashboardPage.primary,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.start,
    required this.end,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String start;
  final String end;
  final Color dotColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    start,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    end,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: const Color(0xFFE7EAF0),
            ),
            const SizedBox(width: 14),
            CircleAvatar(radius: 5, backgroundColor: dotColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF62708A),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subject,
    required this.due,
    required this.status,
    required this.statusBg,
    required this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subject;
  final String due;
  final String status;
  final Color statusBg;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subject,
                    style: GoogleFonts.inter(
                      color: StudentDashboardPage.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  due,
                  style: GoogleFonts.inter(
                    color: StudentDashboardPage.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// FLOATING BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: activeIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.menu_book_rounded,
              label: 'Courses',
              active: activeIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.calendar_month_rounded,
              label: 'Calendar',
              active: activeIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              active: activeIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? StudentDashboardPage.primary
        : const Color(0xFF66758F);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 28 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: active ? StudentDashboardPage.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

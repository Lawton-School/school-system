import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../router/router.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';
import '../operations/sync_diagnostics_screen.dart';

// ─────────────────────────────────────────────────────────────────
// SCHOOL ADMIN SHELL (Navigation)
// ─────────────────────────────────────────────────────────────────

class SchoolAdminShell extends ConsumerWidget {
  final Widget child;
  const SchoolAdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go(AppRoutes.schoolAdminDashboard);
            case 1: context.go(AppRoutes.schoolAdminUsers);
            case 2: context.go(AppRoutes.schoolAdminStructure);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree_rounded), label: 'Structure'),
        ],
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.schoolAdminUsers) ||
        location.startsWith(AppRoutes.schoolAdminCreateUser)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.schoolAdminStructure) ||
        location.startsWith(AppRoutes.academicYears) ||
        location.startsWith(AppRoutes.classesSections) ||
        location.startsWith(AppRoutes.subjects) ||
        location.startsWith(AppRoutes.teacherAssignments) ||
        location.startsWith(AppRoutes.studentEnrollments) ||
        location.startsWith(AppRoutes.parentStudentMapping)) {
      return 2;
    }
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────
// SCHOOL ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────

final schoolAdminMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final rpc = ref.watch(rpcClientProvider);
  try {
    final metrics = await rpc.getSchoolAdminDashboardMetrics();
    if (metrics.isNotEmpty) return metrics;
  } catch (e) {
    debugPrint('[SchoolAdmin] RPC metrics error: $e');
  }
  return const <String, dynamic>{};
});

class SchoolAdminDashboardPage extends ConsumerWidget {
  const SchoolAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final metricsAsync = ref.watch(schoolAdminMetricsProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: _schoolAdminAppBar(context, ref, session?.schoolName ?? 'School Admin'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WelcomeSection(session: session),
            const SizedBox(height: 16),
            const StitchSyncBanner(),
            const SizedBox(height: 20),
            metricsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
              data: (m) => LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 960;
                  final studentsCount = m['total_students'] ?? m['students_count'] ?? 0;
                  final staffCount = m['total_staff'] ?? m['staff_count'] ?? 0;
                  final attendanceRate = m['attendance_rate']?.toString() ?? '—';
                  final feeRecovery = m['fee_recovery_rate']?.toString() ?? '—';

                  return GridView.count(
                    crossAxisCount: isDesktop ? 4 : 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isDesktop ? 1.6 : 1.4,
                    children: [
                      StitchKpiCard(
                        label: 'Active Enrollment',
                        value: '$studentsCount',
                        hint: studentsCount > 0 ? 'Enrolled students' : 'No students enrolled',
                        icon: Icons.school_rounded,
                      ),
                      StitchKpiCard(
                        label: 'Teaching & Staff',
                        value: '$staffCount',
                        hint: staffCount > 0 ? 'Active staff roster' : 'No staff profiles',
                        statusColor: staffCount > 0 ? StitchChipVariant.success : StitchChipVariant.neutral,
                        icon: Icons.badge_rounded,
                      ),
                      StitchKpiCard(
                        label: 'Attendance Rate',
                        value: attendanceRate != '—' ? '$attendanceRate%' : '—',
                        hint: 'Present across all classes',
                        statusColor: attendanceRate != '—' ? StitchChipVariant.success : StitchChipVariant.neutral,
                        icon: Icons.fact_check_rounded,
                      ),
                      StitchKpiCard(
                        label: 'Fee Recovery',
                        value: feeRecovery != '—' ? '$feeRecovery%' : '—',
                        hint: 'Term fee collections',
                        statusColor: StitchChipVariant.warn,
                        icon: Icons.payments_rounded,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _QuickActionsGrid(session: session),
            const SizedBox(height: 28),
            _RecentActivitySection(schoolId: session?.schoolId),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSection extends ConsumerWidget {
  final ActiveSession? session;
  const _WelcomeSection({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting 👋', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            session?.schoolName ?? 'Your School',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'School Administration Portal',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  final ActiveSession? session;
  const _QuickActionsGrid({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _GridAction(icon: Icons.person_add_rounded, label: 'Add Teacher', color: const Color(0xFF10B981), route: AppRoutes.schoolAdminCreateUser),
      _GridAction(icon: Icons.school_rounded, label: 'Add Student', color: const Color(0xFF6366F1), route: AppRoutes.schoolAdminCreateUser),
      _GridAction(icon: Icons.family_restroom_rounded, label: 'Add Parent', color: const Color(0xFF3B82F6), route: AppRoutes.schoolAdminCreateUser),
      _GridAction(icon: Icons.account_tree_rounded, label: 'Setup Classes', color: const Color(0xFFF59E0B), route: AppRoutes.schoolAdminStructure),
      _GridAction(icon: Icons.work_history_rounded, label: 'Operations', color: const Color(0xFF8B5CF6), route: AppRoutes.schoolAdminOperations),
      _GridAction(icon: Icons.grading_rounded, label: 'Gradebook & Exams', color: const Color(0xFFEC4899), route: AppRoutes.schoolAdminGradebook),
      _GridAction(icon: Icons.directions_bus_rounded, label: 'Bus Tracking & Fleet', color: const Color(0xFF38BDF8), route: AppRoutes.schoolAdminBus),
      _GridAction(icon: Icons.storefront_rounded, label: 'School Marketplace', color: const Color(0xFF14B8A6), route: AppRoutes.schoolAdminMarketplace),
      _GridAction(icon: Icons.account_balance_wallet_rounded, label: 'Finance Hub', color: const Color(0xFF10B981), route: AppRoutes.schoolAdminFinance),
      _GridAction(icon: Icons.insights_rounded, label: 'Reports & Analytics', color: const Color(0xFF6366F1), route: AppRoutes.schoolAdminReports),
      _GridAction(icon: Icons.assignment_turned_in_rounded, label: 'Report Cards Review', color: const Color(0xFFF59E0B), route: AppRoutes.schoolAdminReportCards),
      _GridAction(icon: Icons.notifications_active_rounded, label: 'Notification Centre', color: const Color(0xFFEC4899), route: AppRoutes.schoolAdminNotifications),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: actions.map((a) => _QuickActionCard(action: a)).toList(),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _GridAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(action.route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: action.color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: action.color.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: action.color, size: 18),
            ),
            Text(action.label, style: TextStyle(color: action.color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  final String? schoolId;
  const _RecentActivitySection({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (schoolId == null) return const SizedBox.shrink();
    final profilesAsync = ref.watch(_recentProfilesProvider(schoolId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Users', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go(AppRoutes.schoolAdminUsers),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        profilesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading users', style: const TextStyle(color: AppTheme.danger)),
          data: (profiles) {
            if (profiles.isEmpty) return const Text('No users yet.', style: TextStyle(color: AppTheme.textMuted));
            return Column(
              children: profiles.take(5).map((p) => _UserListTile(profile: p)).toList(),
            );
          },
        ),
      ],
    );
  }
}

final _recentProfilesProvider = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getSchoolProfiles(schoolId);
});

// ─────────────────────────────────────────────────────────────────
// USERS PAGE
// ─────────────────────────────────────────────────────────────────

class SchoolAdminUsersPage extends ConsumerStatefulWidget {
  const SchoolAdminUsersPage({super.key});

  @override
  ConsumerState<SchoolAdminUsersPage> createState() => _SchoolAdminUsersPageState();
}

class _SchoolAdminUsersPageState extends ConsumerState<SchoolAdminUsersPage> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    final profilesAsync = ref.watch(_recentProfilesProvider(session.schoolId));

    return Scaffold(
      appBar: _schoolAdminAppBar(context, ref, 'Users'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.schoolAdminCreateUser),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [null, ...AppRoles.all].map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(role == null ? 'All' : AppRoles.displayName(role)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedRole = role),
                    selectedColor: AppTheme.primary.withAlpha(40),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    backgroundColor: AppTheme.cardDark,
                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.borderDark),
                  ),
                );
              }).toList(),
            ),
          ),

          // User list
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
              data: (profiles) {
                final filtered = _selectedRole == null
                    ? profiles
                    : profiles.where((p) => p.role == _selectedRole).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text('No users found', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _UserListTile(profile: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CREATE USER PAGE
// ─────────────────────────────────────────────────────────────────

class CreateUserPage extends ConsumerStatefulWidget {
  const CreateUserPage({super.key});

  @override
  ConsumerState<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends ConsumerState<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = AppRoles.student;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      await ProfileService(client).createProfile(
        schoolId: session.schoolId,
        role: _selectedRole,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      );
      ref.invalidate(_recentProfilesProvider(session.schoolId));
      if (mounted) {
        context.go(AppRoutes.schoolAdminUsers);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New User'), leading: BackButton(onPressed: () => context.pop())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Role selector
              Text('Role', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [AppRoles.teacher, AppRoles.student, AppRoles.parent, AppRoles.financeManager, AppRoles.registrar, AppRoles.reception].map((role) {
                  final isSelected = _selectedRole == role;
                  return ChoiceChip(
                    label: Text(AppRoles.displayName(role)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedRole = role),
                    selectedColor: AppTheme.primary.withAlpha(40),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                    backgroundColor: AppTheme.cardDark,
                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.borderDark),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
              ),

              const SizedBox(height: 32),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _submit, child: const Text('Create User')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ACADEMIC STRUCTURE PAGE
// ─────────────────────────────────────────────────────────────────

class AcademicStructurePage extends ConsumerWidget {
  const AcademicStructurePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _schoolAdminAppBar(context, ref, 'Academic Structure'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StructureCategory(
            title: 'Academic Years',
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF6366F1),
            description: 'Define school years (e.g. 2026–2027) and set current year',
            onTap: () => context.go(AppRoutes.academicYears),
          ),
          _StructureCategory(
            title: 'Classes & Grades',
            icon: Icons.class_rounded,
            color: const Color(0xFF10B981),
            description: 'Set up grade levels and sections per class',
            onTap: () => context.go(AppRoutes.classesSections),
          ),
          _StructureCategory(
            title: 'Subjects',
            icon: Icons.book_rounded,
            color: const Color(0xFFF59E0B),
            description: 'Create subjects and assign codes (e.g. MATH101)',
            onTap: () => context.go(AppRoutes.subjects),
          ),
          _StructureCategory(
            title: 'Teacher Assignments',
            icon: Icons.assignment_ind_rounded,
            color: const Color(0xFF3B82F6),
            description: 'Link teachers to sections and subjects',
            onTap: () => context.go(AppRoutes.teacherAssignments),
          ),
          _StructureCategory(
            title: 'Student Enrollments',
            icon: Icons.how_to_reg_rounded,
            color: const Color(0xFFEC4899),
            description: 'Enroll students into class sections with roll numbers',
            onTap: () => context.go(AppRoutes.studentEnrollments),
          ),
          _StructureCategory(
            title: 'Parent–Student Links',
            icon: Icons.family_restroom_rounded,
            color: const Color(0xFF8B5CF6),
            description: 'Link parents to their children for cross-school visibility',
            onTap: () => context.go(AppRoutes.parentStudentMapping),
          ),
        ],
      ),
    );
  }
}

class _StructureCategory extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StructureCategory({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED: USER LIST TILE & APP BAR
// ─────────────────────────────────────────────────────────────────

class _UserListTile extends StatelessWidget {
  final ProfileModel profile;
  const _UserListTile({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _roleColor(profile.role).withAlpha(40),
          child: Text(
            profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: _roleColor(profile.role), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(profile.fullName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: Text(profile.email ?? profile.phone ?? 'No contact info', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor(profile.role).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            AppRoles.displayName(profile.role),
            style: TextStyle(color: _roleColor(profile.role), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppRoles.teacher: return const Color(0xFF10B981);
      case AppRoles.student: return const Color(0xFF6366F1);
      case AppRoles.parent: return const Color(0xFF3B82F6);
      case AppRoles.financeManager: return const Color(0xFF0F766E);
      case AppRoles.registrar: return const Color(0xFF7C3AED);
      case AppRoles.reception: return const Color(0xFF0891B2);
      default: return AppTheme.textMuted;
    }
  }
}

AppBar _schoolAdminAppBar(BuildContext context, WidgetRef ref, String title) {
  return AppBar(
    title: Text(title),
    actions: [
      const Center(
        child: Padding(
          padding: EdgeInsets.only(right: 8),
          child: SyncStatusBadge(),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.logout_rounded),
        tooltip: 'Sign Out',
        onPressed: () async {
          await ref.read(activeSessionProvider.notifier).clearSession();
          await AuthService(ref.read(supabaseClientProvider)).signOut();
        },
      ),
    ],
  );
}

class _GridAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _GridAction({required this.icon, required this.label, required this.color, required this.route});
}


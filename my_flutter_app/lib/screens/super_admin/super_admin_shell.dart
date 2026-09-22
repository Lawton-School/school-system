import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../router/router.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/stitch_widgets.dart';

// ─────────────────────────────────────────────────────────────────
// SUPER ADMIN SHELL (Navigation)
// ─────────────────────────────────────────────────────────────────

class SuperAdminShell extends ConsumerWidget {
  final Widget child;
  const SuperAdminShell({super.key, required this.child});

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
            case 0:
              context.go(AppRoutes.superAdminDashboard);
            case 1:
              context.go(AppRoutes.superAdminSchools);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business_rounded), label: 'Schools'),
        ],
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.superAdminSchools)) return 1;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────
// PLATFORM METRICS PROVIDER (Screen 10)
// ─────────────────────────────────────────────────────────────────

final superAdminPlatformMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final rpc = ref.watch(rpcClientProvider);
  try {
    return await rpc.getSuperAdminPlatformMetrics();
  } catch (e) {
    debugPrint('[SuperAdmin] Platform metrics error: $e');
    return const <String, dynamic>{};
  }
});

// ─────────────────────────────────────────────────────────────────
// SUPER ADMIN DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────

class SuperAdminDashboardPage extends ConsumerWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(allSchoolsProvider);
    final metricsAsync = ref.watch(superAdminPlatformMetricsProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: _superAdminAppBar(context, ref, 'Platform Overview'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allSchoolsProvider);
          ref.invalidate(superAdminPlatformMetricsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Platform Overview',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.stitchHeading,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cross-tenant operational health and SaaS management.',
                        style: TextStyle(fontSize: 13, color: AppTheme.stitchMuted),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.superAdminCreateSchool),
                    icon: const Icon(Icons.add_business_rounded, size: 16, color: Colors.white),
                    label: const Text('Create School', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4 KPI Cards from RPC
              metricsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
                data: (m) => LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 960;
                    final schoolCount = m['total_schools'] ?? m['schools_count'] ?? 0;
                    final activeSchools = m['active_schools'] ?? m['active_count'] ?? 0;
                    final trialSchools = m['trial_schools'] ?? m['trial_count'] ?? (schoolCount - activeSchools);
                    final platformUsers = m['platform_users'] ?? m['total_users'] ?? 0;
                    final mau = m['monthly_active_users'] ?? m['mau'] ?? 0;
                    final attentionCount = m['needs_attention'] ?? m['attention_count'] ?? 0;

                    return GridView.count(
                      crossAxisCount: isDesktop ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isDesktop ? 1.6 : 1.4,
                      children: [
                        StitchKpiCard(
                          label: 'Schools',
                          value: '$schoolCount',
                          hint: '$activeSchools active · $trialSchools trial',
                          icon: Icons.business_rounded,
                        ),
                        StitchKpiCard(
                          label: 'Platform Users',
                          value: platformUsers > 1000 ? '${(platformUsers / 1000).toStringAsFixed(1)}K' : '$platformUsers',
                          hint: 'Students, staff and guardians',
                          statusColor: StitchChipVariant.neutral,
                          icon: Icons.people_rounded,
                        ),
                        StitchKpiCard(
                          label: 'Monthly Active',
                          value: mau > 1000 ? '${(mau / 1000).toStringAsFixed(1)}K' : '$mau',
                          hint: platformUsers > 0 ? '${(mau / platformUsers * 100).toStringAsFixed(1)}% activity rate' : '—',
                          statusColor: StitchChipVariant.success,
                          icon: Icons.trending_up_rounded,
                        ),
                        StitchKpiCard(
                          label: 'Attention',
                          value: '$attentionCount',
                          hint: attentionCount > 0 ? 'Issues requiring review' : 'All systems healthy',
                          statusColor: attentionCount > 0 ? StitchChipVariant.warn : StitchChipVariant.success,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Schools Requiring Attention table
              StitchCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StitchSectionHeader(
                        title: 'All Schools',
                        trailing: GestureDetector(
                          onTap: () => context.go(AppRoutes.superAdminSchools),
                          child: const Text('Manage →', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      schoolsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppTheme.danger)),
                        data: (schools) {
                          if (schools.isEmpty) {
                            return _EmptyCard(
                              message: 'No schools yet. Create the first tenant.',
                              icon: Icons.business_outlined,
                            );
                          }
                          return Column(
                            children: schools.take(6).map((s) => _SchoolListTile(school: s, ref: ref)).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.add_business_rounded,
                      label: 'Add School',
                      color: AppTheme.primary,
                      onTap: () => context.go(AppRoutes.superAdminCreateSchool),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.group_add_rounded,
                      label: 'Invite Admin',
                      color: AppTheme.secondary,
                      onTap: () => _showInviteAdminSheet(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteAdminSheet(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final client = ref.read(supabaseClientProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.stitchSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Invite School Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
            const SizedBox(height: 8),
            const Text('They will receive an email to set up their account.', style: TextStyle(fontSize: 13, color: AppTheme.stitchMuted)),
            const SizedBox(height: 20),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Admin Email Address', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AuthService(client).inviteUserByEmail(emailCtrl.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation sent successfully!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SUPER ADMIN SCHOOLS PAGE
// ─────────────────────────────────────────────────────────────────

class SuperAdminSchoolsPage extends ConsumerWidget {
  const SuperAdminSchoolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(allSchoolsProvider);
    return Scaffold(
      appBar: _superAdminAppBar(context, ref, 'Schools'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.superAdminCreateSchool),
        icon: const Icon(Icons.add),
        label: const Text('New School'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: schoolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (schools) {
          if (schools.isEmpty) {
            return Center(child: _EmptyCard(message: 'No schools yet.', icon: Icons.business_outlined));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: schools.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _SchoolListTile(school: schools[index], ref: ref),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CREATE SCHOOL PAGE
// ─────────────────────────────────────────────────────────────────

class CreateSchoolPage extends ConsumerStatefulWidget {
  const CreateSchoolPage({super.key});

  @override
  ConsumerState<CreateSchoolPage> createState() => _CreateSchoolPageState();
}

class _CreateSchoolPageState extends ConsumerState<CreateSchoolPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _subdomainCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subdomainCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await SchoolService(client).createSchool(
        name: _nameCtrl.text.trim(),
        subdomain: _subdomainCtrl.text.trim().toLowerCase(),
      );
      ref.invalidate(allSchoolsProvider);
      if (mounted) {
        context.go(AppRoutes.superAdminSchools);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School created successfully!')),
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
      appBar: AppBar(title: const Text('Create New School'), leading: BackButton(onPressed: () => context.pop())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  hintText: 'e.g. Greenwood High School',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subdomainCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Subdomain / Identifier',
                  hintText: 'e.g. greenwood-high',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Subdomain is required';
                  if (v.contains(' ')) return 'No spaces allowed';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _submit, child: const Text('Create School')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED WIDGETS & HELPERS
// ─────────────────────────────────────────────────────────────────

AppBar _superAdminAppBar(BuildContext context, WidgetRef ref, String title) {
  return AppBar(
    title: Text(title),
    actions: [
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

class _SchoolListTile extends StatelessWidget {
  final SchoolModel school;
  final WidgetRef ref;
  const _SchoolListTile({required this.school, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: school.isActive ? AppTheme.primary.withAlpha(30) : AppTheme.danger.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.business_rounded,
            color: school.isActive ? AppTheme.primary : AppTheme.danger,
            size: 22,
          ),
        ),
        title: Text(school.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(school.subdomain, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: _StatusBadge(isActive: school.isActive),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.secondary : AppTheme.danger).withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isActive ? AppTheme.secondary : AppTheme.danger).withAlpha(80)),
      ),
      child: Text(
        isActive ? 'Active' : 'Suspended',
        style: TextStyle(
          color: isActive ? AppTheme.secondary : AppTheme.danger,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}


class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.danger.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

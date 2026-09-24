import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/admissions_controllers.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../router/router.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';

class ReceptionDashboardScreen extends ConsumerWidget {
  const ReceptionDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final pipeline = ref.watch(admissionsPipelineProvider);
    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(title: const Text('Reception'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(admissionsPipelineProvider), icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Sign Out', onPressed: () async {
          await ref.read(activeSessionProvider.notifier).clearSession();
          await AuthService(ref.read(supabaseClientProvider)).signOut();
        }, icon: const Icon(Icons.logout_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(admissionsPipelineProvider); await ref.read(admissionsPipelineProvider.future); },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
          Text(session?.schoolName ?? 'School Reception', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
          const SizedBox(height: 4),
          const Text('Front Desk Workspace', style: TextStyle(color: AppTheme.stitchMuted)),
          const SizedBox(height: 20),
          pipeline.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => StitchCard(child: Text('Unable to load front desk summary: $e')),
            data: (data) {
              final apps = _mapList(data['applications']);
              final applied = _count(apps, {'applied'});
              final attention = _count(apps, {'review', 'info_requested', 'waitlisted'});
              final accepted = _count(apps, {'accepted'});
              return LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth >= 900 ? 4 : 2;
                return GridView.count(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: constraints.maxWidth >= 900 ? 1.7 : 1.25, children: [
                  StitchKpiCard(label: 'New Applications', value: '$applied', hint: 'Awaiting first review', icon: Icons.person_add_alt_1_rounded),
                  StitchKpiCard(label: 'Needs Attention', value: '$attention', hint: 'Review or information follow-up', icon: Icons.pending_actions_rounded),
                  StitchKpiCard(label: 'Accepted', value: '$accepted', hint: 'Registrar/Admin completes enrollment', icon: Icons.verified_rounded),
                  StitchKpiCard(label: 'Applications', value: '${apps.length}', hint: 'Current admissions pipeline', icon: Icons.folder_shared_rounded),
                ]);
              });
            },
          ),
          const SizedBox(height: 24),
          Text('Front Desk Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ActionCard(icon: Icons.how_to_reg_rounded, title: 'Admissions Desk', subtitle: 'Capture new applications, review details and request missing information.', onTap: () => context.go(AppRoutes.schoolAdminAdmissions)),
          const SizedBox(height: 10),
          const StitchCard(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(children: [
            Icon(Icons.admin_panel_settings_outlined, color: AppTheme.stitchMuted), SizedBox(width: 12),
            Expanded(child: Text('Admission decisions and student enrollment are reserved for Registrar or School Admin.', style: TextStyle(color: AppTheme.stitchMuted))),
          ]))),
        ]),
      ),
    );
  }
  static List<Map<String, dynamic>> _mapList(dynamic value) => value is! List ? const [] : value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  static int _count(List<Map<String, dynamic>> apps, Set<String> statuses) => apps.where((a) => statuses.contains(a['status']?.toString())).length;
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => StitchCard(onTap: onTap, child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.primaryDark)),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
      const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppTheme.stitchMuted)),
    ])),
    const Icon(Icons.chevron_right_rounded, color: AppTheme.stitchMuted),
  ]));
}

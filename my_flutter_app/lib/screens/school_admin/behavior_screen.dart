import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/behavior_controllers.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 21 — Behaviour / Pastoral Support.
class BehaviorScreen extends ConsumerWidget {
  const BehaviorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final dashboardAsync = ref.watch(behaviorDashboardProvider);
    final canManage = session.role == AppRoles.schoolAdmin ||
        session.role == AppRoles.teacher ||
        session.role == AppRoles.superAdmin;

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
              'PASTORAL SUPPORT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Behaviour & Discipline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(behaviorDashboardProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _createCase(context, ref, session),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Case'),
            )
          : null,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load behaviour records: $error',
          onRetry: () => ref.invalidate(behaviorDashboardProvider),
        ),
        data: (dashboard) {
          final incidents = _mapList(dashboard['incidents']);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(behaviorDashboardProvider);
              await ref.read(behaviorDashboardProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _BehaviorSummary(dashboard: dashboard),
                const SizedBox(height: 18),
                StitchSectionHeader(
                  title: 'Cases & Notes',
                  subtitle: '${incidents.length} recent records',
                ),
                const SizedBox(height: 10),
                if (incidents.isEmpty)
                  const _EmptyState()
                else
                  ...incidents.map(
                    (incident) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BehaviorCard(
                        incident: incident,
                        canManage: canManage,
                        onUpdate: () => _updateCase(context, ref, incident),
                        onNotifyGuardian: () =>
                            _markGuardianNotified(context, ref, incident),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createCase(
    BuildContext context,
    WidgetRef ref,
    dynamic session,
  ) async {
    final students =
        await ref.read(behaviorStudentsProvider(session.schoolId).future);
    if (!context.mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active student profiles found.')),
      );
      return;
    }

    String? studentId;
    String type = 'incident';
    String severity = 'low';
    final pointsController = TextEditingController(text: '0');
    final descriptionController = TextEditingController();
    DateTime incidentDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Behaviour Record'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: studentId,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: students.map((student) {
                      final id = student['id']?.toString() ?? '';
                      final name =
                          '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                              .trim();
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).where((item) => item.value?.isNotEmpty == true).toList(),
                    onChanged: (value) => setDialogState(() => studentId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'merit', child: Text('Merit')),
                      DropdownMenuItem(value: 'demerit', child: Text('Demerit')),
                      DropdownMenuItem(value: 'incident', child: Text('Incident')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => severity = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Points'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incident date'),
                    subtitle: Text(
                      '${incidentDate.day}/${incidentDate.month}/${incidentDate.year}',
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: incidentDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null) {
                          setDialogState(() => incidentDate = selected);
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: studentId == null ||
                      descriptionController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final points = int.tryParse(pointsController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();
    pointsController.dispose();
    descriptionController.dispose();
    if (confirmed != true || studentId == null || description.isEmpty) return;

    try {
      await ref.read(behaviorRepositoryProvider).createCase(
            schoolId: session.schoolId,
            loggedByProfileId: session.profileId,
            studentProfileId: studentId!,
            type: type,
            severity: severity,
            points: points,
            description: description,
            incidentDate: incidentDate,
          );
      ref.invalidate(behaviorDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Behaviour record created.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create record: $error')),
        );
      }
    }
  }

  Future<void> _updateCase(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> incident,
  ) async {
    String status = incident['status']?.toString() ?? 'open';
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Behaviour Case'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'follow_up',
                      child: Text('Follow Up'),
                    ),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final notes = notesController.text;
    notesController.dispose();
    if (confirmed != true) return;

    final id = incident['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await ref.read(behaviorRepositoryProvider).updateCase(
            behaviorId: id,
            status: status,
            followUpNotes: notes,
          );
      ref.invalidate(behaviorDashboardProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update case: $error')),
        );
      }
    }
  }

  Future<void> _markGuardianNotified(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> incident,
  ) async {
    final id = incident['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await ref
          .read(behaviorRepositoryProvider)
          .markGuardianNotified(id);
      ref.invalidate(behaviorDashboardProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update guardian status: $error')),
        );
      }
    }
  }
}

class _BehaviorSummary extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _BehaviorSummary({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth >= 900 ? 1.8 : 1.45,
          children: [
            StitchKpiCard(
              label: 'Open Follow-ups',
              value: '${dashboard['open_followups'] ?? 0}',
              hint: 'Cases needing action',
              icon: Icons.pending_actions_rounded,
              statusColor: StitchChipVariant.warn,
            ),
            StitchKpiCard(
              label: 'Resolved',
              value: '${dashboard['resolved'] ?? 0}',
              hint: 'Resolved in current period',
              icon: Icons.task_alt_rounded,
              statusColor: StitchChipVariant.success,
            ),
            StitchKpiCard(
              label: 'Merit Notes',
              value: '${dashboard['merit_notes'] ?? 0}',
              hint: 'Positive behaviour records',
              icon: Icons.star_rounded,
            ),
            StitchKpiCard(
              label: 'Guardian Follow-up',
              value: '${dashboard['guardian_followup'] ?? 0}',
              hint: 'Not yet notified',
              icon: Icons.family_restroom_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _BehaviorCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final bool canManage;
  final VoidCallback onUpdate;
  final VoidCallback onNotifyGuardian;

  const _BehaviorCard({
    required this.incident,
    required this.canManage,
    required this.onUpdate,
    required this.onNotifyGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final type = incident['type']?.toString() ?? 'incident';
    final status = incident['status']?.toString() ?? 'open';
    final guardianNotified = incident['guardian_notified_at'] != null;

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: type == 'merit'
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF7ED),
                child: Icon(
                  type == 'merit' ? Icons.star_rounded : Icons.report_outlined,
                  color: type == 'merit' ? AppTheme.success : AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident['student_name']?.toString() ?? 'Student',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                    Text(
                      '${type.toUpperCase()} • ${incident['severity'] ?? 'low'} • ${incident['incident_date'] ?? ''}',
                      style: const TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              StitchChip(
                label: status.replaceAll('_', ' '),
                variant: status == 'resolved'
                    ? StitchChipVariant.success
                    : status == 'follow_up'
                        ? StitchChipVariant.warn
                        : StitchChipVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            incident['description']?.toString() ?? '',
            style: const TextStyle(color: AppTheme.stitchHeading),
          ),
          const SizedBox(height: 10),
          Text(
            'Reported by ${incident['reported_by'] ?? 'School staff'} • Points: ${incident['points'] ?? 0}',
            style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 11),
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update Case'),
                ),
                if (!guardianNotified && status != 'resolved')
                  FilledButton.tonalIcon(
                    onPressed: onNotifyGuardian,
                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                    label: const Text('Mark Guardian Notified'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const StitchCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'No behaviour records are available for the current period.',
            style: TextStyle(color: AppTheme.stitchMuted),
          ),
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

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

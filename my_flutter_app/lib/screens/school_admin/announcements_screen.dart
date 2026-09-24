import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/announcements_controllers.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 28 — Announcements.
///
/// Draft/edit/status transitions are server-authoritative. Realtime refresh is
/// scoped to the active school. Attachment upload is intentionally omitted
/// until an announcements storage bucket/provider exists.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String _filter = 'all';
  String? _subscribedSchoolId;

  @override
  void dispose() {
    ref.read(announcementsRepositoryProvider).disposeRealtime();
    super.dispose();
  }

  void _syncRealtime(String schoolId) {
    if (_subscribedSchoolId == schoolId) return;
    _subscribedSchoolId = schoolId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(announcementsRepositoryProvider).subscribe(
            schoolId: schoolId,
            onChanged: () =>
                ref.invalidate(announcementsManagementProvider(schoolId)),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    _syncRealtime(session.schoolId);
    final announcementsAsync =
        ref.watch(announcementsManagementProvider(session.schoolId));
    final canCreate = session.role == AppRoles.schoolAdmin ||
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
              'COMMUNICATIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Announcements',
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
            onPressed: () => ref.invalidate(
              announcementsManagementProvider(session.schoolId),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canCreate)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: () => _editAnnouncement(context, ref, session, null),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('New'),
              ),
            ),
        ],
      ),
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load announcements: $error',
          onRetry: () => ref.invalidate(
            announcementsManagementProvider(session.schoolId),
          ),
        ),
        data: (items) {
          final visible = _filterItems(items);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'draft', label: Text('Drafts')),
                        ButtonSegment(
                          value: 'scheduled',
                          label: Text('Scheduled'),
                        ),
                        ButtonSegment(
                          value: 'published',
                          label: Text('Published'),
                        ),
                        ButtonSegment(
                          value: 'archived',
                          label: Text('Archived'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (values) {
                        setState(() => _filter = values.first);
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                            announcementsManagementProvider(session.schoolId),
                          );
                          await ref.read(
                            announcementsManagementProvider(session.schoolId)
                                .future,
                          );
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final announcement = visible[index];
                            final ownAnnouncement =
                                announcement['author_profile_id']?.toString() ==
                                    session.profileId;
                            final canManage = session.role == AppRoles.schoolAdmin ||
                                session.role == AppRoles.superAdmin ||
                                (session.role == AppRoles.teacher &&
                                    ownAnnouncement);
                            return _AnnouncementCard(
                              announcement: announcement,
                              canManage: canManage,
                              onEdit: () => _editAnnouncement(
                                context,
                                ref,
                                session,
                                announcement,
                              ),
                              onStatus: (status) => _changeStatus(
                                context,
                                ref,
                                schoolId: session.schoolId,
                                announcement: announcement,
                                status: status,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterItems(
    List<Map<String, dynamic>> items,
  ) {
    if (_filter == 'all') return items;
    return items
        .where((item) => item['status']?.toString() == _filter)
        .toList(growable: false);
  }

  Future<void> _editAnnouncement(
    BuildContext context,
    WidgetRef ref,
    dynamic session,
    Map<String, dynamic>? existing,
  ) async {
    final sections =
        await ref.read(classSectionsProvider(session.schoolId).future);
    if (!context.mounted) return;

    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final contentController =
        TextEditingController(text: existing?['content']?.toString() ?? '');
    String audience = existing?['target_role']?.toString() ?? 'all';
    String priority = existing?['priority']?.toString() ?? 'normal';
    String? sectionId = existing?['target_class_section_id']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Announcement' : 'Edit Announcement'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Everyone')),
                      DropdownMenuItem(
                        value: 'teachers',
                        child: Text('Teachers'),
                      ),
                      DropdownMenuItem(
                        value: 'parents',
                        child: Text('Parents'),
                      ),
                      DropdownMenuItem(
                        value: 'students',
                        child: Text('Students'),
                      ),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(
                        value: 'school_admins',
                        child: Text('School Admins'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => audience = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => priority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: sectionId,
                    decoration: const InputDecoration(
                      labelText: 'Target Class / Section (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All eligible classes'),
                      ),
                      ...sections.map(
                        (section) => DropdownMenuItem(
                          value: section.id,
                          child: Text(section.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => sectionId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Attachments are not enabled until a dedicated announcement storage provider is configured.',
                      style: TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 11,
                      ),
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
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(existing == null ? 'Save Draft' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );

    final title = titleController.text;
    final content = contentController.text;
    titleController.dispose();
    contentController.dispose();
    if (confirmed != true) return;

    try {
      await ref.read(announcementsRepositoryProvider).saveDraft(
            announcementId: existing?['id']?.toString(),
            title: title,
            content: content,
            targetRole: audience,
            priority: priority,
            targetClassSectionId: sectionId,
          );
      ref.invalidate(announcementsManagementProvider(session.schoolId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Draft saved.' : 'Announcement updated.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save announcement: $error')),
        );
      }
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref, {
    required String schoolId,
    required Map<String, dynamic> announcement,
    required String status,
  }) async {
    final id = announcement['id']?.toString() ?? '';
    if (id.isEmpty) return;

    DateTime? scheduledAt;
    if (status == 'scheduled') {
      scheduledAt = await _pickSchedule(context);
      if (scheduledAt == null) return;
    }

    try {
      await ref.read(announcementsRepositoryProvider).setStatus(
            announcementId: id,
            status: status,
            scheduledAt: scheduledAt,
          );
      ref.invalidate(announcementsManagementProvider(schoolId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change status: $error')),
        );
      }
    }
  }

  Future<DateTime?> _pickSchedule(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be in the future.')),
        );
      }
      return null;
    }
    return scheduled;
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final bool canManage;
  final VoidCallback onEdit;
  final void Function(String status) onStatus;

  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.onEdit,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = announcement['status']?.toString() ?? 'draft';
    final priority = announcement['priority']?.toString() ?? 'normal';
    final author = _asMap(announcement['author']);
    final classSection = _asMap(announcement['class_section']);
    final classData = _asMap(classSection['classes']);
    final authorName = '${author['first_name'] ?? ''} ${author['last_name'] ?? ''}'
        .trim();
    final classLabel = [classData['name'], classSection['name']]
        .where((value) => value != null && value.toString().isNotEmpty)
        .join(' · ');

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: priority == 'urgent'
                    ? const Color(0xFFFEE2E2)
                    : AppTheme.primarySoft,
                child: Icon(
                  priority == 'urgent'
                      ? Icons.priority_high_rounded
                      : Icons.campaign_rounded,
                  color: priority == 'urgent'
                      ? AppTheme.danger
                      : AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement['title']?.toString() ?? 'Announcement',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchHeading,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      announcement['content']?.toString() ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StitchChip(
                label: status,
                variant: _statusVariant(status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Audience: ${_audienceLabel(announcement['target_role']?.toString())}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                'Priority: $priority',
                style: const TextStyle(fontSize: 11),
              ),
              if (authorName.isNotEmpty)
                Text('Author: $authorName', style: const TextStyle(fontSize: 11)),
              if (classLabel.isNotEmpty)
                Text('Class: $classLabel', style: const TextStyle(fontSize: 11)),
              if (status == 'scheduled' && announcement['scheduled_at'] != null)
                Text(
                  'Scheduled: ${announcement['scheduled_at']}',
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                if (status != 'published')
                  FilledButton.tonal(
                    onPressed: () => onStatus('published'),
                    child: const Text('Publish Now'),
                  ),
                if (status != 'scheduled')
                  OutlinedButton(
                    onPressed: () => onStatus('scheduled'),
                    child: const Text('Schedule'),
                  ),
                if (status != 'archived')
                  TextButton(
                    onPressed: () => onStatus('archived'),
                    child: const Text('Archive'),
                  ),
                if (status == 'archived')
                  TextButton(
                    onPressed: () => onStatus('draft'),
                    child: const Text('Return to Draft'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static StitchChipVariant _statusVariant(String status) {
    switch (status) {
      case 'published':
        return StitchChipVariant.success;
      case 'scheduled':
        return StitchChipVariant.warn;
      default:
        return StitchChipVariant.neutral;
    }
  }

  static String _audienceLabel(String? audience) {
    switch (audience) {
      case 'teachers':
        return 'Teachers';
      case 'parents':
        return 'Parents';
      case 'students':
        return 'Students';
      case 'staff':
        return 'Staff';
      case 'school_admins':
        return 'School Admins';
      default:
        return 'Everyone';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 50,
              color: AppTheme.stitchMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No announcements match this filter.',
              style: TextStyle(color: AppTheme.stitchMuted),
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

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/notification_controller.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

// Screen 17 - Notification Centre
// Server-scoped through get_notification_center(); Realtime listens only to
// notifications addressed to the active profile.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['All', 'Unread', 'Academic', 'Finance', 'Messages'];
  String? _subscribedProfileId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _syncRealtime(String? profileId) {
    if (_subscribedProfileId == profileId) return;
    _subscribedProfileId = profileId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(notificationControllerProvider);
      controller.disposeRealtime();
      if (profileId != null && profileId.isNotEmpty) {
        controller.subscribe(activeProfileId: profileId);
      }
    });
  }

  @override
  void dispose() {
    ref.read(notificationControllerProvider).disposeRealtime();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    _syncRealtime(session?.profileId);

    final centerAsync = ref.watch(notificationCenterProvider);

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
              'Notification Centre',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final count = await ref
                  .read(notificationControllerProvider)
                  .markAllRead();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$count notification${count == 1 ? '' : 's'} marked as read')),
                );
              }
            },
            icon: const Icon(
              Icons.done_all_rounded,
              size: 16,
              color: AppTheme.primary,
            ),
            label: const Text(
              'Mark All Read',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.stitchMuted,
          indicatorColor: AppTheme.primary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(notificationCenterProvider.future).then<void>((_) {});
        },
        child: centerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error loading notifications: $e',
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
          data: (center) {
            final rawItems = (center['items'] as List<dynamic>?) ?? const [];
            final all = rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final filtered = _filter(all, _tabController.index);

            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: AppTheme.stitchBorder,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No notifications',
                          style: TextStyle(
                            color: AppTheme.stitchMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You are all caught up',
                          style: TextStyle(
                            color: AppTheme.stitchMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final notification = filtered[i];
                return _NotifTile(
                  n: notification,
                  onTap: notification['read_at'] == null
                      ? () async {
                          final id = notification['id']?.toString();
                          if (id == null || id.isEmpty) return;
                          await ref
                              .read(notificationControllerProvider)
                              .markRead(id);
                        }
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> all,
    int tab,
  ) {
    switch (tab) {
      case 1:
        return all.where((n) => n['read_at'] == null).toList();
      case 2:
        return all.where((n) {
          final category = (n['category'] ?? '').toString().toLowerCase();
          return category.contains('academic') ||
              category.contains('report') ||
              category.contains('grade') ||
              category.contains('attendance');
        }).toList();
      case 3:
        return all.where((n) {
          final category = (n['category'] ?? '').toString().toLowerCase();
          return category.contains('finance') ||
              category.contains('invoice') ||
              category.contains('payment') ||
              category.contains('fee');
        }).toList();
      case 4:
        return all.where((n) {
          final category = (n['category'] ?? '').toString().toLowerCase();
          return category.contains('message') || category.contains('chat');
        }).toList();
      default:
        return all;
    }
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> n;
  final VoidCallback? onTap;

  const _NotifTile({required this.n, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = n['title'] ?? 'Notification';
    final body = n['body'] ?? '';
    final category = (n['category'] ?? '').toString().toLowerCase();
    final priority = (n['priority'] ?? 'normal').toString().toLowerCase();
    final isRead = n['read_at'] != null;
    final createdAt = n['created_at'];
    final when = createdAt != null
        ? _fmt(DateTime.tryParse(createdAt.toString()))
        : '';

    final chipLabel = category.contains('finance') || category.contains('payment')
        ? 'Finance'
        : category.contains('academic') || category.contains('report')
            ? 'Academic'
            : category.contains('message')
                ? 'Message'
                : category.contains('attendance')
                    ? 'Attendance'
                    : 'Info';

    final chipVariant = priority == 'urgent' || priority == 'high'
        ? StitchChipVariant.warn
        : category.contains('finance') || category.contains('payment')
            ? StitchChipVariant.success
            : StitchChipVariant.neutral;

    return StitchCard(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isRead ? AppTheme.stitchBg : AppTheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _icon(category),
            color: isRead ? AppTheme.stitchMuted : AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title.toString(),
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
            color: AppTheme.stitchHeading,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.toString().isNotEmpty)
              Text(
                body.toString(),
                style: const TextStyle(
                  color: AppTheme.stitchMuted,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (when.isNotEmpty)
              Text(
                when,
                style: const TextStyle(
                  color: AppTheme.stitchMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        trailing: isRead
            ? null
            : StitchChip(label: chipLabel, variant: chipVariant),
      ),
    );
  }

  IconData _icon(String category) {
    if (category.contains('message')) return Icons.message_rounded;
    if (category.contains('finance') || category.contains('payment')) {
      return Icons.payments_rounded;
    }
    if (category.contains('attendance')) return Icons.how_to_reg_rounded;
    if (category.contains('report') || category.contains('academic')) {
      return Icons.school_rounded;
    }
    if (category.contains('transport') || category.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    return Icons.notifications_rounded;
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

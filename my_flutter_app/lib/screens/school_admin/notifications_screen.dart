import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

// Screen 17 - Notification Centre
// Reads from public.notifications, scoped to active profile/school.

final notificationsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(activeSessionProvider);
  if (session == null) return [];
  try {
    final res = await client
        .from('notifications')
        .select()
        .eq('school_id', session.schoolId)
        .eq('profile_id', session.profileId)
        .order('created_at', ascending: false)
        .limit(80);
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    debugPrint('[Notifications] fetch error: ');
    return [];
  }
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['All', 'Unread', 'Academic', 'Finance', 'Messages'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COMMUNICATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.primaryDark)),
            Text('Notification Centre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(rpcClientProvider).markAllNotificationsRead();
              ref.invalidate(notificationsListProvider);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('All marked as read')),
                );
              }
            },
            icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primary),
            label: const Text('Mark All Read', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
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
        onRefresh: () async => ref.invalidate(notificationsListProvider),
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: ', style: const TextStyle(color: AppTheme.danger))),
          data: (all) {
            final filtered = _filter(all, _tabController.index);
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: AppTheme.stitchBorder),
                    const SizedBox(height: 14),
                    const Text('No notifications', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('You are all caught up', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NotifTile(n: filtered[i]),
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all, int tab) {
    switch (tab) {
      case 1: return all.where((n) => n['is_read'] != true).toList();
      case 2: return all.where((n) { final t = (n['type'] ?? '').toString().toLowerCase(); return t.contains('academic') || t.contains('report') || t.contains('grade') || t.contains('attendance'); }).toList();
      case 3: return all.where((n) { final t = (n['type'] ?? '').toString().toLowerCase(); return t.contains('finance') || t.contains('invoice') || t.contains('payment') || t.contains('fee'); }).toList();
      case 4: return all.where((n) { final t = (n['type'] ?? '').toString().toLowerCase(); return t.contains('message') || t.contains('chat'); }).toList();
      default: return all;
    }
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> n;
  const _NotifTile({required this.n});

  @override
  Widget build(BuildContext context) {
    final title = n['title'] ?? n['subject'] ?? 'Notification';
    final body = n['body'] ?? n['message'] ?? '';
    final type = (n['type'] ?? '').toString().toLowerCase();
    final isRead = n['is_read'] == true;
    final createdAt = n['created_at'];
    final when = createdAt != null ? _fmt(DateTime.tryParse(createdAt.toString())) : '';

    final chipLabel = type.contains('finance') || type.contains('payment') ? 'Finance'
        : type.contains('academic') || type.contains('report') ? 'Academic'
        : type.contains('message') ? 'Message'
        : type.contains('attendance') ? 'Attendance'
        : 'Info';
    final chipVariant = type.contains('finance') || type.contains('payment') ? StitchChipVariant.success
        : type.contains('overdue') ? StitchChipVariant.warn
        : StitchChipVariant.neutral;

    return StitchCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isRead ? AppTheme.stitchBg : AppTheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(_icon(type), color: isRead ? AppTheme.stitchMuted : AppTheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: AppTheme.stitchHeading, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (when.isNotEmpty)
              Text(when, style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 10)),
          ],
        ),
        trailing: isRead ? null : StitchChip(label: chipLabel, variant: chipVariant),
      ),
    );
  }

  IconData _icon(String type) {
    if (type.contains('message')) return Icons.message_rounded;
    if (type.contains('finance') || type.contains('payment')) return Icons.payments_rounded;
    if (type.contains('attendance')) return Icons.how_to_reg_rounded;
    if (type.contains('report') || type.contains('academic')) return Icons.school_rounded;
    if (type.contains('transport') || type.contains('bus')) return Icons.directions_bus_rounded;
    return Icons.notifications_rounded;
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'm ago';
    if (diff.inHours < 24) return 'h ago';
    if (diff.inDays < 7) return 'd ago';
    return '//';
  }
}

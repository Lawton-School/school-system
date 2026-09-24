import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for Notification Centre reads, read-state mutations and Realtime.
/// All data is scoped by the active profile on the server; callers never pass
/// a recipient/profile id into the RPCs.
class NotificationRepository {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final Set<String> _seenRealtimeIds = <String>{};

  NotificationRepository(this._client);

  Future<Map<String, dynamic>> fetchCenter({
    int limit = 80,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_notification_center',
      params: {
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> markRead(String notificationId) async {
    await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<int> markAllRead() async {
    final response = await _client.rpc('mark_all_notifications_read');
    return (response as num?)?.toInt() ?? 0;
  }

  void subscribeToRealtime({
    required String activeProfileId,
    required VoidCallback onChanged,
  }) {
    disposeRealtime();
    if (activeProfileId.isEmpty) return;

    _channel = _client.channel('notifications:$activeProfileId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_profile_id',
            value: activeProfileId,
          ),
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final id = record['id']?.toString();

            // Inserts can be delivered more than once after reconnect. Updates
            // must still invalidate even when the id has already been seen.
            if (payload.eventType == PostgresChangeEvent.insert && id != null) {
              if (!_seenRealtimeIds.add(id)) return;
            }
            onChanged();
          },
        )
        .subscribe();
  }

  void disposeRealtime() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _seenRealtimeIds.clear();
  }
}

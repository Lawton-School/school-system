import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsRepository {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  AnnouncementsRepository(this._client);

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String schoolId) async {
    final response = await _client
        .from('announcements')
        .select(
          'id, school_id, title, content, author_profile_id, target_role, status, priority, '
          'scheduled_at, published_at, expires_at, target_class_section_id, attachment_urls, created_at, updated_at, '
          'author:profiles!announcements_author_profile_id_fkey(first_name, last_name, role), '
          'class_section:class_sections!announcements_target_class_section_id_fkey(name, classes(name))',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveDraft({
    String? announcementId,
    required String title,
    required String content,
    required String targetRole,
    required String priority,
    String? targetClassSectionId,
  }) async {
    final response = await _client.rpc('save_announcement_draft', params: {
      'p_announcement_id': announcementId,
      'p_title': title.trim(),
      'p_content': content.trim(),
      'p_target_role': targetRole,
      'p_priority': priority,
      'p_target_class_section_id': targetClassSectionId,
      'p_attachment_urls': <String>[],
    });
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> setStatus({
    required String announcementId,
    required String status,
    DateTime? scheduledAt,
    DateTime? expiresAt,
  }) async {
    final response = await _client.rpc('set_announcement_status', params: {
      'p_announcement_id': announcementId,
      'p_status': status,
      'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(response as Map);
  }

  void subscribe({
    required String schoolId,
    required VoidCallback onChanged,
  }) {
    disposeRealtime();
    if (schoolId.isEmpty) return;

    _channel = _client.channel('announcements:$schoolId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'school_id',
            value: schoolId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void disposeRealtime() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}

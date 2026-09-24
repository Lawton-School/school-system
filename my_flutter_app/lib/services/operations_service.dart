import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'legacy_services.dart' as legacy;

/// Hardened compatibility facade for school operations.
///
/// Existing read/leave/clocking behavior is inherited while attendance upserts
/// and announcement publishing are aligned to the verified production schema
/// and server-authoritative announcement RPCs.
class SchoolOperationsService extends legacy.SchoolOperationsService {
  final SupabaseClient _client;

  SchoolOperationsService(this._client) : super(_client);

  @override
  Future<AttendanceEntryModel> markAttendance({
    required String schoolId,
    required String studentProfileId,
    required String classSectionId,
    required DateTime date,
    required String status,
    String? remarks,
  }) async {
    final response = await _client.from('daily_attendance').upsert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'class_section_id': classSectionId,
      'date': date.toIso8601String().split('T')[0],
      'status': status,
      'remarks': remarks,
    }, onConflict: 'school_id,class_section_id,student_profile_id,date').select(
      '*, profiles!daily_attendance_student_profile_id_fkey(*), class_sections(*, classes(*))',
    ).single();

    return AttendanceEntryModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<SchoolAnnouncementModel> createAnnouncement({
    required String schoolId,
    required String title,
    required String content,
    required String targetRole,
    required String authorProfileId,
  }) async {
    final draft = await _client.rpc(
      'save_announcement_draft',
      params: {
        'p_announcement_id': null,
        'p_title': title,
        'p_content': content,
        'p_target_role': targetRole,
        'p_priority': 'normal',
        'p_target_class_section_id': null,
        'p_attachment_urls': <String>[],
      },
    );

    final draftMap = Map<String, dynamic>.from(draft as Map);
    final announcementId = draftMap['id']?.toString();
    if (announcementId == null || announcementId.isEmpty) {
      throw StateError('Announcement draft RPC returned no announcement id.');
    }

    final published = await _client.rpc(
      'set_announcement_status',
      params: {
        'p_announcement_id': announcementId,
        'p_status': 'published',
        'p_scheduled_at': null,
        'p_expires_at': null,
      },
    );

    return SchoolAnnouncementModel.fromMap(
      Map<String, dynamic>.from(published as Map),
    );
  }
}

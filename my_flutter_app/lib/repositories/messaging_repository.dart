import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Clean Architecture Repository for Direct Messaging (Screens 09 & 16).
class MessagingRepository {
  final SupabaseClient _client;
  final String? Function() _getActiveProfileId;
  final String? Function() _getActiveSchoolId;

  RealtimeChannel? _realtimeChannel;
  final Set<String> _receivedMessageIds = {};

  MessagingRepository({
    required this._client,
    required this._getActiveProfileId,
    required this._getActiveSchoolId,
  });

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return [];

    try {
      final response = await _client
          .from('direct_messages')
          .select(
            'id, school_id, sender_profile_id, recipient_profile_id, message, created_at, '
            'sender:profiles!direct_messages_sender_profile_id_fkey(id, first_name, last_name, role), '
            'recipient:profiles!direct_messages_recipient_profile_id_fkey(id, first_name, last_name, role)',
          )
          .or(
            'sender_profile_id.eq.$myProfileId,recipient_profile_id.eq.$myProfileId',
          )
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>?) ?? [];
      final contacts = <String, Map<String, dynamic>>{};

      for (final raw in list) {
        final item = Map<String, dynamic>.from(raw as Map);
        final senderId = item['sender_profile_id'] as String;
        final recipientId = item['recipient_profile_id'] as String;
        final otherId = senderId == myProfileId ? recipientId : senderId;

        if (!contacts.containsKey(otherId)) {
          final profileRaw = senderId == myProfileId
              ? item['recipient']
              : item['sender'];
          final otherProfile = _profileMap(profileRaw);
          contacts[otherId] = {
            'profile_id': otherId,
            'name': _profileName(otherProfile),
            'role': otherProfile?['role'] ?? 'staff',
            'last_message': item['message'],
            'last_time': item['created_at'],
          };
        }
      }

      return contacts.values.toList(growable: false);
    } catch (e) {
      debugPrint('[MessagingRepository] fetchConversations error: $e');
      return [];
    }
  }

  /// Returns active profiles in the currently selected school that can be
  /// selected when starting a new direct-message conversation.
  Future<List<Map<String, dynamic>>> fetchAvailableContacts() async {
    final myProfileId = _getActiveProfileId();
    final schoolId = _getActiveSchoolId();
    if (myProfileId == null ||
        myProfileId.isEmpty ||
        schoolId == null ||
        schoolId.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('profiles')
          .select('id, first_name, last_name, role, status')
          .eq('school_id', schoolId)
          .eq('status', 'active')
          .neq('id', myProfileId)
          .isFilter('deleted_at', null)
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((raw) {
        final profile = Map<String, dynamic>.from(raw as Map);
        return <String, dynamic>{
          'profile_id': profile['id'],
          'name': _profileName(profile),
          'role': profile['role'] ?? 'staff',
        };
      }).toList(growable: false);
    } catch (e) {
      debugPrint('[MessagingRepository] fetchAvailableContacts error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchParentTeacherMeetings() async {
    final response=await _client.rpc('get_parent_teacher_meetings');
    return ((response as List<dynamic>?)??const []).map((e)=>Map<String,dynamic>.from(e as Map)).toList(growable:false);
  }

  Future<String?> requestParentTeacherMeeting({required String counterpartProfileId,required String studentProfileId,required DateTime scheduledAt,required String reason,String? subjectId,String mode='in_person'}) async {
    try {
      final r=await _client.rpc('request_parent_teacher_meeting',params:{'p_counterpart':counterpartProfileId,'p_student':studentProfileId,'p_scheduled_at':scheduledAt.toUtc().toIso8601String(),'p_reason':reason.trim(),'p_subject':subjectId,'p_mode':mode});
      return r?.toString();
    } catch(e){debugPrint('[MessagingRepository] requestParentTeacherMeeting error: $e');return null;}
  }

  Future<bool> respondParentTeacherMeeting({required String meetingId,required String status,DateTime? scheduledAt,String? locationOrLink,String? notes}) async {
    try {
      await _client.rpc('respond_parent_teacher_meeting',params:{'p_meeting':meetingId,'p_status':status,'p_scheduled_at':scheduledAt?.toUtc().toIso8601String(),'p_location_or_link':locationOrLink,'p_notes':notes});
      return true;
    } catch(e){debugPrint('[MessagingRepository] respondParentTeacherMeeting error: $e');return false;}
  }

  Future<List<Map<String, dynamic>>> fetchStudentConcerns() async {
    final response = await _client.rpc('get_student_concerns');
    return ((response as List<dynamic>?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<String?> createStudentConcern({
    required String parentProfileId,
    required String studentProfileId,
    required String kind,
    required String title,
    required String details,
    String? subjectId,
  }) async {
    try {
      final response = await _client.rpc('create_student_concern', params: {
        'p_parent': parentProfileId,
        'p_student': studentProfileId,
        'p_kind': kind,
        'p_title': title.trim(),
        'p_details': details.trim(),
        'p_subject': subjectId,
      });
      return response?.toString();
    } catch (e) {
      debugPrint('[MessagingRepository] createStudentConcern error: $e');
      return null;
    }
  }

  Future<bool> acknowledgeStudentConcern(String concernId) async {
    try {
      await _client.rpc('acknowledge_student_concern', params: {'p_concern': concernId});
      return true;
    } catch (e) {
      debugPrint('[MessagingRepository] acknowledgeStudentConcern error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTeacherParentContacts() async {
    try {
      final response = await _client.rpc('get_teacher_parent_contacts');
      return ((response as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[MessagingRepository] fetchTeacherParentContacts error: $e');
      return [];
    }
  }

  Future<DirectMessageItem?> sendTeacherParentMessage({
    required String recipientProfileId,
    required String studentProfileId,
    required String messageText,
    String? subjectId,
  }) async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null) return null;
    final trimmed = messageText.trim();
    if (trimmed.isEmpty) return null;
    try {
      final id = await _client.rpc('send_teacher_parent_message', params: {
        'p_recipient': recipientProfileId,
        'p_student': studentProfileId,
        'p_message': trimmed,
        'p_subject': subjectId,
      });
      final response = await _client.from('direct_messages').select(
        '*, sender:profiles!direct_messages_sender_profile_id_fkey(id, first_name, last_name, role)',
      ).eq('id', id).single();
      final map = Map<String, dynamic>.from(response);
      _normalizeSender(map);
      final item = DirectMessageItem.fromMap(map, myProfileId);
      _receivedMessageIds.add(item.id);
      return item;
    } catch (e) {
      debugPrint('[MessagingRepository] sendTeacherParentMessage error: $e');
      return null;
    }
  }

  Future<List<DirectMessageItem>> fetchThread(String otherProfileId, {String? studentProfileId, String? subjectId}) async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return [];

    try {
      var query = _client
          .from('direct_messages')
          .select(
            'id, school_id, sender_profile_id, recipient_profile_id, message, created_at, context_student_id, context_subject_id, '
            'sender:profiles!direct_messages_sender_profile_id_fkey(id, first_name, last_name, role)',
          )
          .or(
            'and(sender_profile_id.eq.$myProfileId,recipient_profile_id.eq.$otherProfileId),'
            'and(sender_profile_id.eq.$otherProfileId,recipient_profile_id.eq.$myProfileId)',
          )
          .isFilter('deleted_at', null);
      if (studentProfileId != null) query = query.eq('context_student_id', studentProfileId);
      if (subjectId != null) query = query.eq('context_subject_id', subjectId);
      final response = await query.order('created_at', ascending: true);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        _normalizeSender(map);
        return DirectMessageItem.fromMap(map, myProfileId);
      }).toList(growable: false);
    } catch (e) {
      debugPrint('[MessagingRepository] fetchThread error: $e');
      return [];
    }
  }

  Future<DirectMessageItem?> sendMessage({
    required String recipientProfileId,
    required String messageText,
  }) async {
    final myProfileId = _getActiveProfileId();
    final schoolId = _getActiveSchoolId();
    if (myProfileId == null || schoolId == null) return null;

    final trimmed = messageText.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await _client.from('direct_messages').insert({
        'school_id': schoolId,
        'sender_profile_id': myProfileId,
        'recipient_profile_id': recipientProfileId,
        'message': trimmed,
      }).select(
        '*, sender:profiles!direct_messages_sender_profile_id_fkey(id, first_name, last_name, role)',
      ).single();

      final map = Map<String, dynamic>.from(response);
      _normalizeSender(map);
      final item = DirectMessageItem.fromMap(map, myProfileId);
      _receivedMessageIds.add(item.id);
      return item;
    } catch (e) {
      debugPrint('[MessagingRepository] sendMessage error: $e');
      return null;
    }
  }

  void subscribeToRealtime({
    required void Function(DirectMessageItem message) onMessageReceived,
  }) {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return;

    disposeRealtime();

    final channelName = 'realtime:direct_messages:$myProfileId';
    _realtimeChannel = _client.channel(channelName);

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'direct_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'recipient_profile_id',
        value: myProfileId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        final id = newRecord['id'] as String? ?? '';
        if (_receivedMessageIds.contains(id)) return;
        _receivedMessageIds.add(id);
        onMessageReceived(DirectMessageItem.fromMap(newRecord, myProfileId));
      },
    ).subscribe();

    debugPrint(
      '[MessagingRepository] Subscribed to Realtime direct messages on $channelName',
    );
  }

  void disposeRealtime() {
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _receivedMessageIds.clear();
  }

  static Map<String, dynamic>? _profileMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _profileName(Map<String, dynamic>? profile) {
    if (profile == null) return 'School Staff';
    final firstName = profile['first_name']?.toString().trim() ?? '';
    final lastName = profile['last_name']?.toString().trim() ?? '';
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'School Staff' : name;
  }

  static void _normalizeSender(Map<String, dynamic> message) {
    final sender = _profileMap(message['sender']);
    if (sender == null) return;
    sender['full_name'] = _profileName(sender);
    message['sender'] = sender;
  }
}

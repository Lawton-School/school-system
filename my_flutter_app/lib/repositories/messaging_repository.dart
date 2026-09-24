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

  Future<List<DirectMessageItem>> fetchThread(String otherProfileId) async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return [];

    try {
      final response = await _client
          .from('direct_messages')
          .select(
            'id, school_id, sender_profile_id, recipient_profile_id, message, created_at, '
            'sender:profiles!direct_messages_sender_profile_id_fkey(id, first_name, last_name, role)',
          )
          .or(
            'and(sender_profile_id.eq.$myProfileId,recipient_profile_id.eq.$otherProfileId),'
            'and(sender_profile_id.eq.$otherProfileId,recipient_profile_id.eq.$myProfileId)',
          )
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);

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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Clean Architecture Repository for Direct Messaging (Screens 09 & 16)
/// Connects to `public.direct_messages`, `public.profiles`, and Supabase Realtime.
/// All queries are strictly scoped to the active profile context.
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

  /// Fetch conversations involving the active profile
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return [];

    try {
      final response = await _client
          .from('direct_messages')
          .select('id, school_id, sender_profile_id, recipient_profile_id, message, created_at, sender:profiles!direct_messages_sender_profile_id_fkey(id, full_name, role), recipient:profiles!direct_messages_recipient_profile_id_fkey(id, full_name, role)')
          .or('sender_profile_id.eq.$myProfileId,recipient_profile_id.eq.$myProfileId')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>?) ?? [];
      final Map<String, Map<String, dynamic>> contactMap = {};

      for (final raw in list) {
        final item = Map<String, dynamic>.from(raw as Map);
        final senderId = item['sender_profile_id'] as String;
        final recipientId = item['recipient_profile_id'] as String;
        final otherId = senderId == myProfileId ? recipientId : senderId;

        if (!contactMap.containsKey(otherId)) {
          final otherProfile = senderId == myProfileId ? item['recipient'] : item['sender'];
          contactMap[otherId] = {
            'profile_id': otherId,
            'name': otherProfile?['full_name'] ?? 'School Staff',
            'role': otherProfile?['role'] ?? 'Staff',
            'last_message': item['message'],
            'last_time': item['created_at'],
          };
        }
      }

      return contactMap.values.toList();
    } catch (e) {
      debugPrint('[MessagingRepository] fetchConversations error: $e');
      return [];
    }
  }

  /// Fetch all messages in a conversation between active profile and counterpart
  Future<List<DirectMessageItem>> fetchThread(String otherProfileId) async {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return [];

    try {
      final response = await _client
          .from('direct_messages')
          .select('id, school_id, sender_profile_id, recipient_profile_id, message, created_at, sender:profiles!direct_messages_sender_profile_id_fkey(id, full_name, role)')
          .or('and(sender_profile_id.eq.$myProfileId,recipient_profile_id.eq.$otherProfileId),and(sender_profile_id.eq.$otherProfileId,recipient_profile_id.eq.$myProfileId)')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        return DirectMessageItem.fromMap(map, myProfileId);
      }).toList();
    } catch (e) {
      debugPrint('[MessagingRepository] fetchThread error: $e');
      return [];
    }
  }

  /// Send a new direct message
  Future<DirectMessageItem?> sendMessage({
    required String recipientProfileId,
    required String messageText,
  }) async {
    final myProfileId = _getActiveProfileId();
    final schoolId = _getActiveSchoolId();
    if (myProfileId == null || schoolId == null) return null;

    try {
      final response = await _client.from('direct_messages').insert({
        'school_id': schoolId,
        'sender_profile_id': myProfileId,
        'recipient_profile_id': recipientProfileId,
        'message': messageText.trim(),
      }).select('*, sender:profiles!direct_messages_sender_profile_id_fkey(id, full_name, role)').single();

      final item = DirectMessageItem.fromMap(Map<String, dynamic>.from(response), myProfileId);
      _receivedMessageIds.add(item.id);
      return item;
    } catch (e) {
      debugPrint('[MessagingRepository] sendMessage error: $e');
      return null;
    }
  }

  /// Subscribe to Realtime incoming direct messages for the active profile
  void subscribeToRealtime({required void Function(DirectMessageItem message) onMessageReceived}) {
    final myProfileId = _getActiveProfileId();
    if (myProfileId == null || myProfileId.isEmpty) return;

    // Dispose any existing subscription to prevent duplicates
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
        if (_receivedMessageIds.contains(id)) return; // Deduplicate
        _receivedMessageIds.add(id);

        final item = DirectMessageItem.fromMap(newRecord, myProfileId);
        onMessageReceived(item);
      },
    ).subscribe();

    debugPrint('[MessagingRepository] Subscribed to Realtime direct messages on $channelName');
  }

  /// Dispose Realtime channel cleanly
  void disposeRealtime() {
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      debugPrint('[MessagingRepository] Disposed direct messages Realtime channel');
    }
    _receivedMessageIds.clear();
  }
}

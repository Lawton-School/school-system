import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/messaging_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 16 — Direct Messaging.
///
/// Staff-facing messaging backed by `public.direct_messages`. Existing threads
/// are Realtime-enabled and new conversations can only target active profiles
/// in the current school.
class DirectMessagingScreen extends ConsumerStatefulWidget {
  const DirectMessagingScreen({super.key});

  @override
  ConsumerState<DirectMessagingScreen> createState() =>
      _DirectMessagingScreenState();
}

class _DirectMessagingScreenState
    extends ConsumerState<DirectMessagingScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _selectedContact;
  List<DirectMessageItem> _messages = [];
  bool _loadingThread = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
  }

  void _subscribeRealtime() {
    final repository = ref.read(directMessagingRepositoryProvider);
    repository.subscribeToRealtime(onMessageReceived: (message) {
      if (!mounted) return;
      final contactId = _selectedContact?['profile_id']?.toString();
      if (contactId != null &&
          (message.senderProfileId == contactId ||
              message.recipientProfileId == contactId)) {
        _appendIfMissing(message);
        _scrollToBottom();
      }
      ref.invalidate(directMessageConversationsProvider);
    });
  }

  @override
  void dispose() {
    ref.read(directMessagingRepositoryProvider).disposeRealtime();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectContact(Map<String, dynamic> contact) async {
    final id = contact['profile_id']?.toString() ?? '';
    if (id.isEmpty) return;

    setState(() {
      _selectedContact = contact;
      _messages = [];
      _loadingThread = true;
    });

    final thread =
        await ref.read(directMessagingRepositoryProvider).fetchThread(id);
    if (!mounted) return;

    setState(() {
      _messages = thread;
      _loadingThread = false;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final recipientId = _selectedContact?['profile_id']?.toString() ?? '';
    final text = _messageController.text.trim();
    if (recipientId.isEmpty || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final sent = await ref.read(directMessagingRepositoryProvider).sendMessage(
          recipientProfileId: recipientId,
          messageText: text,
        );
    if (!mounted) return;

    setState(() => _sending = false);
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message could not be sent. Your text was kept.'),
        ),
      );
      return;
    }

    _messageController.clear();
    _appendIfMissing(sent);
    ref.invalidate(directMessageConversationsProvider);
    _scrollToBottom();
  }

  void _appendIfMissing(DirectMessageItem message) {
    if (_messages.any((item) => item.id == message.id)) return;
    setState(() => _messages.add(message));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startConversation() async {
    final contacts = await ref.read(directMessageContactsProvider.future);
    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other active school profiles found.')),
      );
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _ContactPickerDialog(contacts: contacts),
    );
    if (selected != null && mounted) {
      await _selectContact(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(directMessageConversationsProvider);

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
              'Direct Messaging',
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
            tooltip: 'Refresh conversations',
            onPressed: () => ref.invalidate(directMessageConversationsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _startConversation,
              icon: const Icon(Icons.add_comment_rounded, size: 17),
              label: const Text('New Message'),
            ),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load conversations: $error',
          onRetry: () => ref.invalidate(directMessageConversationsProvider),
        ),
        data: (contacts) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 800;
              if (desktop) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: StitchCard(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 320,
                          child: _buildContactsPane(contacts),
                        ),
                        Container(width: 1, color: AppTheme.stitchBorder),
                        Expanded(child: _buildThreadPane()),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (contacts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedContact?['profile_id']?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Conversation',
                          isDense: true,
                        ),
                        items: contacts
                            .where((contact) =>
                                (contact['profile_id']?.toString() ?? '').isNotEmpty)
                            .map(
                              (contact) => DropdownMenuItem<String>(
                                value: contact['profile_id']?.toString(),
                                child: Text(
                                  contact['name']?.toString() ?? 'School user',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          for (final contact in contacts) {
                            if (contact['profile_id']?.toString() == id) {
                              _selectContact(contact);
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  Expanded(child: _buildThreadPane()),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContactsPane(List<Map<String, dynamic>> contacts) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: StitchSectionHeader(
            title: 'Conversations',
            subtitle: 'School communication threads',
          ),
        ),
        const Divider(height: 1, color: AppTheme.stitchBorder),
        Expanded(
          child: contacts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No conversations yet. Use New Message to start one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.stitchMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final selected = _selectedContact?['profile_id'] ==
                        contact['profile_id'];
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xFFF8FAFC),
                      onTap: () => _selectContact(contact),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primarySoft,
                        child: Text(_initial(contact['name']?.toString())),
                      ),
                      title: Text(
                        contact['name']?.toString() ?? 'School user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        contact['last_message']?.toString() ??
                            _roleLabel(contact['role']?.toString()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThreadPane() {
    final contact = _selectedContact;
    if (contact == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 48,
                color: AppTheme.stitchMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select a conversation or start a new message.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.stitchMuted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _startConversation,
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text('New Message'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.stitchBorder)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primarySoft,
                child: Text(_initial(contact['name']?.toString())),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['name']?.toString() ?? 'School user',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                    Text(
                      _roleLabel(contact['role']?.toString()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const StitchChip(
                label: 'Messages',
                variant: StitchChipVariant.neutral,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Start the conversation below.',
                        style: TextStyle(color: AppTheme.stitchMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Align(
                          alignment: message.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 460),
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: message.isMe
                                  ? AppTheme.primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: message.isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    color: message.isMe
                                        ? Colors.white
                                        : AppTheme.stitchHeading,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: message.isMe
                                        ? Colors.white70
                                        : AppTheme.stitchMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.stitchBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_sending,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _initial(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
  }

  static String _roleLabel(String? role) {
    switch (role) {
      case 'school_admin':
        return 'School Admin';
      case 'finance_manager':
        return 'Finance Manager';
      case 'registrar':
        return 'Registrar';
      case 'teacher':
        return 'Teacher';
      case 'parent':
        return 'Parent';
      case 'student':
        return 'Student';
      case 'super_admin':
        return 'Super Admin';
      default:
        return 'School User';
    }
  }
}

class _ContactPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  const _ContactPickerDialog({required this.contacts});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.contacts.where((contact) {
      final haystack = '${contact['name'] ?? ''} ${contact['role'] ?? ''}'
          .toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList(growable: false);

    return AlertDialog(
      title: const Text('Start New Conversation'),
      content: SizedBox(
        width: 480,
        height: 430,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search school profiles',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No matching profiles.'))
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final contact = visible[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primarySoft,
                            child: Text(
                              _DirectMessagingScreenState._initial(
                                contact['name']?.toString(),
                              ),
                            ),
                          ),
                          title: Text(
                            contact['name']?.toString() ?? 'School user',
                          ),
                          subtitle: Text(
                            _DirectMessagingScreenState._roleLabel(
                              contact['role']?.toString(),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, contact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
            const Icon(Icons.error_outline_rounded, size: 42),
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

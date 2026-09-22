import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 09: Parent Direct Messages & School Staff Communication
/// Connects authoritatively to `public.direct_messages` via [MessagingRepository].
/// Realtime events are deduplicated, lifecycle-managed, and disposed upon unmount.
class ParentMessagesScreen extends ConsumerStatefulWidget {
  const ParentMessagesScreen({super.key});

  @override
  ConsumerState<ParentMessagesScreen> createState() => _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends ConsumerState<ParentMessagesScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _selectedContact;
  List<DirectMessageItem> _messages = [];
  bool _loadingThread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtime();
    });
  }

  void _initRealtime() {
    final repo = ref.read(messagingRepositoryProvider);
    repo.subscribeToRealtime(onMessageReceived: (incoming) {
      if (mounted) {
        if (_selectedContact != null &&
            (_selectedContact!['profile_id'] == incoming.senderProfileId ||
                _selectedContact!['profile_id'] == incoming.recipientProfileId)) {
          setState(() {
            _messages.add(incoming);
          });
          _scrollToBottom();
        }
        ref.read(parentMessagesControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    final repo = ref.read(messagingRepositoryProvider);
    repo.disposeRealtime();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectContact(Map<String, dynamic> contact) async {
    setState(() {
      _selectedContact = contact;
      _loadingThread = true;
      _messages = [];
    });

    final repo = ref.read(messagingRepositoryProvider);
    final otherId = contact['profile_id'] as String;
    final thread = await repo.fetchThread(otherId);

    if (mounted) {
      setState(() {
        _messages = thread;
        _loadingThread = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedContact == null) return;

    final repo = ref.read(messagingRepositoryProvider);
    final recipientId = _selectedContact!['profile_id'] as String;
    _textController.clear();

    final sent = await repo.sendMessage(
      recipientProfileId: recipientId,
      messageText: text,
    );

    if (sent != null && mounted) {
      setState(() {
        _messages.add(sent);
      });
      _scrollToBottom();
      ref.read(parentMessagesControllerProvider.notifier).refresh();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(parentMessagesControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        title: const Text('Direct Messages & Staff Communication',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.stitchHeading)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.stitchHeading),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Conversations',
            onPressed: () => ref.read(parentMessagesControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading messages: $err')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.forum_rounded, size: 36, color: AppTheme.primaryDark),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Active Conversations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.stitchHeading),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No messages have been sent or received yet.\nMessages from class teachers and school administrators will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.stitchMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          // Auto-select first contact if none selected
          if (_selectedContact == null && contacts.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _selectContact(contacts.first);
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;

              if (isDesktop) {
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
                        Expanded(
                          child: _buildConversationPane(),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return _buildConversationPane(showContactSelector: true, contacts: contacts);
              }
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
            subtitle: 'Staff and administration contacts',
          ),
        ),
        const Divider(height: 1, color: AppTheme.stitchBorder),
        Expanded(
          child: ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final isSelected = _selectedContact?['profile_id'] == contact['profile_id'];

              return ListTile(
                selected: isSelected,
                selectedTileColor: const Color(0xFFF8FAFC),
                onTap: () => _selectContact(contact),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primarySoft,
                  child: Text(
                    (contact['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  contact['name']?.toString() ?? 'Staff Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  contact['last_message']?.toString() ?? contact['role']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConversationPane({bool showContactSelector = false, List<Map<String, dynamic>>? contacts}) {
    if (_selectedContact == null) {
      return const Center(child: Text('Select a conversation to start messaging'));
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.stitchBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primarySoft,
                    child: Text(
                      (_selectedContact!['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedContact!['name']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.stitchHeading),
                      ),
                      Text(
                        _selectedContact!['role']?.toString() ?? 'School Staff',
                        style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const StitchChip(label: 'Connected', variant: StitchChipVariant.success),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Text('No messages in this conversation yet. Send a message below.',
                          style: TextStyle(color: AppTheme.stitchMuted, fontSize: 12)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.isMe;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: const BoxConstraints(maxWidth: 440),
                            decoration: BoxDecoration(
                              color: isMe ? AppTheme.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppTheme.stitchHeading,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, "0")}',
                                  style: TextStyle(
                                    color: isMe ? Colors.white.withAlpha(180) : AppTheme.stitchMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // Input bar
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
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.stitchBorder)),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


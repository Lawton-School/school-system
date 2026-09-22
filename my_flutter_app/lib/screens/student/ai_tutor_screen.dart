import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  SubjectModel? _selectedSubject;
  bool _isGenerating = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendPrompt(String schoolId, String studentProfileId, String sessionId, String prompt) async {
    if (prompt.trim().isEmpty) return;
    _promptCtrl.clear();
    setState(() => _isGenerating = true);
    final client = ref.read(supabaseClientProvider);
    final service = AiTutorService(client);

    try {
      // 1. Send user message
      await service.sendUserMessage(
        schoolId: schoolId,
        sessionId: sessionId,
        content: prompt.trim(),
      );
      ref.invalidate(aiMessagesProvider((schoolId, sessionId)));

      // 2. Generate AI tutor response (via OpenAI live or contextual fallback)
      await service.generateAiResponse(
        schoolId: schoolId,
        sessionId: sessionId,
        prompt: prompt.trim(),
        subjectName: _selectedSubject?.name,
      );
      ref.invalidate(aiMessagesProvider((schoolId, sessionId)));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final studentProfileId = session.profileId;
    final subjectsAsync = ref.watch(subjectsProvider(schoolId));
    final sessionAsync = ref.watch(aiSessionProvider((schoolId, studentProfileId, _selectedSubject?.id)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6557F5), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZivoConnect AI Study Tutor',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF172033),
                    ),
                  ),
                  Text(
                    'DeepSeek AI • 24/7 Educational Assistant',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF18B77A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            labelColor: const Color(0xFF6557F5),
            unselectedLabelColor: const Color(0xFF74809A),
            indicatorColor: const Color(0xFF6557F5),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_rounded), text: 'AI Study Chat'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Learning Profile'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── AI CHAT TAB ─────────────────────────────────────────
            Column(
              children: [
                // Subject Filter Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF6557F5)),
                      const SizedBox(width: 8),
                      Text(
                        'Focus Subject:',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF74809A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: subjectsAsync.when(
                          data: (subjects) {
                            return DropdownButtonHideUnderline(
                              child: DropdownButton<SubjectModel>(
                                isExpanded: true,
                                value: _selectedSubject,
                                hint: Text(
                                  'General Studies (All Subjects)',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF172033)),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'General Studies (All Subjects)',
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                  ),
                                  ...subjects.map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name, style: GoogleFonts.inter(fontSize: 13)),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _selectedSubject = v),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEDEFF5)),

                // Quick Prompt Starters
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFFF6F7FB),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _QuickChip(
                        label: '📐 Pythagorean Theorem',
                        onTap: () {
                          if (sessionAsync.hasValue) {
                            _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, 'Explain the Pythagorean Theorem step-by-step with a real example');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: '✍️ PEEL Essay Structure',
                        onTap: () {
                          if (sessionAsync.hasValue) {
                            _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, 'How do I write a high-scoring academic essay using the PEEL technique?');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: '🔢 Quadratic Formula',
                        onTap: () {
                          if (sessionAsync.hasValue) {
                            _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, 'Explain the quadratic formula and how the discriminant works.');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: '🌿 Photosynthesis',
                        onTap: () {
                          if (sessionAsync.hasValue) {
                            _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, 'Break down the equation and stages of photosynthesis for secondary biology.');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Chat messages list
                Expanded(
                  child: sessionAsync.when(
                    data: (aiSession) {
                      final messagesAsync = ref.watch(aiMessagesProvider((schoolId, aiSession.id)));

                      return messagesAsync.when(
                        data: (messages) {
                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDEAFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.smart_toy_rounded, size: 52, color: Color(0xFF6557F5)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Hello! I am your AI Study Tutor.',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF172033),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 360),
                                      child: Text(
                                        'Ask me any homework question, concept explanation, or exam revision problem.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF74809A),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length + (_isGenerating ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == messages.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6557F5)),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'AI Tutor is preparing your response...',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF74809A),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final msg = messages[i];
                              return Align(
                                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                  decoration: BoxDecoration(
                                    color: msg.isUser ? const Color(0xFF6557F5) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: msg.isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: .04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: SelectableText(
                                    msg.content,
                                    style: GoogleFonts.inter(
                                      color: msg.isUser ? Colors.white : const Color(0xFF172033),
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error loading messages: $e')),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error initializing AI session: $e')),
                  ),
                ),

                // Message Input Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              controller: _promptCtrl,
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF172033)),
                              decoration: InputDecoration(
                                hintText: 'Ask a question or request step-by-step help...',
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              onSubmitted: (val) {
                                if (sessionAsync.hasValue) {
                                  _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF6557F5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (sessionAsync.hasValue) {
                                _sendPrompt(schoolId, studentProfileId, sessionAsync.value!.id, _promptCtrl.text);
                              }
                            },
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            tooltip: 'Send Prompt',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── LEARNING PROFILE TAB ────────────────────────────────
            _buildLearningProfileTab(schoolId, studentProfileId),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningProfileTab(String schoolId, String studentProfileId) {
    final profileAsync = ref.watch(studentLearningProfileProvider((schoolId, studentProfileId)));

    return profileAsync.when(
      data: (profile) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDEAFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.psychology_rounded, size: 38, color: Color(0xFF6557F5)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Personal Diagnostic Profile',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last evaluated: ${profile.lastEvaluatedAt.day}/${profile.lastEvaluatedAt.month}/${profile.lastEvaluatedAt.year}',
                      style: GoogleFonts.inter(color: const Color(0xFF74809A), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Strengths Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF18B77A), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Demonstrated Strengths',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF172033)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...profile.strengths.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFF18B77A), fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(child: Text(s, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Priority Focus Areas
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Color(0xFFF5A623), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Priority Revision Focus Areas',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF172033)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...profile.weaknesses.map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFFF5A623), fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(child: Text(w, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading learning profile: $e')),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF172033)),
      ),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

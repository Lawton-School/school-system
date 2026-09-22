import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';

/// Teacher AI Assistant Screen — Comprehensive educational copilot for teachers.
/// Includes Lesson Planner, Quiz & Exam Authoring, Report Card Remarks, and Chat.
class TeacherAiAssistantScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const TeacherAiAssistantScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<TeacherAiAssistantScreen> createState() => _TeacherAiAssistantScreenState();
}

class _TeacherAiAssistantScreenState extends ConsumerState<TeacherAiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Teacher AI Copilot',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.stitchHeading,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ZIMSEC & Cambridge • OpenAI / DeepSeek Live',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.stitchMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                Text(
                  session?.schoolName ?? 'Educator Hub',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Lesson Planner'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Quiz & Exam Bank'),
            Tab(icon: Icon(Icons.rate_review_rounded, size: 18), text: 'Report Remarks'),
            Tab(icon: Icon(Icons.psychology_rounded, size: 18), text: 'Pedagogy Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LessonPlannerTab(),
          _QuizGeneratorTab(),
          _ReportRemarksTab(),
          _PedagogyChatTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 1: LESSON PLANNER
// ─────────────────────────────────────────────────────────────────

class _LessonPlannerTab extends ConsumerStatefulWidget {
  const _LessonPlannerTab();

  @override
  ConsumerState<_LessonPlannerTab> createState() => _LessonPlannerTabState();
}

class _LessonPlannerTabState extends ConsumerState<_LessonPlannerTab> {
  final TextEditingController _topicCtrl = TextEditingController(text: 'Quadratic Equations & Parabolic Graphs');
  final TextEditingController _notesCtrl = TextEditingController();
  String _selectedSubject = 'Mathematics';
  String _selectedGrade = 'O-Level (Form 3-4)';
  String _selectedCurriculum = 'ZIMSEC & Cambridge';
  int _duration = 45;
  bool _isLoading = false;
  String? _generatedOutput;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _generate() async {
    if (_topicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a lesson topic.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedOutput = null;
    });

    final service = ref.read(teacherAiServiceProvider);
    try {
      final result = await service.generateLessonPlan(
        subject: _selectedSubject,
        topic: _topicCtrl.text.trim(),
        gradeLevel: _selectedGrade,
        durationMinutes: _duration,
        curriculum: _selectedCurriculum,
        additionalNotes: _notesCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _generatedOutput = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyOutput() {
    if (_generatedOutput == null) return;
    Clipboard.setData(ClipboardData(text: _generatedOutput!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lesson Plan copied to clipboard ✓'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lesson Plan Generator',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                Text(
                  'Generates complete 7-phase pedagogical plans compliant with ZIMSEC and Cambridge standards.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // Quick Preset Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPresetChip('Maths: Quadratic Formula', 'Mathematics', 'Quadratic Equations & Roots', 'O-Level (Form 3-4)'),
                    _buildPresetChip('Science: Photosynthesis', 'Physical / Life Science', 'Photosynthesis & Chloroplasts', 'Form 2'),
                    _buildPresetChip('English: Formal Writing', 'English Language', 'Argumentative & Formal Letter Essay', 'Form 3'),
                    _buildPresetChip('History: Great Zimbabwe', 'History', 'Rise & Trade of Great Zimbabwe State', 'Form 1-2'),
                  ],
                ),
                const SizedBox(height: 16),

                // Subject & Grade Level
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                          DropdownMenuItem(value: 'Physical / Life Science', child: Text('Physical / Life Science')),
                          DropdownMenuItem(value: 'English Language', child: Text('English Language')),
                          DropdownMenuItem(value: 'Geography', child: Text('Geography')),
                          DropdownMenuItem(value: 'History', child: Text('History')),
                          DropdownMenuItem(value: 'Commerce & Accounting', child: Text('Commerce & Accounts')),
                          DropdownMenuItem(value: 'Computer Science', child: Text('Computer Science')),
                        ],
                        onChanged: (v) => setState(() => _selectedSubject = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGrade,
                        decoration: const InputDecoration(labelText: 'Grade Level', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Grade 7 (Primary)', child: Text('Grade 7 (Primary)')),
                          DropdownMenuItem(value: 'Form 1', child: Text('Form 1')),
                          DropdownMenuItem(value: 'Form 2', child: Text('Form 2')),
                          DropdownMenuItem(value: 'O-Level (Form 3-4)', child: Text('O-Level (Form 3-4)')),
                          DropdownMenuItem(value: 'A-Level (Lower 6)', child: Text('A-Level (Lower 6)')),
                          DropdownMenuItem(value: 'A-Level (Upper 6)', child: Text('A-Level (Upper 6)')),
                        ],
                        onChanged: (v) => setState(() => _selectedGrade = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Topic Input
                TextField(
                  controller: _topicCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Topic / Unit',
                    hintText: 'e.g. Simultaneous Equations by Elimination',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Duration & Curriculum
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _duration,
                        decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 35, child: Text('35 Minutes')),
                          DropdownMenuItem(value: 45, child: Text('45 Minutes (Single Period)')),
                          DropdownMenuItem(value: 60, child: Text('60 Minutes')),
                          DropdownMenuItem(value: 80, child: Text('80 Minutes (Double Period)')),
                        ],
                        onChanged: (v) => setState(() => _duration = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCurriculum,
                        decoration: const InputDecoration(labelText: 'Curriculum Focus', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'ZIMSEC & Cambridge', child: Text('ZIMSEC & Cambridge')),
                          DropdownMenuItem(value: 'ZIMSEC Spec', child: Text('ZIMSEC Spec Only')),
                          DropdownMenuItem(value: 'Cambridge IGCSE', child: Text('Cambridge IGCSE')),
                        ],
                        onChanged: (v) => setState(() => _selectedCurriculum = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Specific instructions
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Notes / Focus (Optional)',
                    hintText: 'e.g. Emphasize common sign errors; include paired whiteboard exercise',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _generate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _isLoading ? 'Drafting Lesson Plan...' : 'Generate AI Lesson Plan',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_generatedOutput != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(
              title: 'Generated Lesson Plan',
              content: _generatedOutput!,
              onCopy: _copyOutput,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String subject, String topic, String grade) {
    return ActionChip(
      avatar: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF4F46E5)),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFEEF2FF),
      side: const BorderSide(color: Color(0xFFC7D2FE)),
      onPressed: () {
        setState(() {
          _selectedSubject = subject;
          _topicCtrl.text = topic;
          _selectedGrade = grade;
        });
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2: QUIZ & QUESTION BANK GENERATOR
// ─────────────────────────────────────────────────────────────────

class _QuizGeneratorTab extends ConsumerStatefulWidget {
  const _QuizGeneratorTab();

  @override
  ConsumerState<_QuizGeneratorTab> createState() => _QuizGeneratorTabState();
}

class _QuizGeneratorTabState extends ConsumerState<_QuizGeneratorTab> {
  final TextEditingController _topicCtrl = TextEditingController(text: 'Trigonometry & Pythagoras Theorem');
  String _selectedSubject = 'Mathematics';
  String _selectedGrade = 'O-Level (Form 3-4)';
  String _questionType = 'Mixed (MCQ + Short Answer + Structured)';
  String _difficulty = 'Medium';
  int _questionCount = 5;
  bool _isLoading = false;
  String? _generatedOutput;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  void _generate() async {
    if (_topicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an assessment topic.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedOutput = null;
    });

    final service = ref.read(teacherAiServiceProvider);
    try {
      final result = await service.generateQuiz(
        subject: _selectedSubject,
        topic: _topicCtrl.text.trim(),
        gradeLevel: _selectedGrade,
        questionCount: _questionCount,
        questionType: _questionType,
        difficulty: _difficulty,
      );
      if (mounted) {
        setState(() {
          _generatedOutput = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyOutput() {
    if (_generatedOutput == null) return;
    Clipboard.setData(ClipboardData(text: _generatedOutput!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quiz & Marking Scheme copied to clipboard ✓'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz & Exam Bank Authoring',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                Text(
                  'Produces exam questions with mark allocations and complete step-by-step model solutions.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                          DropdownMenuItem(value: 'Physical / Life Science', child: Text('Physical / Life Science')),
                          DropdownMenuItem(value: 'English Language', child: Text('English Language')),
                          DropdownMenuItem(value: 'Geography', child: Text('Geography')),
                          DropdownMenuItem(value: 'History', child: Text('History')),
                        ],
                        onChanged: (v) => setState(() => _selectedSubject = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGrade,
                        decoration: const InputDecoration(labelText: 'Grade Level', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                          DropdownMenuItem(value: 'Form 1', child: Text('Form 1')),
                          DropdownMenuItem(value: 'Form 2', child: Text('Form 2')),
                          DropdownMenuItem(value: 'O-Level (Form 3-4)', child: Text('O-Level (Form 3-4)')),
                          DropdownMenuItem(value: 'A-Level', child: Text('A-Level')),
                        ],
                        onChanged: (v) => setState(() => _selectedGrade = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _topicCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Assessment Topic',
                    hintText: 'e.g. Periodic Table & Chemical Bonding',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _questionType,
                        decoration: const InputDecoration(labelText: 'Question Format', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Multiple Choice (MCQ)', child: Text('Multiple Choice (MCQ)')),
                          DropdownMenuItem(value: 'Short Answer', child: Text('Short Answer')),
                          DropdownMenuItem(value: 'Structured / Essays', child: Text('Structured / Essays')),
                          DropdownMenuItem(value: 'Mixed (MCQ + Short Answer + Structured)', child: Text('Mixed Format')),
                        ],
                        onChanged: (v) => setState(() => _questionType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _questionCount,
                        decoration: const InputDecoration(labelText: 'Question Count', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 3, child: Text('3 Questions (Quick Quiz)')),
                          DropdownMenuItem(value: 5, child: Text('5 Questions (Standard)')),
                          DropdownMenuItem(value: 8, child: Text('8 Questions (Full Test)')),
                        ],
                        onChanged: (v) => setState(() => _questionCount = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty Level', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Foundation', child: Text('Foundation / Remedial')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium / Standard Board')),
                    DropdownMenuItem(value: 'Challenging', child: Text('Challenging / Distinction Hunter')),
                  ],
                  onChanged: (v) => setState(() => _difficulty = v!),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _generate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.quiz_rounded),
                    label: Text(
                      _isLoading ? 'Generating Questions & Keys...' : 'Generate Quiz & Marking Key',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_generatedOutput != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(
              title: 'Assessment & Marking Scheme',
              content: _generatedOutput!,
              onCopy: _copyOutput,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3: REPORT CARD REMARKS GENERATOR
// ─────────────────────────────────────────────────────────────────

class _ReportRemarksTab extends ConsumerStatefulWidget {
  const _ReportRemarksTab();

  @override
  ConsumerState<_ReportRemarksTab> createState() => _ReportRemarksTabState();
}

class _ReportRemarksTabState extends ConsumerState<_ReportRemarksTab> {
  final TextEditingController _studentNameCtrl = TextEditingController(text: 'Tariro Moyo');
  final TextEditingController _focusCtrl = TextEditingController(text: 'Strong in problem solving, needs to review exam timing');
  String _selectedSubject = 'Mathematics';
  String _grade = 'A (82%)';
  final String _trend = 'Consistent High Performer';
  String _effort = 'High & Participative';
  bool _isLoading = false;
  String? _generatedOutput;

  @override
  void dispose() {
    _studentNameCtrl.dispose();
    _focusCtrl.dispose();
    super.dispose();
  }

  void _generate() async {
    if (_studentNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter student name.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedOutput = null;
    });

    final service = ref.read(teacherAiServiceProvider);
    try {
      final result = await service.generateReportRemarks(
        studentName: _studentNameCtrl.text.trim(),
        subject: _selectedSubject,
        grade: _grade,
        performanceTrend: _trend,
        effort: _effort,
        focusAreas: _focusCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _generatedOutput = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyOutput() {
    if (_generatedOutput == null) return;
    Clipboard.setData(ClipboardData(text: _generatedOutput!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Remarks copied to clipboard ✓'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Card Remarks Writer',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                Text(
                  'Drafts 3 distinct styles (Professional, Motivating, Target-Driven) for official school report cards.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _studentNameCtrl,
                        decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                          DropdownMenuItem(value: 'Physical / Life Science', child: Text('Physical / Life Science')),
                          DropdownMenuItem(value: 'English Language', child: Text('English Language')),
                          DropdownMenuItem(value: 'Geography', child: Text('Geography')),
                          DropdownMenuItem(value: 'General Class Performance', child: Text('Overall Homeroom / Class')),
                        ],
                        onChanged: (v) => setState(() => _selectedSubject = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _grade,
                        decoration: const InputDecoration(labelText: 'Grade / Score', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'A* (90–100%)', child: Text('A* (Distinction 90–100%)')),
                          DropdownMenuItem(value: 'A (80–89%)', child: Text('A (Excellent 80–89%)')),
                          DropdownMenuItem(value: 'A (82%)', child: Text('A (82%)')),
                          DropdownMenuItem(value: 'B (70–79%)', child: Text('B (Credit / Good 70–79%)')),
                          DropdownMenuItem(value: 'C (60–69%)', child: Text('C (Pass 60–69%)')),
                          DropdownMenuItem(value: 'D / E (Below 50%)', child: Text('D / E (Requires Support)')),
                        ],
                        onChanged: (v) => setState(() => _grade = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _effort,
                        decoration: const InputDecoration(labelText: 'Effort Level', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Exceptional & Dedicated', child: Text('Exceptional & Dedicated')),
                          DropdownMenuItem(value: 'High & Participative', child: Text('High & Participative')),
                          DropdownMenuItem(value: 'Satisfactory / Steady', child: Text('Satisfactory / Steady')),
                          DropdownMenuItem(value: 'Inconsistent Effort', child: Text('Inconsistent Effort')),
                        ],
                        onChanged: (v) => setState(() => _effort = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _focusCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Observation / Specific Focus',
                    hintText: 'e.g. Excellent homework habits, struggles with algebra questions',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _generate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rate_review_rounded),
                    label: Text(
                      _isLoading ? 'Composing Remarks...' : 'Generate 3 Remark Options',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_generatedOutput != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(
              title: 'Individualized Remarks',
              content: _generatedOutput!,
              onCopy: _copyOutput,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 4: INTERACTIVE PEDAGOGY CHAT
// ─────────────────────────────────────────────────────────────────

class _PedagogyChatTab extends ConsumerStatefulWidget {
  const _PedagogyChatTab();

  @override
  ConsumerState<_PedagogyChatTab> createState() => _PedagogyChatTabState();
}

class _PedagogyChatTabState extends ConsumerState<_PedagogyChatTab> {
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hello! I am your ZivoConnect Teacher AI Assistant. '
          'I am ready to help you with:\n'
          '• **Classroom Strategies**: Managing large classes, mixed abilities, and discipline.\n'
          '• **Syllabus & Curriculum**: Guidance on ZIMSEC & Cambridge requirements.\n'
          '• **Formative Assessment**: Active checking techniques and rubric design.\n\n'
          'What pedagogical challenge or idea are you working on today?'
    },
  ];
  bool _isSending = false;

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _chatCtrl.text).trim();
    if (text.isEmpty) return;

    _chatCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isSending = true;
    });

    _scrollToBottom();

    final service = ref.read(teacherAiServiceProvider);
    try {
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final reply = await service.chat(
        prompt: text,
        history: history,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Error generating response: $e'});
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preset Prompt Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPromptChip('Noisy Classroom Routine'),
                _buildPromptChip('Explain standard deviation simply'),
                _buildPromptChip('4-Level Rubric for History Essay'),
                _buildPromptChip('Form 3 Starter Activity'),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length && _isSending) {
                return _buildTypingIndicator();
              }
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return _buildChatBubble(msg['content']!, isUser);
            },
          ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask Teacher AI Assistant anything...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF4F46E5),
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFFF8FAFC),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        onPressed: () => _sendMessage(text),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SelectableText(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.45,
            color: isUser ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 10),
            Text(
              'Teacher Copilot is thinking...',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED RESULT CARD WIDGET
// ─────────────────────────────────────────────────────────────────

Widget _buildResultCard({
  required String title,
  required String content,
  required VoidCallback onCopy,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFCBD5E1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(12),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy to Clipboard', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            content,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.55,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    ),
  );
}

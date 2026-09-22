import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/teacher_controllers.dart';
import '../../core/grading_engine.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/teacher_ai_floating_button.dart';
import 'teacher_ai_assistant_screen.dart';

class TeacherGradebookScreen extends ConsumerStatefulWidget {
  const TeacherGradebookScreen({super.key});

  @override
  ConsumerState<TeacherGradebookScreen> createState() => _TeacherGradebookScreenState();
}

class _TeacherGradebookScreenState extends ConsumerState<TeacherGradebookScreen> {
  ClassSectionModel? _selectedSection;
  SubjectModel? _selectedSubject;
  GradingTermModel? _selectedTerm;
  CurriculumType _selectedCurriculum = CurriculumType.zimsec;

  AssessmentModel? _selectedAssessment;
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _remarksControllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showCreateAssessmentDialog(String schoolId) {
    if (_selectedSection == null || _selectedSubject == null || _selectedTerm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Section, Subject, and Term first.')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final maxPointsCtrl = TextEditingController(text: '100');
    final categoriesAsync = ref.read(assessmentCategoriesProvider(schoolId));
    DateTime dateAdministered = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedCategoryId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Assessment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assessment Title',
                        hintText: 'e.g. Mid-Term Exam, CALA Component 1, Paper 2 Mock',
                      ),
                    ),
                    const SizedBox(height: 12),
                    categoriesAsync.when(
                      data: (cats) {
                        if (cats.isEmpty) {
                          return const Text('Please create Assessment Categories first.');
                        }
                        selectedCategoryId ??= cats.first.id;
                        return DropdownButtonFormField<String>(
                          initialValue: selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: cats
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxPointsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Max Marks / Points (e.g. 100)'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dateAdministered,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setDialogState(() => dateAdministered = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Date: ${dateAdministered.day}/${dateAdministered.month}/${dateAdministered.year}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || selectedCategoryId == null) return;
                    final maxPts = double.tryParse(maxPointsCtrl.text.trim()) ?? 100.0;
                    final client = ref.read(supabaseClientProvider);
                    final newAss = await AcademicGradebookService(client).createAssessment(
                      schoolId: schoolId,
                      classSectionId: _selectedSection!.id,
                      subjectId: _selectedSubject!.id,
                      termId: _selectedTerm!.id,
                      categoryId: selectedCategoryId!,
                      title: titleCtrl.text.trim(),
                      maxPoints: maxPts,
                      dateAdministered: dateAdministered,
                    );

                    ref.invalidate(
                      assessmentsProvider((
                        schoolId,
                        _selectedSection?.id,
                        _selectedSubject?.id,
                      )),
                    );

                    setState(() {
                      _selectedAssessment = newAss;
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAllGrades(String schoolId, List<StudentEnrollmentModel> enrollments) async {
    if (_selectedAssessment == null) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(teacherRepositoryProvider);
      final maxPts = _selectedAssessment!.maxPoints;

      // First pass: validate all scores are within 0 <= score <= maxPoints
      for (final e in enrollments) {
        final scoreText = _scoreControllers[e.studentProfileId]?.text.trim() ?? '';
        if (scoreText.isNotEmpty) {
          final score = double.tryParse(scoreText);
          if (score == null || score < 0 || score > maxPts) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid score "$scoreText". Score must be between 0 and $maxPts.'),
                backgroundColor: AppTheme.danger,
              ),
            );
            return;
          }
        }
      }

      // Second pass: save or queue via repository
      for (final e in enrollments) {
        final scoreText = _scoreControllers[e.studentProfileId]?.text.trim() ?? '';
        final remarks = _remarksControllers[e.studentProfileId]?.text.trim();
        final score = double.tryParse(scoreText);
        if (score != null) {
          await repo.saveGradeRecord(
            schoolId: schoolId,
            assessmentId: _selectedAssessment!.id,
            studentProfileId: e.studentProfileId,
            score: score,
            maxPoints: maxPts,
            remarks: remarks,
          );
        }
      }

      ref.invalidate(gradeRecordsProvider(_selectedAssessment!.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All grades saved successfully ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving grades: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final sectionsAsync = ref.watch(
      teacherSectionsProvider((schoolId, session.profileId)),
    );
    final subjectsAsync = ref.watch(subjectsProvider(schoolId));
    final termsAsync = ref.watch(gradingTermsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Gradebook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Teacher AI Copilot (Report Remarks & Quiz)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherAiAssistantScreen(initialTabIndex: 2)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CurriculumType>(
                value: _selectedCurriculum,
                items: const [
                  DropdownMenuItem(
                    value: CurriculumType.zimsec,
                    child: Text('🇿🇼 ZIMSEC Board', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: CurriculumType.cambridge,
                    child: Text('🇬🇧 Cambridge IGCSE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCurriculum = v);
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter selector card
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceDark,
            child: Column(
              children: [
                Row(
                  children: [
                    // Section Selector
                    Expanded(
                      child: sectionsAsync.when(
                        data: (sections) {
                          return DropdownButtonFormField<ClassSectionModel>(
                            initialValue: _selectedSection,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Class Section',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: sections
                                .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedSection = v;
                              _selectedAssessment = null;
                            }),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Subject Selector
                    Expanded(
                      child: subjectsAsync.when(
                        data: (subjects) {
                          return DropdownButtonFormField<SubjectModel>(
                            initialValue: _selectedSubject,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: subjects
                                .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedSubject = v;
                              _selectedAssessment = null;
                            }),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Term Selector
                    Expanded(
                      child: termsAsync.when(
                        data: (terms) {
                          return DropdownButtonFormField<GradingTermModel>(
                            initialValue: _selectedTerm,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Grading Term',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: terms
                                .map((t) => DropdownMenuItem(value: t, child: Text(t.name, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedTerm = v;
                              _selectedAssessment = null;
                            }),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Assessment Selector
                    Expanded(
                      child: FutureBuilder<List<AssessmentModel>>(
                        future: AcademicGradebookService(ref.read(supabaseClientProvider))
                            .getAssessments(
                          schoolId,
                          classSectionId: _selectedSection?.id,
                          subjectId: _selectedSubject?.id,
                          termId: _selectedTerm?.id,
                        ),
                        builder: (context, snapshot) {
                          final assessments = snapshot.data ?? [];
                          return DropdownButtonFormField<AssessmentModel>(
                            initialValue: _selectedAssessment,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Assessment',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: assessments
                                .map((a) => DropdownMenuItem(value: a, child: Text(a.title, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedAssessment = v),
                            hint: const Text('Select Assessment'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Grade Entry Spreadsheet Area
          Expanded(
            child: _selectedSection == null
                ? const Center(child: Text('Please select a Class Section above.', style: TextStyle(color: AppTheme.textMuted)))
                : _selectedAssessment == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.grade_rounded, size: 54, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            const Text('No assessment selected.', style: TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateAssessmentDialog(schoolId),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create New Assessment'),
                            ),
                          ],
                        ),
                      )
                    : _buildGradeSpreadsheet(schoolId),
          ),
        ],
      ),
      floatingActionButton: _selectedAssessment != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateAssessmentDialog(schoolId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Assessment'),
            )
          : const TeacherAiFloatingButton(),
    );
  }

  Widget _buildGradeSpreadsheet(String schoolId) {
    final enrollmentsAsync = ref.watch(enrollmentsProvider(schoolId));
    final gradesAsync = ref.watch(gradeRecordsProvider(_selectedAssessment!.id));

    return enrollmentsAsync.when(
      data: (allEnrollments) {
        final enrollments = allEnrollments
            .where((e) => e.classSectionId == _selectedSection!.id)
            .toList();

        if (enrollments.isEmpty) {
          return const Center(child: Text('No students enrolled in this section.'));
        }

        return gradesAsync.when(
          data: (existingGrades) {
            // Populate text controllers
            for (final g in existingGrades) {
              _scoreControllers.putIfAbsent(
                g.studentProfileId,
                () => TextEditingController(text: g.pointsObtained.toString()),
              );
              _remarksControllers.putIfAbsent(
                g.studentProfileId,
                () => TextEditingController(text: g.teacherRemarks ?? ''),
              );
            }
            for (final e in enrollments) {
              _scoreControllers.putIfAbsent(
                e.studentProfileId,
                () => TextEditingController(),
              );
              _remarksControllers.putIfAbsent(
                e.studentProfileId,
                () => TextEditingController(),
              );
            }

            return Column(
              children: [
                // Info header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.cardDark,
                  child: Row(
                    children: [
                      Text(
                        'Max Marks: ${_selectedAssessment!.maxPoints.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Curriculum: ${_selectedCurriculum == CurriculumType.zimsec ? "ZIMSEC (1-9 pts)" : "Cambridge (A*-U)"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _saveAllGrades(schoolId, enrollments),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: _isSaving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save All Grades'),
                      ),
                    ],
                  ),
                ),

                // Spreadsheet table
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: enrollments.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = enrollments[index];
                      final studentId = student.studentProfileId;
                      final studentName = student.student?.fullName ?? 'Student #$index';
                      final scoreCtrl = _scoreControllers[studentId]!;

                      final scoreVal = double.tryParse(scoreCtrl.text.trim()) ?? 0.0;
                      final pct = (_selectedAssessment!.maxPoints > 0)
                          ? (scoreVal / _selectedAssessment!.maxPoints) * 100.0
                          : 0.0;
                      final result = CurriculumGradingEngine.evaluate(pct, _selectedCurriculum);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            // Student Name & Roll
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (student.rollNumber != null)
                                    Text('Roll: ${student.rollNumber}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            // Score Input
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: scoreCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'Marks',
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Grade & Points Translation Tag
                            Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getGradeColor(result.grade).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getGradeColor(result.grade).withAlpha(50)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    result.grade,
                                    style: TextStyle(
                                      color: _getGradeColor(result.grade),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _selectedCurriculum == CurriculumType.zimsec
                                        ? '${result.points} Pt • ${result.description}'
                                        : '${pct.toStringAsFixed(0)}% • ${result.description}',
                                    style: TextStyle(color: _getGradeColor(result.grade), fontSize: 9),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading grades: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading students: $e')),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return AppTheme.success;
    if (grade == 'B') return const Color(0xFF3B82F6);
    if (grade == 'C') return AppTheme.warning;
    if (grade == 'D' || grade == 'E') return const Color(0xFFF97316);
    return AppTheme.danger;
  }
}

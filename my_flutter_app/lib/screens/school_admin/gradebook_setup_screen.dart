import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/teacher_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 26: Gradebook Setup & Weight Configuration
/// Authoritatively drives category weights, assessment weights, total percentage,
/// and `weights_valid` status from `get_gradebook_setup(class_section_id, subject_id, term_id)`.
class GradebookSetupScreen extends ConsumerStatefulWidget {
  const GradebookSetupScreen({super.key});

  @override
  ConsumerState<GradebookSetupScreen> createState() => _GradebookSetupScreenState();
}

class _GradebookSetupScreenState extends ConsumerState<GradebookSetupScreen> {
  ClassSectionModel? _selectedSection;
  SubjectModel? _selectedSubject;
  GradingTermModel? _selectedTerm;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.stitchBg,
        appBar: AppBar(
          title: const Text('Gradebook Setup & Exam Boards', style: TextStyle(color: AppTheme.stitchHeading, fontWeight: FontWeight.w700, fontSize: 16)),
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.tune_rounded), text: 'Weight Matrix'),
              Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Grading Terms'),
              Tab(icon: Icon(Icons.category_rounded), text: 'Assessment Types'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _WeightMatrixTab(
              schoolId: schoolId,
              selectedSection: _selectedSection,
              selectedSubject: _selectedSubject,
              selectedTerm: _selectedTerm,
              onSectionChanged: (s) => setState(() => _selectedSection = s),
              onSubjectChanged: (sub) => setState(() => _selectedSubject = sub),
              onTermChanged: (t) => setState(() => _selectedTerm = t),
            ),
            _TermsTab(schoolId: schoolId),
            _CategoriesTab(schoolId: schoolId),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 1: WEIGHT CONFIGURATION MATRIX (Screen 26 Core)
// ─────────────────────────────────────────────────────────────────

class _WeightMatrixTab extends ConsumerWidget {
  final String schoolId;
  final ClassSectionModel? selectedSection;
  final SubjectModel? selectedSubject;
  final GradingTermModel? selectedTerm;
  final ValueChanged<ClassSectionModel?> onSectionChanged;
  final ValueChanged<SubjectModel?> onSubjectChanged;
  final ValueChanged<GradingTermModel?> onTermChanged;

  const _WeightMatrixTab({
    required this.schoolId,
    required this.selectedSection,
    required this.selectedSubject,
    required this.selectedTerm,
    required this.onSectionChanged,
    required this.onSubjectChanged,
    required this.onTermChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(classSectionsProvider(schoolId));
    final subjectsAsync = ref.watch(subjectsProvider(schoolId));
    final termsAsync = ref.watch(gradingTermsProvider(schoolId));

    final isSelectionComplete = selectedSection != null && selectedSubject != null && selectedTerm != null;

    final setupAsync = isSelectionComplete
        ? ref.watch(teacherGradebookSetupProvider((
            sectionId: selectedSection!.id,
            subjectId: selectedSubject!.id,
            termId: selectedTerm!.id,
          )))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter card
          StitchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StitchSectionHeader(
                  title: 'Select Academic Scope',
                  subtitle: 'Configure assessment category weights for a specific class, subject, and term',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Section Selector
                    Expanded(
                      child: sectionsAsync.when(
                        data: (sections) => DropdownButtonFormField<ClassSectionModel>(
                          initialValue: selectedSection,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Class Section',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: sections
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: onSectionChanged,
                          hint: const Text('Select Section'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Subject Selector
                    Expanded(
                      child: subjectsAsync.when(
                        data: (subjects) => DropdownButtonFormField<SubjectModel>(
                          initialValue: selectedSubject,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: subjects
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: onSubjectChanged,
                          hint: const Text('Select Subject'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Term Selector
                    Expanded(
                      child: termsAsync.when(
                        data: (terms) => DropdownButtonFormField<GradingTermModel>(
                          initialValue: selectedTerm,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Grading Term',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: terms
                              .map((t) => DropdownMenuItem(value: t, child: Text(t.name, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: onTermChanged,
                          hint: const Text('Select Term'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Setup Details
          if (!isSelectionComplete)
            const StitchCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.tune_rounded, size: 48, color: AppTheme.stitchMuted),
                      SizedBox(height: 12),
                      Text('Please select Section, Subject, and Term above to inspect gradebook weights.',
                          style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          else
            setupAsync!.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (e, _) => StitchCard(child: Text('Error loading gradebook setup: $e')),
              data: (setup) {
                final categories = (setup['categories'] as List<dynamic>?) ?? [];
                final totalPercentage = (setup['total_percentage'] as num?)?.toDouble() ?? 0.0;
                final weightsValid = setup['weights_valid'] as bool? ?? (totalPercentage >= 99.9 && totalPercentage <= 100.1);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Weight Validity Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: weightsValid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        border: Border.all(
                          color: weightsValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            weightsValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            color: weightsValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  weightsValid
                                      ? 'VALID WEIGHT CONFIGURATION (Total: ${totalPercentage.toStringAsFixed(1)}%)'
                                      : 'INVALID WEIGHT CONFIGURATION (Total: ${totalPercentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: weightsValid ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  weightsValid
                                      ? 'Assessment categories properly reconcile to 100%. Grades calculated in this scope will be authoritative.'
                                      : 'The category weights sum to ${totalPercentage.toStringAsFixed(1)}%, not 100.0%. Please adjust category weights before finalizing term reports.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: weightsValid ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Categories Weight Matrix Table
                    StitchCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StitchSectionHeader(
                            title: 'Category Weight Allocation',
                            subtitle: '${categories.length} assessment categories configured for this scope',
                            trailing: TextButton.icon(
                              onPressed: () {
                                ref.invalidate(teacherGradebookSetupProvider((
                                  sectionId: selectedSection!.id,
                                  subjectId: selectedSubject!.id,
                                  termId: selectedTerm!.id,
                                )));
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Sync Setup'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (categories.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No categories linked to this gradebook configuration.',
                                    style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
                              ),
                            )
                          else
                            DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 48,
                              columns: const [
                                DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                DataColumn(label: Text('WEIGHT FACTOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                DataColumn(label: Text('PERCENTAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                DataColumn(label: Text('ASSESSMENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                              rows: categories.map((c) {
                                final map = Map<String, dynamic>.from(c as Map);
                                final weightFactor = (map['weight'] as num?)?.toDouble() ?? 1.0;
                                final pct = (map['percentage'] as num?)?.toDouble() ?? (weightFactor * 100.0);
                                final count = (map['assessment_count'] as num?)?.toInt() ?? 0;

                                return DataRow(cells: [
                                  DataCell(Text(map['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  DataCell(Text(weightFactor.toStringAsFixed(2))),
                                  DataCell(StitchChip(label: '${pct.toStringAsFixed(1)}%', variant: StitchChipVariant.primary)),
                                  DataCell(Text('$count items')),
                                ]);
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2: GRADING TERMS
// ─────────────────────────────────────────────────────────────────

class _TermsTab extends ConsumerWidget {
  final String schoolId;
  const _TermsTab({required this.schoolId});

  void _showAddTermDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: 'Term 1');
    final weightCtrl = TextEditingController(text: '1.0');
    final yearsAsync = ref.read(academicYearsProvider(schoolId));

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedYearId;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Grading Term'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  yearsAsync.when(
                    data: (years) {
                      if (years.isEmpty) return const Text('Please create an Academic Year first');
                      selectedYearId ??= years.first.id;
                      return DropdownButtonFormField<String>(
                        initialValue: selectedYearId,
                        decoration: const InputDecoration(labelText: 'Academic Year'),
                        items: years
                            .map((y) => DropdownMenuItem(value: y.id, child: Text(y.name)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedYearId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading years: $e'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Term Name (e.g. Term 1, Mid-Year)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (e.g. 1.0 or 0.33)'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedYearId == null || nameCtrl.text.trim().isEmpty) return;
                    final weight = double.tryParse(weightCtrl.text.trim()) ?? 1.0;
                    final client = ref.read(supabaseClientProvider);
                    await AcademicGradebookService(client).createGradingTerm(
                      schoolId: schoolId,
                      academicYearId: selectedYearId!,
                      name: nameCtrl.text.trim(),
                      weight: weight,
                    );
                    ref.invalidate(gradingTermsProvider(schoolId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Save Term', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(gradingTermsProvider(schoolId));

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      body: termsAsync.when(
        data: (terms) {
          if (terms.isEmpty) {
            return const Center(
              child: Text(
                'No grading terms configured yet.\nTap + to add terms like Term 1, Term 2, Term 3.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.stitchMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: terms.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final term = terms[i];
              return StitchCard(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.date_range_rounded, color: AppTheme.primaryDark),
                  ),
                  title: Text(term.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Weight Factor: ${term.weight}', style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12)),
                  trailing: const StitchChip(label: 'Active Term', variant: StitchChipVariant.success),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTermDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Term'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3: ASSESSMENT CATEGORIES
// ─────────────────────────────────────────────────────────────────

class _CategoriesTab extends ConsumerWidget {
  final String schoolId;
  const _CategoriesTab({required this.schoolId});

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Assessment Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. ZIMSEC CALA, Exam, Mock, Coursework',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Default Weight (e.g. 0.3 for 30%)',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.stitchBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Curriculum suggestions:\n• ZIMSEC: CALA / Continuous (30%), Final Exam (70%)\n• Cambridge: Formative Coursework (30%), Written Papers (70%)',
                  style: TextStyle(color: AppTheme.stitchMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final weight = double.tryParse(weightCtrl.text.trim()) ?? 1.0;
                final client = ref.read(supabaseClientProvider);
                await AcademicGradebookService(client).createAssessmentCategory(
                  schoolId: schoolId,
                  name: nameCtrl.text.trim(),
                  weight: weight,
                );
                ref.invalidate(assessmentCategoriesProvider(schoolId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Save Category', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(assessmentCategoriesProvider(schoolId));

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No assessment categories configured yet.\nTap + to add categories (e.g. Exams, Homework, CALA, Mocks).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.stitchMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final cat = categories[i];
              return StitchCard(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryDark),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Weight Factor: ${cat.weight}', style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12)),
                  trailing: const StitchChip(label: 'Category', variant: StitchChipVariant.primary),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
    );
  }
}

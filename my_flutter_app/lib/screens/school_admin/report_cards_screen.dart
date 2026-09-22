import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/grading_engine.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class ReportCardsScreen extends ConsumerStatefulWidget {
  const ReportCardsScreen({super.key});

  @override
  ConsumerState<ReportCardsScreen> createState() => _ReportCardsScreenState();
}

class _ReportCardsScreenState extends ConsumerState<ReportCardsScreen> {
  GradingTermModel? _selectedTerm;
  CurriculumType _curriculum = CurriculumType.zimsec;

  void _showReportCardDetail(BuildContext context, ReportCardModel reportCard) {
    final client = ref.read(supabaseClientProvider);
    final service = AcademicGradebookService(client);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      builder: (ctx) {
        return FutureBuilder<List<GradeRecordModel>>(
          future: service.getStudentGrades(reportCard.studentProfileId),
          builder: (context, snapshot) {
            final grades = snapshot.data ?? [];
            final studentName = reportCard.student?.fullName ?? 'Student';
            final yearName = reportCard.academicYear?.name ?? '';
            final termName = reportCard.term?.name ?? '';

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card with Watermark & Curriculum Badge
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(studentName, style: Theme.of(context).textTheme.titleLarge),
                                    Text('$yearName • $termName', style: const TextStyle(color: AppTheme.textMuted)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_curriculum == CurriculumType.zimsec ? AppTheme.primary : AppTheme.secondary).withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _curriculum == CurriculumType.zimsec ? '🇿🇼 ZIMSEC O-Level' : '🇬🇧 Cambridge IGCSE',
                                    style: TextStyle(
                                      color: _curriculum == CurriculumType.zimsec ? AppTheme.primary : AppTheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatTile(
                                  label: 'Overall Status',
                                  value: reportCard.principalApproved ? 'Approved ✓' : 'Pending Review',
                                  color: reportCard.principalApproved ? AppTheme.success : AppTheme.warning,
                                ),
                                _StatTile(
                                  label: 'Subjects Recorded',
                                  value: '${grades.length}',
                                  color: AppTheme.primaryLight,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Subject Breakdown', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),

                      // Grades list
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : grades.isEmpty
                                ? const Center(child: Text('No grades entered for this student.'))
                                : ListView.separated(
                                    controller: scrollCtrl,
                                    itemCount: grades.length,
                                    separatorBuilder: (_, i) => const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final g = grades[i];
                                      final subj = g.assessment?.subject?.name ?? 'Subject';
                                      final assName = g.assessment?.title ?? 'Assessment';
                                      final maxPts = g.assessment?.maxPoints ?? 100.0;
                                      final pct = (maxPts > 0) ? (g.pointsObtained / maxPts) * 100.0 : 0.0;
                                      final result = CurriculumGradingEngine.evaluate(pct, _curriculum);

                                      return ListTile(
                                        title: Text(subj, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('$assName (${g.pointsObtained.toStringAsFixed(0)} / ${maxPts.toStringAsFixed(0)})'),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _curriculum == CurriculumType.zimsec
                                                ? 'Grade ${result.grade} (${result.points} Pt)'
                                                : '${result.grade} (${pct.toStringAsFixed(0)}%)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),

                      // Approve / Reject Toggle
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await service.setReportCardApproval(
                            reportCard.id,
                            !reportCard.principalApproved,
                          );
                          ref.invalidate(reportCardsProvider((reportCard.schoolId, _selectedTerm?.id)));
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: Icon(reportCard.principalApproved ? Icons.lock_open_rounded : Icons.verified_rounded),
                        label: Text(reportCard.principalApproved ? 'Revoke Approval' : 'Principal Approve Report Card'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reportCard.principalApproved ? AppTheme.warning : AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _generateAllReportCards(String schoolId, List<StudentEnrollmentModel> enrollments) async {
    if (_selectedTerm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Grading Term first.')),
      );
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final service = AcademicGradebookService(client);

    for (final e in enrollments) {
      await service.generateReportCard(
        schoolId: schoolId,
        studentProfileId: e.studentProfileId,
        academicYearId: e.academicYearId,
        termId: _selectedTerm!.id,
      );
    }

    ref.invalidate(reportCardsProvider((schoolId, _selectedTerm?.id)));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report cards compiled for all enrolled students ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final termsAsync = ref.watch(gradingTermsProvider(schoolId));
    final enrollmentsAsync = ref.watch(enrollmentsProvider(schoolId));
    final reportCardsAsync = ref.watch(reportCardsProvider((schoolId, _selectedTerm?.id)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Report Cards'),
        actions: [
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
                value: _curriculum,
                items: const [
                  DropdownMenuItem(value: CurriculumType.zimsec, child: Text('🇿🇼 ZIMSEC Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: CurriculumType.cambridge, child: Text('🇬🇧 Cambridge Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _curriculum = v);
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceDark,
            child: Row(
              children: [
                Expanded(
                  child: termsAsync.when(
                    data: (terms) {
                      if (terms.isNotEmpty && _selectedTerm == null) {
                        _selectedTerm = terms.first;
                      }
                      return DropdownButtonFormField<GradingTermModel>(
                        initialValue: _selectedTerm,
                        decoration: const InputDecoration(labelText: 'Grading Term', border: OutlineInputBorder()),
                        items: terms
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTerm = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
                const SizedBox(width: 12),
                enrollmentsAsync.when(
                  data: (enrollments) => ElevatedButton.icon(
                    onPressed: () => _generateAllReportCards(schoolId, enrollments),
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('Compile All'),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, err) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Report Cards List
          Expanded(
            child: reportCardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_rounded, size: 54, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text('No report cards compiled for this term yet.', style: TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 12),
                        enrollmentsAsync.when(
                          data: (enrollments) => ElevatedButton(
                            onPressed: () => _generateAllReportCards(schoolId, enrollments),
                            child: const Text('Compile Term Report Cards'),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, err) => const SizedBox(),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final card = cards[i];
                    final studentName = card.student?.fullName ?? 'Student #${i + 1}';
                    final isApproved = card.principalApproved;

                    return Card(
                      child: ListTile(
                        onTap: () => _showReportCardDetail(context, card),
                        leading: CircleAvatar(
                          backgroundColor: (isApproved ? AppTheme.success : AppTheme.warning).withAlpha(25),
                          child: Icon(
                            isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                            color: isApproved ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isApproved ? 'Approved by Principal ✓' : 'Draft / Pending Review',
                          style: TextStyle(color: isApproved ? AppTheme.success : AppTheme.warning, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading report cards: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}

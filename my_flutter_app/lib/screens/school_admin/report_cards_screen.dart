import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/report_cards_controllers.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 27 — Report Cards.
///
/// All academic calculations and lifecycle changes come from PostgreSQL RPCs.
/// Flutter does not recalculate subject grades or infer curriculum thresholds.
class ReportCardsScreen extends ConsumerStatefulWidget {
  const ReportCardsScreen({super.key});

  @override
  ConsumerState<ReportCardsScreen> createState() =>
      _ReportCardsScreenState();
}

class _ReportCardsScreenState extends ConsumerState<ReportCardsScreen> {
  String? _selectedYearId;
  String? _selectedTermId;
  String? _selectedSectionId;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final yearsAsync = ref.watch(academicYearsProvider(session.schoolId));
    final termsAsync = ref.watch(gradingTermsProvider(session.schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(session.schoolId));
    final canManage = session.role == AppRoles.schoolAdmin ||
        session.role == AppRoles.superAdmin;

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
              'ACADEMICS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Report Cards',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load academic years: $error',
          onRetry: () => ref.invalidate(academicYearsProvider(session.schoolId)),
        ),
        data: (years) => termsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: 'Unable to load grading terms: $error',
            onRetry: () => ref.invalidate(gradingTermsProvider(session.schoolId)),
          ),
          data: (allTerms) => sectionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: 'Unable to load class sections: $error',
              onRetry: () =>
                  ref.invalidate(classSectionsProvider(session.schoolId)),
            ),
            data: (allSections) {
              if (years.isEmpty) {
                return const _EmptyState(
                  message: 'Create an academic year before using report cards.',
                );
              }

              final yearId = _resolveYearId(years);
              final terms = allTerms
                  .where((term) => term.academicYearId == yearId)
                  .toList(growable: false);
              final sections = allSections
                  .where(
                    (section) => section.classModel == null ||
                        section.classModel!.academicYearId == yearId,
                  )
                  .toList(growable: false);

              if (terms.isEmpty || sections.isEmpty) {
                return _ReportCardSetupMissing(
                  hasTerms: terms.isNotEmpty,
                  hasSections: sections.isNotEmpty,
                );
              }

              final termId = _resolveTermId(terms);
              final sectionId = _resolveSectionId(sections);
              final args = (
                academicYearId: yearId,
                termId: termId,
                classSectionId: sectionId,
              );
              final overviewAsync = ref.watch(reportCardsOverviewProvider(args));

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _FiltersCard(
                      years: years,
                      terms: terms,
                      sections: sections,
                      yearId: yearId,
                      termId: termId,
                      sectionId: sectionId,
                      processing: _processing,
                      onYearChanged: (value) {
                        setState(() {
                          _selectedYearId = value;
                          _selectedTermId = null;
                          _selectedSectionId = null;
                        });
                      },
                      onTermChanged: (value) =>
                          setState(() => _selectedTermId = value),
                      onSectionChanged: (value) =>
                          setState(() => _selectedSectionId = value),
                    ),
                  ),
                  Expanded(
                    child: overviewAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _ErrorState(
                        message: 'Unable to load report cards: $error',
                        onRetry: () =>
                            ref.invalidate(reportCardsOverviewProvider(args)),
                      ),
                      data: (overview) {
                        final rows = _mapList(overview['students']);
                        final counts = _asMap(overview['counts']);

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: _CountsRow(counts: counts),
                            ),
                            if (canManage)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: _ManagementActions(
                                  processing: _processing,
                                  notGenerated:
                                      (counts['not_generated'] as num?)?.toInt() ??
                                          0,
                                  approved:
                                      (counts['approved'] as num?)?.toInt() ?? 0,
                                  onGenerateMissing: () => _generateMissing(
                                    args: args,
                                    rows: rows,
                                  ),
                                  onBulkPublish: () => _bulkPublish(args),
                                ),
                              ),
                            Expanded(
                              child: rows.isEmpty
                                  ? const _EmptyState(
                                      message:
                                          'No active students are enrolled in this class section.',
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        ref.invalidate(
                                          reportCardsOverviewProvider(args),
                                        );
                                        await ref.read(
                                          reportCardsOverviewProvider(args).future,
                                        );
                                      },
                                      child: ListView.separated(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          24,
                                        ),
                                        itemCount: rows.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final row = rows[index];
                                          return _ReportCardRow(
                                            row: row,
                                            canManage: canManage,
                                            processing: _processing,
                                            onGenerate: () => _generateOne(
                                              args: args,
                                              row: row,
                                            ),
                                            onSetStatus: (status) =>
                                                _setStatus(
                                              args: args,
                                              row: row,
                                              status: status,
                                            ),
                                            onView: () =>
                                                _showDetails(context, row),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _resolveYearId(List<AcademicYearModel> years) {
    final selected = _selectedYearId;
    if (selected != null && years.any((year) => year.id == selected)) {
      return selected;
    }
    for (final year in years) {
      if (year.isCurrent) return year.id;
    }
    return years.first.id;
  }

  String _resolveTermId(List<GradingTermModel> terms) {
    final selected = _selectedTermId;
    if (selected != null && terms.any((term) => term.id == selected)) {
      return selected;
    }
    return terms.first.id;
  }

  String _resolveSectionId(List<ClassSectionModel> sections) {
    final selected = _selectedSectionId;
    if (selected != null && sections.any((section) => section.id == selected)) {
      return selected;
    }
    return sections.first.id;
  }

  Future<void> _generateOne({
    required ({String academicYearId, String termId, String classSectionId}) args,
    required Map<String, dynamic> row,
  }) async {
    final studentId = row['profile_id']?.toString() ?? '';
    if (studentId.isEmpty || _processing) return;

    await _runMutation(
      args,
      () => ref.read(reportCardsRepositoryProvider).generateStudent(
            studentProfileId: studentId,
            termId: args.termId,
          ),
      successMessage: 'Report card generated from server-calculated results.',
    );
  }

  Future<void> _generateMissing({
    required ({String academicYearId, String termId, String classSectionId}) args,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (_processing) return;
    final missing = rows
        .where((row) => row['report_card_id'] == null)
        .map((row) => row['profile_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (missing.isEmpty) return;

    setState(() => _processing = true);
    var generated = 0;
    try {
      for (final studentId in missing) {
        await ref.read(reportCardsRepositoryProvider).generateStudent(
              studentProfileId: studentId,
              termId: args.termId,
            );
        generated++;
      }
      ref.invalidate(reportCardsOverviewProvider(args));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $generated report card(s).')),
        );
      }
    } catch (error) {
      ref.invalidate(reportCardsOverviewProvider(args));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated $generated before the server stopped the operation: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _setStatus({
    required ({String academicYearId, String termId, String classSectionId}) args,
    required Map<String, dynamic> row,
    required String status,
  }) async {
    final reportCardId = row['report_card_id']?.toString() ?? '';
    if (reportCardId.isEmpty || _processing) return;

    await _runMutation(
      args,
      () => ref.read(reportCardsRepositoryProvider).setStatus(
            reportCardId: reportCardId,
            status: status,
          ),
      successMessage: 'Report card status updated.',
    );
  }

  Future<void> _bulkPublish(
    ({String academicYearId, String termId, String classSectionId}) args,
  ) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final count = await ref.read(reportCardsRepositoryProvider).bulkPublish(
            academicYearId: args.academicYearId,
            termId: args.termId,
            classSectionId: args.classSectionId,
          );
      ref.invalidate(reportCardsOverviewProvider(args));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Published $count approved report card(s).')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk publish failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _runMutation(
    ({String academicYearId, String termId, String classSectionId}) args,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _processing = true);
    try {
      await action();
      ref.invalidate(reportCardsOverviewProvider(args));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showDetails(BuildContext context, Map<String, dynamic> row) {
    final summary = _asMap(row['summary']);
    final subjects = _mapList(summary['subjects']);
    final attendance = _asMap(summary['attendance']);
    final curriculum = summary['curriculum']?.toString() ?? '—';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              row['student_name']?.toString() ?? 'Student',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Curriculum: $curriculum',
              style: const TextStyle(color: AppTheme.stitchMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailMetric(
                  label: 'Average',
                  value: _percentage(
                    row['average_percentage'] ?? summary['final_average'],
                  ),
                ),
                _DetailMetric(
                  label: 'Grade',
                  value: row['overall_grade']?.toString() ??
                      summary['overall_grade']?.toString() ??
                      '—',
                ),
                _DetailMetric(
                  label: 'Attendance',
                  value: _percentage(
                    row['attendance_rate'] ?? attendance['attendance_rate'],
                  ),
                ),
                _DetailMetric(
                  label: 'Missing Scores',
                  value: '${summary['missing_scores'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            if ((row['teacher_comments']?.toString().trim() ?? '').isNotEmpty)
              StitchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teacher Comments',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(row['teacher_comments'].toString()),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            const StitchSectionHeader(
              title: 'Subject Results',
              subtitle: 'Calculated by the authoritative term-report engine',
            ),
            const SizedBox(height: 10),
            if (subjects.isEmpty)
              const Text(
                'No subject results are available in this report card.',
                style: TextStyle(color: AppTheme.stitchMuted),
              )
            else
              ...subjects.map(
                (subject) => Card(
                  child: ListTile(
                    title: Text(
                      subject['subject']?.toString() ?? 'Subject',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Assessments: ${subject['assessment_count'] ?? 0} • Missing: ${subject['missing_scores'] ?? 0} • Weights: ${subject['weights_total_percent'] ?? 0}%',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          subject['grade']?.toString() ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          _percentage(
                            subject['final_average'] ??
                                subject['running_average'],
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.stitchMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _percentage(dynamic value) {
    final number = (value as num?)?.toDouble();
    return number == null ? '—' : '${number.toStringAsFixed(1)}%';
  }
}

class _FiltersCard extends StatelessWidget {
  final List<AcademicYearModel> years;
  final List<GradingTermModel> terms;
  final List<ClassSectionModel> sections;
  final String yearId;
  final String termId;
  final String sectionId;
  final bool processing;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onTermChanged;
  final ValueChanged<String> onSectionChanged;

  const _FiltersCard({
    required this.years,
    required this.terms,
    required this.sections,
    required this.yearId,
    required this.termId,
    required this.sectionId,
    required this.processing,
    required this.onYearChanged,
    required this.onTermChanged,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            DropdownButtonFormField<String>(
              initialValue: yearId,
              decoration: const InputDecoration(labelText: 'Academic Year'),
              items: years
                  .map(
                    (year) => DropdownMenuItem(
                      value: year.id,
                      child: Text(year.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  processing ? null : (value) => value == null ? null : onYearChanged(value),
            ),
            DropdownButtonFormField<String>(
              initialValue: termId,
              decoration: const InputDecoration(labelText: 'Grading Term'),
              items: terms
                  .map(
                    (term) => DropdownMenuItem(
                      value: term.id,
                      child: Text(term.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  processing ? null : (value) => value == null ? null : onTermChanged(value),
            ),
            DropdownButtonFormField<String>(
              initialValue: sectionId,
              decoration: const InputDecoration(labelText: 'Class Section'),
              items: sections
                  .map(
                    (section) => DropdownMenuItem(
                      value: section.id,
                      child: Text(section.displayName),
                    ),
                  )
                  .toList(),
              onChanged: processing
                  ? null
                  : (value) => value == null ? null : onSectionChanged(value),
            ),
          ];

          if (constraints.maxWidth < 800) {
            return Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: field,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: 10),
              Expanded(child: fields[1]),
              const SizedBox(width: 10),
              Expanded(child: fields[2]),
            ],
          );
        },
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  final Map<String, dynamic> counts;
  const _CountsRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _countChip('Students', counts['students'], StitchChipVariant.neutral),
          _countChip(
            'Not Generated',
            counts['not_generated'],
            StitchChipVariant.warn,
          ),
          _countChip('Draft', counts['draft'], StitchChipVariant.neutral),
          _countChip(
            'Pending',
            counts['pending_approval'],
            StitchChipVariant.warn,
          ),
          _countChip('Approved', counts['approved'], StitchChipVariant.success),
          _countChip('Published', counts['published'], StitchChipVariant.success),
        ],
      ),
    );
  }

  Widget _countChip(String label, dynamic value, StitchChipVariant variant) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: StitchChip(
        label: '$label: ${value ?? 0}',
        variant: variant,
      ),
    );
  }
}

class _ManagementActions extends StatelessWidget {
  final bool processing;
  final int notGenerated;
  final int approved;
  final VoidCallback onGenerateMissing;
  final VoidCallback onBulkPublish;

  const _ManagementActions({
    required this.processing,
    required this.notGenerated,
    required this.approved,
    required this.onGenerateMissing,
    required this.onBulkPublish,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (notGenerated > 0)
          OutlinedButton.icon(
            onPressed: processing ? null : onGenerateMissing,
            icon: const Icon(Icons.calculate_outlined, size: 17),
            label: Text('Generate Missing ($notGenerated)'),
          ),
        if (notGenerated > 0 && approved > 0) const SizedBox(width: 8),
        if (approved > 0)
          FilledButton.icon(
            onPressed: processing ? null : onBulkPublish,
            icon: const Icon(Icons.publish_rounded, size: 17),
            label: Text('Publish Approved ($approved)'),
          ),
      ],
    );
  }
}

class _ReportCardRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool canManage;
  final bool processing;
  final VoidCallback onGenerate;
  final ValueChanged<String> onSetStatus;
  final VoidCallback onView;

  const _ReportCardRow({
    required this.row,
    required this.canManage,
    required this.processing,
    required this.onGenerate,
    required this.onSetStatus,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final reportCardId = row['report_card_id']?.toString();
    final status = row['status']?.toString() ?? 'not_generated';
    final average = (row['average_percentage'] as num?)?.toDouble();
    final grade = row['overall_grade']?.toString();

    return StitchCard(
      onTap: reportCardId == null ? null : onView,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: status == 'published' || status == 'approved'
                ? const Color(0xFFECFDF5)
                : AppTheme.primarySoft,
            child: Icon(
              reportCardId == null
                  ? Icons.description_outlined
                  : Icons.assignment_turned_in_rounded,
              color: status == 'published' || status == 'approved'
                  ? AppTheme.success
                  : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['student_name']?.toString() ?? 'Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.stitchHeading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if ((row['admission_number']?.toString() ?? '').isNotEmpty)
                      row['admission_number'],
                    if (average != null) 'Average ${average.toStringAsFixed(1)}%',
                    if (grade != null && grade.isNotEmpty) 'Grade $grade',
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StitchChip(
            label: status.replaceAll('_', ' '),
            variant: _statusVariant(status),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            _actionForStatus(status),
          ],
        ],
      ),
    );
  }

  Widget _actionForStatus(String status) {
    if (status == 'not_generated') {
      return FilledButton.tonal(
        onPressed: processing ? null : onGenerate,
        child: const Text('Generate'),
      );
    }
    if (status == 'draft') {
      return FilledButton.tonal(
        onPressed: processing ? null : () => onSetStatus('pending_approval'),
        child: const Text('Submit'),
      );
    }
    if (status == 'pending_approval') {
      return FilledButton.tonal(
        onPressed: processing ? null : () => onSetStatus('approved'),
        child: const Text('Approve'),
      );
    }
    if (status == 'approved') {
      return FilledButton.tonal(
        onPressed: processing ? null : () => onSetStatus('published'),
        child: const Text('Publish'),
      );
    }
    return TextButton(onPressed: onView, child: const Text('View'));
  }

  static StitchChipVariant _statusVariant(String status) {
    switch (status) {
      case 'approved':
      case 'published':
        return StitchChipVariant.success;
      case 'pending_approval':
        return StitchChipVariant.warn;
      default:
        return StitchChipVariant.neutral;
    }
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.stitchBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stitchBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.stitchHeading,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.stitchMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCardSetupMissing extends StatelessWidget {
  final bool hasTerms;
  final bool hasSections;

  const _ReportCardSetupMissing({
    required this.hasTerms,
    required this.hasSections,
  });

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (!hasTerms) 'grading term',
      if (!hasSections) 'class section',
    ].join(' and ');
    return _EmptyState(
      message: 'A $missing must be configured before report cards can be reviewed.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 52,
              color: AppTheme.stitchMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.stitchMuted),
            ),
          ],
        ),
      ),
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
            const Icon(Icons.error_outline_rounded, size: 44),
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

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

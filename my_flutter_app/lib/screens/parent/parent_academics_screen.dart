import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 07: Parent Academics & Student 360 View
/// Uses the authoritative `get_parent_academics` RPC with zero mock fixtures.
class ParentAcademicsScreen extends ConsumerWidget {
  const ParentAcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentChildrenProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        title: const Text(
          'Academics & Progress',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.stitchHeading,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.stitchHeading),
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading student: $err')),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No linked student profiles found.',
                  style: TextStyle(color: AppTheme.stitchMuted),
                ),
              ),
            );
          }

          final child = activeChild ?? children.first;
          final academicsAsync = ref.watch(parentAcademicsProvider(child.studentId));

          return academicsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading academics: $e')),
            data: (academics) => _buildContent(context, child, academics),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthorizedChild child,
    Map<String, dynamic> academics,
  ) {
    final bestSubject = _map(academics['best_subject']);
    final reportCard = _map(academics['latest_report_card']);
    final subjects = _listOfMaps(academics['subjects']);
    final recentAssessments = _listOfMaps(academics['recent_assessments']);

    final currentAverage = (academics['current_average'] as num?)?.toDouble();
    final assessmentsCount =
        (academics['assessment_count'] as num?)?.toInt() ?? recentAssessments.length;
    final assessmentsThisMonth =
        (academics['assessments_added_this_month'] as num?)?.toInt() ?? 0;
    final reportCardsCount =
        (academics['report_card_count'] as num?)?.toInt() ?? 0;
    final bestSubjectName = bestSubject['subject']?.toString();
    final bestSubjectAverage = (bestSubject['average'] as num?)?.toDouble();

    final enrollmentLabel = child.className.trim();
    final subtitle = enrollmentLabel.isNotEmpty && enrollmentLabel != 'Enrolled Class'
        ? 'Enrolled in $enrollmentLabel · Real-time academic standing and progress'
        : 'Real-time academic standing and progress';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARENT WORKSPACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${child.fullName}'s Academics",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchHeading,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              return GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.6 : 1.4,
                children: [
                  StitchKpiCard(
                    label: 'Current Average',
                    value: currentAverage == null
                        ? '—'
                        : '${currentAverage.toStringAsFixed(1)}%',
                    hint: 'Current approved/published term',
                  ),
                  StitchKpiCard(
                    label: 'Best Subject',
                    value: bestSubjectName?.isNotEmpty == true
                        ? bestSubjectName!
                        : '—',
                    hint: bestSubjectAverage == null
                        ? 'No subject average available'
                        : '${bestSubjectAverage.toStringAsFixed(1)}% average',
                    statusColor: bestSubjectName?.isNotEmpty == true
                        ? StitchChipVariant.success
                        : StitchChipVariant.neutral,
                  ),
                  StitchKpiCard(
                    label: 'Assessments',
                    value: '$assessmentsCount',
                    hint: '$assessmentsThisMonth added this month',
                  ),
                  StitchKpiCard(
                    label: 'Report Cards',
                    value: '$reportCardsCount',
                    hint: 'Official published cards',
                    statusColor: StitchChipVariant.info,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildSubjectPerformanceCard(subjects),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: _buildLatestReportCardSummary(reportCard),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildSubjectPerformanceCard(subjects),
                  const SizedBox(height: 16),
                  _buildLatestReportCardSummary(reportCard),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildRecentAssessmentsCard(recentAssessments),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceCard(List<Map<String, dynamic>> subjects) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Subject Performance',
            subtitle: 'Enrolled subjects and cumulative standing',
          ),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No subject grades published yet.',
                  style: TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 46,
                horizontalMargin: 8,
                columnSpacing: 24,
                columns: const [
                  DataColumn(
                    label: Text(
                      'SUBJECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TEACHER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'AVERAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TREND',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                  ),
                ],
                rows: subjects.map((subject) {
                  final score = (subject['average'] as num?)?.toDouble();
                  final trend = (subject['trend'] as num?)?.toDouble();
                  final trendLabel = trend == null
                      ? '—'
                      : '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)} pts';
                  final trendVariant = trend == null
                      ? StitchChipVariant.neutral
                      : trend >= 0
                          ? StitchChipVariant.success
                          : StitchChipVariant.warn;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          subject['subject']?.toString() ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          subject['teacher']?.toString().trim().isNotEmpty == true
                              ? subject['teacher'].toString()
                              : '—',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          score == null ? '—' : '${score.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        StitchChip(
                          label: trendLabel,
                          variant: trendVariant,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestReportCardSummary(Map<String, dynamic> reportCard) {
    if (reportCard.isEmpty) {
      return const StitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StitchSectionHeader(
              title: 'Latest Report Card',
              trailing: StitchChip(
                label: 'Pending',
                variant: StitchChipVariant.neutral,
              ),
            ),
            SizedBox(height: 24),
            Center(
              child: Text(
                'No approved or published report card for this term.',
                style: TextStyle(
                  color: AppTheme.stitchMuted,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      );
    }

    final average = (reportCard['average_percentage'] as num?)?.toDouble();
    final grade = reportCard['overall_grade']?.toString() ?? '—';
    final attendance = (reportCard['attendance_rate'] as num?)?.toDouble();
    final comment = reportCard['teacher_comments']?.toString().trim();
    final status = reportCard['status']?.toString() ?? 'Report';

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: 'Latest Report Card',
            trailing: StitchChip(
              label: status,
              variant: status == 'published'
                  ? StitchChipVariant.success
                  : StitchChipVariant.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    average == null ? '—' : '${average.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.stitchHeading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AVERAGE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.stitchMuted,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: const Color(0xFFEEF2F6)),
              Column(
                children: [
                  Text(
                    grade,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'OVERALL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.stitchMuted,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: const Color(0xFFEEF2F6)),
              Column(
                children: [
                  Text(
                    attendance == null
                        ? '—'
                        : '${attendance.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.stitchSuccessText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'ATTENDANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.stitchMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCD6FF)),
              ),
              child: Text(
                'Teacher comment: $comment',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4C3ADB),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentAssessmentsCard(
    List<Map<String, dynamic>> recentAssessments,
  ) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Recent Assessments',
            subtitle: 'Latest graded quizzes, practicals, and coursework',
          ),
          const SizedBox(height: 12),
          if (recentAssessments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No assessment grades recorded for this term.',
                  style: TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 46,
                horizontalMargin: 8,
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('ASSESSMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('FEEDBACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                ],
                rows: recentAssessments.map((assessment) {
                  final percentage =
                      (assessment['percentage'] as num?)?.toDouble();
                  final remarks =
                      assessment['teacher_remarks']?.toString().trim();
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          assessment['assessment']?.toString() ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          assessment['subject']?.toString() ?? '—',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          assessment['date_administered']?.toString() ?? '—',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.stitchMuted,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          percentage == null
                              ? '—'
                              : '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.stitchSuccessText,
                          ),
                        ),
                      ),
                      DataCell(
                        StitchChip(
                          label: remarks != null && remarks.isNotEmpty
                              ? 'Available'
                              : 'Graded',
                          variant: StitchChipVariant.primary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

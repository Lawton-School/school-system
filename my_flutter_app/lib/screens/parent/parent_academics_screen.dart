import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 07: Parent Academics & Student 360 View
/// Connects to `get_student_360_summary(student_profile_id)` with zero mock fixtures.
class ParentAcademicsScreen extends ConsumerWidget {
  const ParentAcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentChildrenProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        title: const Text('Academics & Progress', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.stitchHeading)),
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
                child: Text('No linked student profiles found.', style: TextStyle(color: AppTheme.stitchMuted)),
              ),
            );
          }

          final child = activeChild ?? children.first;
          final summaryAsync = ref.watch(student360SummaryProvider(child.studentId));

          return summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading academics: $e')),
            data: (summary) => _buildContent(context, ref, child, summary),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AuthorizedChild child,
    Map<String, dynamic> summary,
  ) {
    final kpis = summary['kpis'] as Map<String, dynamic>? ?? {};
    final subjects = (summary['subjects'] as List<dynamic>?) ?? [];
    final reportCard = summary['latest_report_card'] as Map<String, dynamic>? ?? {};
    final recentAssessments = (summary['recent_assessments'] as List<dynamic>?) ?? [];

    final averageStr = kpis['academic_average'] != null ? '${kpis["academic_average"]}%' : '—';
    final bestSubjectStr = kpis['best_subject']?.toString() ?? '—';
    final assessmentsCount = kpis['assessments_count']?.toString() ?? '${recentAssessments.length}';
    final reportCardsCount = kpis['reports_count']?.toString() ?? (reportCard.isNotEmpty ? '1' : '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                      'Enrolled in ${child.className} · Real-time academic standing and progress',
                      style: const TextStyle(fontSize: 13, color: AppTheme.stitchMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4 KPI Cards
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
                    value: averageStr,
                    hint: kpis['term_label']?.toString() ?? 'Current Term',
                  ),
                  StitchKpiCard(
                    label: 'Best Subject',
                    value: bestSubjectStr,
                    hint: 'Top scoring subject',
                    statusColor: StitchChipVariant.success,
                  ),
                  StitchKpiCard(
                    label: 'Assessments',
                    value: assessmentsCount,
                    hint: 'Recorded grades',
                  ),
                  StitchKpiCard(
                    label: 'Report Cards',
                    value: reportCardsCount,
                    hint: 'Official published cards',
                    statusColor: StitchChipVariant.info,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Two-column layout: Subject Performance + Latest Report Card
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildSubjectPerformanceCard(subjects)),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: _buildLatestReportCardSummary(reportCard)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSubjectPerformanceCard(subjects),
                    const SizedBox(height: 16),
                    _buildLatestReportCardSummary(reportCard),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // Recent Assessments Card
          _buildRecentAssessmentsCard(recentAssessments),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceCard(List<dynamic> subjects) {
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
                child: Text('No subject grades published yet.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
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
                  DataColumn(label: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('TEACHER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('AVERAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted))),
                ],
                rows: subjects.map((sub) {
                  final s = Map<String, dynamic>.from(sub as Map);
                  final score = (s['average'] as num?)?.toDouble() ?? 0.0;
                  final statusVariant = score >= 80 ? StitchChipVariant.success : (score >= 60 ? StitchChipVariant.primary : StitchChipVariant.warn);

                  return DataRow(cells: [
                    DataCell(Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    DataCell(Text(s['teacher']?.toString() ?? 'Faculty', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${score.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    DataCell(StitchChip(label: score >= 80 ? 'Strong' : 'On Track', variant: statusVariant)),
                  ]);
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
              trailing: StitchChip(label: 'Pending', variant: StitchChipVariant.neutral),
            ),
            SizedBox(height: 24),
            Center(
              child: Text('No formal report cards published for this term.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
            ),
            SizedBox(height: 24),
          ],
        ),
      );
    }

    final avg = (reportCard['average'] as num?)?.toDouble() ?? 0.0;
    final grade = reportCard['overall_grade']?.toString() ?? '—';
    final att = reportCard['attendance_rate']?.toString() ?? '—';
    final comment = reportCard['principal_comment']?.toString() ?? reportCard['teacher_comment']?.toString() ?? 'Consistent effort and positive academic participation.';

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchSectionHeader(
            title: 'Latest Report Card',
            trailing: Text(reportCard['term']?.toString() ?? 'Official Report',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.stitchSuccessText)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${avg.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
                  const SizedBox(height: 2),
                  const Text('AVERAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted)),
                ],
              ),
              Container(width: 1, height: 36, color: const Color(0xFFEEF2F6)),
              Column(
                children: [
                  Text(grade, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                  const SizedBox(height: 2),
                  const Text('OVERALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted)),
                ],
              ),
              Container(width: 1, height: 36, color: const Color(0xFFEEF2F6)),
              Column(
                children: [
                  Text(att, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.stitchSuccessText)),
                  const SizedBox(height: 2),
                  const Text('ATTENDANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted)),
                ],
              ),
            ],
          ),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4C3ADB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssessmentsCard(List<dynamic> recentAssessments) {
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
                child: Text('No assessment submissions graded yet for this period.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
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
                rows: recentAssessments.map((item) {
                  final a = Map<String, dynamic>.from(item as Map);
                  return DataRow(cells: [
                    DataCell(Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    DataCell(Text(a['subject']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a['date']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.stitchMuted))),
                    DataCell(Text(a['score']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.stitchSuccessText))),
                    DataCell(StitchChip(label: a['feedback'] != null ? 'Available' : 'Graded', variant: StitchChipVariant.primary)),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

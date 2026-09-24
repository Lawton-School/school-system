import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

// Screen 22 - Reports & Analytics
// Uses the verified attendance, academic-performance and scoped fee-report RPCs.

enum _ReportType { attendance, academic, finance }

class ReportsAnalyticsScreen extends ConsumerStatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  ConsumerState<ReportsAnalyticsScreen> createState() =>
      _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends ConsumerState<ReportsAnalyticsScreen> {
  _ReportType _selectedReport = _ReportType.attendance;
  AcademicYearModel? _selectedYear;
  GradingTermModel? _selectedTerm;
  ClassSectionModel? _selectedSection;
  Map<String, dynamic>? _reportData;
  bool _loading = false;

  Future<void> _runReport() async {
    final yearId = _selectedYear?.id;
    if (yearId == null || _loading) return;

    setState(() {
      _loading = true;
      _reportData = null;
    });

    try {
      final rpc = ref.read(rpcClientProvider);
      final Map<String, dynamic> result;

      switch (_selectedReport) {
        case _ReportType.attendance:
          result = await rpc.getAttendanceReport(
            academicYearId: yearId,
            termId: _selectedTerm?.id,
            classSectionId: _selectedSection?.id,
          );
        case _ReportType.academic:
          result = await rpc.getAcademicPerformanceReport(
            academicYearId: yearId,
            termId: _selectedTerm?.id,
            classSectionId: _selectedSection?.id,
          );
        case _ReportType.finance:
          result = await rpc.getFeeCollectionsReportByScope(
            academicYearId: yearId,
            termId: _selectedTerm?.id,
            classSectionId: _selectedSection?.id,
          );
      }

      if (mounted) setState(() => _reportData = result);
    } catch (error) {
      debugPrint('[Reports] error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not run report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    final schoolId = session.schoolId;
    final yearsAsync = ref.watch(academicYearsProvider(schoolId));
    final termsAsync = ref.watch(gradingTermsProvider(schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(schoolId));

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
              'ANALYTICS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Reports & Analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading || _selectedYear == null ? null : _runReport,
            icon: Icon(
              _loading ? Icons.hourglass_empty : Icons.play_arrow_rounded,
              size: 16,
              color: AppTheme.primary,
            ),
            label: Text(
              _loading ? 'Running...' : 'Run Report',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StitchCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Filters',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_ReportType>(
                      initialValue: _selectedReport,
                      decoration: const InputDecoration(
                        labelText: 'Report',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ReportType.attendance,
                          child: Text('Attendance Trends'),
                        ),
                        DropdownMenuItem(
                          value: _ReportType.academic,
                          child: Text('Academic Performance'),
                        ),
                        DropdownMenuItem(
                          value: _ReportType.finance,
                          child: Text('Fee Collections'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedReport = value;
                          _reportData = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    yearsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        'Could not load academic years: $error',
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                      data: (years) => DropdownButtonFormField<AcademicYearModel>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select year'),
                        items: years
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text(year.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value;
                            _selectedTerm = null;
                            _reportData = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    termsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        'Could not load terms: $error',
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                      data: (allTerms) {
                        final yearId = _selectedYear?.id;
                        final terms = yearId == null
                            ? const <GradingTermModel>[]
                            : allTerms
                                .where((term) => term.academicYearId == yearId)
                                .toList(growable: false);

                        return DropdownButtonFormField<GradingTermModel>(
                          initialValue: _selectedTerm,
                          decoration: const InputDecoration(
                            labelText: 'Academic Term (optional)',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          hint: Text(
                            yearId == null
                                ? 'Select academic year first'
                                : 'All terms',
                          ),
                          items: [
                            const DropdownMenuItem<GradingTermModel>(
                              value: null,
                              child: Text('All terms'),
                            ),
                            ...terms.map(
                              (term) => DropdownMenuItem(
                                value: term,
                                child: Text(term.name),
                              ),
                            ),
                          ],
                          onChanged: yearId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedTerm = value;
                                    _reportData = null;
                                  });
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    sectionsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        'Could not load classes: $error',
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                      data: (sections) =>
                          DropdownButtonFormField<ClassSectionModel>(
                        initialValue: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Class / Section (optional)',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('All classes'),
                        items: [
                          const DropdownMenuItem<ClassSectionModel>(
                            value: null,
                            child: Text('All classes'),
                          ),
                          ...sections.map(
                            (section) => DropdownMenuItem(
                              value: section,
                              child: Text(section.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value;
                            _reportData = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reportData == null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 60,
                      color: AppTheme.stitchBorder,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Configure filters and run report',
                      style: TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              _ReportResults(
                data: _reportData!,
                reportType: _selectedReport,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportResults extends StatelessWidget {
  final Map<String, dynamic> data;
  final _ReportType reportType;

  const _ReportResults({required this.data, required this.reportType});

  @override
  Widget build(BuildContext context) {
    final summary = _asMap(data['summary']);
    final classes = _mapList(data['classes']);
    final subjects = _mapList(data['subjects']);
    final gradeDistribution = _mapList(data['grade_distribution']);
    final currencies = _mapList(data['currencies']);
    final paymentMethods = _mapList(data['payment_methods']);
    final dataQuality = _asMap(data['data_quality']);

    final hasAnyData = summary.isNotEmpty ||
        classes.isNotEmpty ||
        subjects.isNotEmpty ||
        gradeDistribution.isNotEmpty ||
        currencies.isNotEmpty ||
        paymentMethods.isNotEmpty ||
        dataQuality.isNotEmpty;

    if (!hasAnyData) {
      return const StitchCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'The report ran successfully but there is no data for this scope.',
              style: TextStyle(color: AppTheme.stitchMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty) ...[
          _SummaryCard(title: 'Summary', values: summary),
          const SizedBox(height: 12),
        ],
        if (currencies.isNotEmpty) ...[
          _ResultTableCard(title: 'Currency Summary', rows: currencies),
          const SizedBox(height: 12),
        ],
        if (classes.isNotEmpty) ...[
          _ResultTableCard(title: 'Classes', rows: classes),
          const SizedBox(height: 12),
        ],
        if (subjects.isNotEmpty) ...[
          _ResultTableCard(title: 'Subjects', rows: subjects),
          const SizedBox(height: 12),
        ],
        if (gradeDistribution.isNotEmpty) ...[
          _ResultTableCard(
            title: 'Grade Distribution',
            rows: gradeDistribution,
          ),
          const SizedBox(height: 12),
        ],
        if (paymentMethods.isNotEmpty) ...[
          _ResultTableCard(title: 'Payment Methods', rows: paymentMethods),
          const SizedBox(height: 12),
        ],
        if (dataQuality.isNotEmpty)
          _SummaryCard(title: 'Data Quality', values: dataQuality),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;

  const _SummaryCard({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: values.entries
                  .map(
                    (entry) => _MetricBubble(
                      label: _humanize(entry.key),
                      value: _displayValue(entry.value),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTableCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;

  const _ResultTableCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ),
          _DataTable(rows: rows),
        ],
      ),
    );
  }
}

class _MetricBubble extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBubble({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.stitchHeading,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.stitchMuted,
          ),
        ),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _DataTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.first.keys.take(7).toList(growable: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.stitchBg),
        columns: columns
            .map(
              (column) => DataColumn(
                label: Text(
                  _humanize(column).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.stitchMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows.take(50).map((row) {
          return DataRow(
            cells: columns
                .map(
                  (column) => DataCell(
                    Text(
                      _displayValue(row[column]),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }).toList(),
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

String _humanize(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String _displayValue(dynamic value) {
  if (value == null) return '—';
  if (value is num) {
    final number = value.toDouble();
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number.toStringAsFixed(1);
  }
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is List) return value.isEmpty ? '—' : '${value.length} items';
  if (value is Map) return value.isEmpty ? '—' : '${value.length} fields';
  final text = value.toString().trim();
  return text.isEmpty ? '—' : text;
}

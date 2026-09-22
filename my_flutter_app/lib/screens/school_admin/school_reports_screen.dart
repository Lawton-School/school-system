import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

// Screen 22 - Reports & Analytics
// Calls get_attendance_report, get_academic_performance_report, get_fee_collections_report RPCs.

enum _ReportType { attendance, academic, finance }

class ReportsAnalyticsScreen extends ConsumerStatefulWidget {
  const ReportsAnalyticsScreen({super.key});
  @override
  ConsumerState<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends ConsumerState<ReportsAnalyticsScreen> {
  _ReportType _selectedReport = _ReportType.attendance;
  AcademicYearModel? _selectedYear;
  GradingTermModel? _selectedTerm;
  ClassSectionModel? _selectedSection;
  Map<String, dynamic>? _reportData;
  bool _loading = false;

  Future<void> _runReport() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    final yearId = _selectedYear?.id;
    if (yearId == null) return;
    setState(() { _loading = true; _reportData = null; });
    try {
      final rpc = ref.read(rpcClientProvider);
      Map<String, dynamic> result;
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
          result = await rpc.getFeeCollectionsReport(academicYearId: yearId);
      }
      setState(() { _reportData = result; });
    } catch (e) {
      debugPrint('[Reports] error: ');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No session')));
    final schoolId = session.schoolId;

    final yearsAsync = ref.watch(academicYearsProvider(schoolId));
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
            Text('ANALYTICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.primaryDark)),
            Text('Reports & Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _runReport,
            icon: Icon(_loading ? Icons.hourglass_empty : Icons.play_arrow_rounded, size: 16, color: AppTheme.primary),
            label: Text(_loading ? 'Running...' : 'Run Report', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter panel
            StitchCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
                    const SizedBox(height: 12),
                    // Report type
                    DropdownButtonFormField<_ReportType>(
                      initialValue: _selectedReport,
                      decoration: const InputDecoration(
                        labelText: 'Report',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: _ReportType.attendance, child: Text('Attendance Trends')),
                        DropdownMenuItem(value: _ReportType.academic, child: Text('Academic Performance')),
                        DropdownMenuItem(value: _ReportType.finance, child: Text('Fee Collections')),
                      ],
                      onChanged: (v) => setState(() { _selectedReport = v!; _reportData = null; }),
                    ),
                    const SizedBox(height: 10),
                    // Academic year
                    yearsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (years) => DropdownButtonFormField<AcademicYearModel>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(labelText: 'Academic Year', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder()),
                        hint: const Text('Select year'),
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.name))).toList(),
                        onChanged: (v) => setState(() { _selectedYear = v; _selectedTerm = null; _reportData = null; }),
                      ),
                    ),
                    if (_selectedReport != _ReportType.finance) ...[
                      const SizedBox(height: 10),
                      // Section filter
                      sectionsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (sections) => DropdownButtonFormField<ClassSectionModel>(
                          initialValue: _selectedSection,
                          decoration: const InputDecoration(labelText: 'Class / Section (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder()),
                          hint: const Text('All classes'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All classes')),
                            ...sections.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                          ],
                          onChanged: (v) => setState(() { _selectedSection = v; _reportData = null; }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results area
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_reportData == null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.bar_chart_rounded, size: 60, color: AppTheme.stitchBorder),
                    const SizedBox(height: 14),
                    const Text('Configure filters and run report', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 14)),
                  ],
                ),
              )
            else
              _ReportResults(data: _reportData!, reportType: _selectedReport),
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
    final summary = data['summary'];
    final rows = data['rows'];
    final classes = data['classes'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary metrics
        if (summary is Map) ...[
          StitchCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.stitchHeading)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: summary.entries.map((e) {
                      final v = e.value;
                      return _MetricBubble(label: _humanize(e.key), value: v is double ? _fmtNum(v) : '');
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Class-level table
        if (rows is List && rows.isNotEmpty)
          _DataTable(rows: rows.cast<Map>())
        else if (classes is List && classes.isNotEmpty)
          _DataTable(rows: classes.cast<Map>()),
      ],
    );
  }

  String _humanize(String key) => key.replaceAll('_', ' ').replaceFirst(RegExp('^.'), key[0].toUpperCase());

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
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
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  final List<Map> rows;
  const _DataTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.first.keys.take(6).toList();

    return StitchCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.stitchBg),
          columns: cols.map((c) => DataColumn(
            label: Text(
              c.toString().replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.stitchMuted, letterSpacing: 0.5),
            ),
          )).toList(),
          rows: rows.take(30).map((row) => DataRow(
            cells: cols.map((c) {
              final val = row[c];
              return DataCell(Text(
                val != null ? '' : '�',
                style: const TextStyle(fontSize: 12, color: AppTheme.stitchHeading),
              ));
            }).toList(),
          )).toList(),
        ),
      ),
    );
  }
}

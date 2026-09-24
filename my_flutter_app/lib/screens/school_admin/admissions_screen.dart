import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/admissions_controllers.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../widgets/stitch_widgets.dart';
import '../../providers/providers.dart';

/// Screen 15 — Admissions.
///
/// Staff-facing admissions pipeline backed by `get_admissions_pipeline()`.
/// Status changes and enrollment linking are server-authoritative. Applicant
/// document upload is deliberately not exposed here because the private
/// admissions bucket does not support unauthenticated uploads.
class AdmissionsScreen extends ConsumerStatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  ConsumerState<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends ConsumerState<AdmissionsScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(admissionsPipelineProvider);
    final role = ref.watch(activeSessionProvider)?.role;
    final isReception = role == AppRoles.reception;

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
              'ADMISSIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Application Pipeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New application',
            onPressed: _showNewApplicationDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: () => ref.invalidate(admissionsPipelineProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: pipelineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdmissionsError(
          message: 'Unable to load admissions: $error',
          onRetry: () => ref.invalidate(admissionsPipelineProvider),
        ),
        data: (pipeline) {
          final applications = _mapList(pipeline['applications']);
          final visible = _filterApplications(applications);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(admissionsPipelineProvider);
              await ref.read(admissionsPipelineProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _PipelineSummary(pipeline: pipeline, applications: applications),
                const SizedBox(height: 18),
                if (isReception)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: StitchCard(
                      child: Text('Reception workspace · Capture applications, request missing information and prepare records for Registrar review. Admission decisions and enrollment are restricted.'),
                    ),
                  ),
                _buildFilters(),
                const SizedBox(height: 18),
                StitchSectionHeader(
                  title: 'Applications',
                  subtitle: '${visible.length} of ${applications.length} records',
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const StitchCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No applications match the current filter.',
                          style: TextStyle(color: AppTheme.stitchMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ...visible.map(_buildApplicationCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search applicant, guardian or class',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _filterChip('all', 'All'),
              _filterChip('new', 'New'),
              _filterChip('under_review', 'Under Review'),
              _filterChip('accepted', 'Accepted'),
              _filterChip('waitlisted', 'Waitlisted'),
              _filterChip('enrolled', 'Enrolled'),
              _filterChip('rejected', 'Rejected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  List<Map<String, dynamic>> _filterApplications(
    List<Map<String, dynamic>> applications,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return applications.where((application) {
      final displayStatus = application['display_status']?.toString() ??
          application['status']?.toString() ??
          '';
      if (_filter != 'all' && displayStatus != _filter) return false;
      if (query.isEmpty) return true;

      final haystack = [
        application['applicant_name'],
        application['parent_name'],
        application['parent_email'],
        application['parent_phone'],
        application['requested_class'],
        application['previous_school'],
      ].whereType<Object>().map((value) => value.toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final isReception = ref.read(activeSessionProvider)?.role == AppRoles.reception;
    final displayStatus = application['display_status']?.toString() ??
        application['status']?.toString() ??
        'applied';
    final createdAt = _date(application['created_at']);
    final documentCount = (application['document_count'] as num?)?.toInt() ?? 0;
    final enrolledId = application['enrolled_student_profile_id']?.toString();
    final acceptedAndUnlinked = application['status']?.toString() == 'accepted' &&
        (enrolledId == null || enrolledId.isEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StitchCard(
        onTap: () => _showApplicationDetails(application),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application['applicant_name']?.toString() ?? 'Applicant',
                        style: const TextStyle(
                          color: AppTheme.stitchHeading,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        application['requested_class']?.toString().isNotEmpty == true
                            ? 'Requested class: ${application['requested_class']}'
                            : 'Requested class not assigned',
                        style: const TextStyle(
                          color: AppTheme.stitchMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                StitchChip(
                  label: _statusLabel(displayStatus),
                  variant: _statusVariant(displayStatus),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _AdmissionMetric(
                  label: 'Guardian',
                  value: application['parent_name']?.toString() ?? '—',
                ),
                _AdmissionMetric(
                  label: 'Documents',
                  value: '$documentCount',
                ),
                _AdmissionMetric(
                  label: 'Applied',
                  value: createdAt == null
                      ? '—'
                      : '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showStatusDialog(application),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Review'),
                ),
                if (acceptedAndUnlinked && !isReception)
                  FilledButton.icon(
                    onPressed: () => _showEnrollAcceptedDialog(application),
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: const Text('Enroll Student'),
                  ),
                TextButton.icon(
                  onPressed: () => _showApplicationDetails(application),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusDialog(Map<String, dynamic> application) async {
    final isReception = ref.read(activeSessionProvider)?.role == AppRoles.reception;
    final statuses = <String, String>{
      'applied': 'Applied',
      'review': 'Under Review',
      'info_requested': 'Information Requested',
      if (!isReception) 'accepted': 'Accepted',
      'waitlisted': 'Waitlisted',
      if (!isReception) 'rejected': 'Rejected',
    };
    var selected = application['status']?.toString() ?? 'applied';
    if (!statuses.containsKey(selected)) selected = 'applied';
    final notesController = TextEditingController(
      text: application['review_notes']?.toString() ?? '',
    );
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Review ${application['applicant_name']?.toString() ?? 'Application'}',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Application Status'),
                  items: statuses.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) setDialogState(() => selected = value);
                        },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Review Notes',
                    hintText: 'Internal review notes or information required',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final id = application['id']?.toString() ?? '';
                      if (id.isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await ref.read(admissionsRepositoryProvider).setStatus(
                              applicationId: id,
                              status: selected,
                              reviewNotes: notesController.text,
                            );
                        ref.invalidate(admissionsPipelineProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Application updated.')),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Update failed: $error')),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );

    notesController.dispose();
  }

  Future<void> _showNewApplicationDialog() async {
    final formKey = GlobalKey<FormState>();
    final first = TextEditingController();
    final middle = TextEditingController();
    final last = TextEditingController();
    final studentEmail = TextEditingController();
    final studentPhone = TextEditingController();
    final guardian = TextEditingController();
    final guardianEmail = TextEditingController();
    final guardianPhone = TextEditingController();
    final previousSchool = TextEditingController();
    final nationality = TextEditingController(text: 'Zimbabwean');
    final emergencyName = TextEditingController();
    final emergencyPhone = TextEditingController();
    final medicalNotes = TextEditingController();
    DateTime? dob;
    String relationship = 'guardian';
    String curriculum = 'ZIMSEC';
    String attendanceType = 'day';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Student Application'),
          content: SizedBox(
            width: 650,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: Text('Student details', style: TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(controller: first, decoration: const InputDecoration(labelText: 'First name *'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: middle, decoration: const InputDecoration(labelText: 'Middle name'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: last, decoration: const InputDecoration(labelText: 'Last name *'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
                    ]),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dob == null ? 'Date of birth *' : 'Date of birth: ${dob!.day}/${dob!.month}/${dob!.year}'),
                      trailing: const Icon(Icons.calendar_month_rounded),
                      onTap: () async {
                        final value = await showDatePicker(context: context, initialDate: DateTime(DateTime.now().year - 10), firstDate: DateTime(1990), lastDate: DateTime.now());
                        if (value != null) setDialogState(() => dob = value);
                      },
                    ),
                    Row(children: [
                      Expanded(child: TextFormField(controller: studentEmail, decoration: const InputDecoration(labelText: 'Student email (optional)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: studentPhone, decoration: const InputDecoration(labelText: 'Student phone (optional)'))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(initialValue: curriculum, decoration: const InputDecoration(labelText: 'Curriculum'), items: const [DropdownMenuItem(value: 'ZIMSEC', child: Text('ZIMSEC')), DropdownMenuItem(value: 'Cambridge', child: Text('Cambridge')), DropdownMenuItem(value: 'Other', child: Text('Other'))], onChanged: (v) => setDialogState(() => curriculum = v ?? curriculum))),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<String>(initialValue: attendanceType, decoration: const InputDecoration(labelText: 'Attendance'), items: const [DropdownMenuItem(value: 'day', child: Text('Day')), DropdownMenuItem(value: 'boarding', child: Text('Boarding'))], onChanged: (v) => setDialogState(() => attendanceType = v ?? attendanceType))),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(controller: previousSchool, decoration: const InputDecoration(labelText: 'Previous school')),
                    const SizedBox(height: 10),
                    TextFormField(controller: nationality, decoration: const InputDecoration(labelText: 'Nationality')),
                    const SizedBox(height: 18),
                    const Align(alignment: Alignment.centerLeft, child: Text('Parent / Guardian', style: TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(height: 10),
                    TextFormField(controller: guardian, decoration: const InputDecoration(labelText: 'Guardian full name *'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(controller: guardianEmail, decoration: const InputDecoration(labelText: 'Guardian email'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: guardianPhone, decoration: const InputDecoration(labelText: 'Guardian phone'))),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(initialValue: relationship, decoration: const InputDecoration(labelText: 'Relationship'), items: const [DropdownMenuItem(value: 'mother', child: Text('Mother')), DropdownMenuItem(value: 'father', child: Text('Father')), DropdownMenuItem(value: 'guardian', child: Text('Guardian')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (v) => setDialogState(() => relationship = v ?? relationship)),
                    const SizedBox(height: 18),
                    const Align(alignment: Alignment.centerLeft, child: Text('Emergency & important notes', style: TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(controller: emergencyName, decoration: const InputDecoration(labelText: 'Emergency contact'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: emergencyPhone, decoration: const InputDecoration(labelText: 'Emergency phone'))),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(controller: medicalNotes, maxLines: 2, decoration: const InputDecoration(labelText: 'Important medical notes (optional)')),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (!(formKey.currentState?.validate() ?? false) || dob == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Complete the required student and guardian fields.')));
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final result = await ref.read(admissionsRepositoryProvider).createApplication(
                    firstName: first.text, middleName: middle.text, lastName: last.text, dateOfBirth: dob!,
                    email: studentEmail.text, phone: studentPhone.text, parentName: guardian.text,
                    parentEmail: guardianEmail.text, parentPhone: guardianPhone.text, previousSchool: previousSchool.text,
                    nationality: nationality.text, curriculum: curriculum, attendanceType: attendanceType,
                    guardianRelationship: relationship, emergencyContactName: emergencyName.text,
                    emergencyContactPhone: emergencyPhone.text, medicalNotes: medicalNotes.text,
                  );
                  ref.invalidate(admissionsPipelineProvider);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Application ${result['application_number'] ?? ''} created successfully.')));
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Application failed: $e')));
                    setDialogState(() => saving = false);
                  }
                }
              },
              child: Text(saving ? 'Submitting...' : 'Submit Application'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [first,middle,last,studentEmail,studentPhone,guardian,guardianEmail,guardianPhone,previousSchool,nationality,emergencyName,emergencyPhone,medicalNotes]) {
      controller.dispose();
    }
  }

  Future<void> _showEnrollAcceptedDialog(Map<String, dynamic> application) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    final sections = await ref.read(classSectionsProvider(session.schoolId).future);
    final years = await ref.read(academicYearsProvider(session.schoolId).future);
    if (!mounted) return;
    if (sections.isEmpty || years.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create an academic year and class section before enrollment.')));
      return;
    }

    String yearId = years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
    var matchingSections = sections.where((s) => s.classModel?.academicYearId == yearId).toList();
    if (matchingSections.isEmpty) matchingSections = sections;
    String sectionId = matchingSections.first.id;
    final roll = TextEditingController();
    final admissionNo = TextEditingController(text: application['application_number']?.toString() ?? '');
    bool saving = false;

    Map<String, dynamic>? success;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(success == null ? 'Enroll Accepted Student' : 'Enrollment Successful'),
          content: SizedBox(
            width: 560,
            child: success != null
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 54),
                    const SizedBox(height: 12),
                    Text('${application['applicant_name'] ?? 'Student'} is now an active student.', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('Admission number: ${success!['admission_number'] ?? '—'}'),
                    Text('Student profile: ${success!['student_profile_id'] ?? '—'}'),
                    const SizedBox(height: 8),
                    const Text('The guardian profile and parent-student relationship were created or linked automatically.'),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: yearId,
                      decoration: const InputDecoration(labelText: 'Academic Year'),
                      items: years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.name))).toList(),
                      onChanged: saving ? null : (v) {
                        if (v == null) return;
                        setDialogState(() {
                          yearId = v;
                          final filtered = sections.where((s) => s.classModel?.academicYearId == yearId).toList();
                          matchingSections = filtered.isEmpty ? sections : filtered;
                          sectionId = matchingSections.first.id;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(sectionId),
                      initialValue: sectionId,
                      decoration: const InputDecoration(labelText: 'Class / Section'),
                      items: matchingSections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName))).toList(),
                      onChanged: saving ? null : (v) => setDialogState(() => sectionId = v ?? sectionId),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: admissionNo, decoration: const InputDecoration(labelText: 'Admission Number')),
                    const SizedBox(height: 12),
                    TextFormField(controller: roll, decoration: const InputDecoration(labelText: 'Roll Number (optional)')),
                    const SizedBox(height: 12),
                    const Text('Enrollment creates the student profile, student details, class enrollment, parent profile (or reuses a matching parent), and parent-student relationship in one server transaction.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 11.5)),
                  ]),
          ),
          actions: success != null
              ? [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))]
              : [
                  TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                  FilledButton.icon(
                    onPressed: saving ? null : () async {
                      setDialogState(() => saving = true);
                      try {
                        final result = await ref.read(admissionsRepositoryProvider).enrollAcceptedApplication(
                          applicationId: application['id'].toString(), classSectionId: sectionId,
                          academicYearId: yearId, rollNumber: roll.text, admissionNumber: admissionNo.text,
                        );
                        ref.invalidate(admissionsPipelineProvider);
                        setDialogState(() { success = result; saving = false; });
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Enrollment failed: $e')));
                          setDialogState(() => saving = false);
                        }
                      }
                    },
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: Text(saving ? 'Enrolling...' : 'Enroll Student'),
                  ),
                ],
        ),
      ),
    );
    roll.dispose();
    admissionNo.dispose();
  }

  Future<void> _showApplicationDetails(Map<String, dynamic> application) async {
    final applicationId = application['id']?.toString() ?? '';
    if (applicationId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.88,
        child: Consumer(
          builder: (context, ref, _) {
            final documentsAsync = ref.watch(
              admissionDocumentsProvider(applicationId),
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        application['applicant_name']?.toString() ?? 'Application',
                        style: const TextStyle(
                          color: AppTheme.stitchHeading,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    StitchChip(
                      label: _statusLabel(
                        application['display_status']?.toString() ??
                            application['status']?.toString() ??
                            'applied',
                      ),
                      variant: _statusVariant(
                        application['display_status']?.toString() ??
                            application['status']?.toString() ??
                            'applied',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailSection(
                  title: 'Application',
                  rows: {
                    'Requested class': application['requested_class']?.toString() ?? '—',
                    'Previous school': application['previous_school']?.toString() ?? '—',
                    'Applied': _formatDate(application['created_at']),
                    'Reviewed': _formatDate(application['reviewed_at']),
                    'Decision': _formatDate(application['decision_at']),
                  },
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Guardian & Contact',
                  rows: {
                    'Guardian': application['parent_name']?.toString() ?? '—',
                    'Guardian email': application['parent_email']?.toString() ?? '—',
                    'Guardian phone': application['parent_phone']?.toString() ?? '—',
                  },
                ),
                if ((application['review_notes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  StitchCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Notes',
                          style: TextStyle(
                            color: AppTheme.stitchHeading,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          application['review_notes'].toString(),
                          style: const TextStyle(
                            color: AppTheme.stitchMuted,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const StitchSectionHeader(
                  title: 'Documents',
                  subtitle: 'Private admissions document records',
                ),
                const SizedBox(height: 10),
                documentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(
                    'Unable to load documents: $error',
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                  data: (documents) {
                    if (documents.isEmpty) {
                      return const StitchCard(
                        child: Text(
                          'No documents are recorded for this application.',
                          style: TextStyle(color: AppTheme.stitchMuted),
                        ),
                      );
                    }
                    return Column(
                      children: documents.map((document) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: StitchCard(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        document['document_type']?.toString() ?? 'Document',
                                        style: const TextStyle(
                                          color: AppTheme.stitchHeading,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _fileLabel(document['document_url']),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.stitchMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Document files remain private. This screen lists authenticated records only; public applicant uploads require a separate signed-upload flow.',
                  style: TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static String _formatDate(dynamic value) {
    final date = _date(value);
    return date == null ? '—' : '${date.day}/${date.month}/${date.year}';
  }

  static String _fileLabel(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return 'Private file';
    final parts = text.split('/');
    return parts.isEmpty ? text : parts.last;
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'new':
      case 'applied':
        return 'NEW';
      case 'under_review':
      case 'review':
        return 'UNDER REVIEW';
      case 'info_requested':
        return 'INFO REQUESTED';
      case 'accepted':
        return 'ACCEPTED';
      case 'waitlisted':
        return 'WAITLISTED';
      case 'rejected':
        return 'REJECTED';
      case 'enrolled':
        return 'ENROLLED';
      default:
        return status.toUpperCase();
    }
  }

  static StitchChipVariant _statusVariant(String status) {
    switch (status) {
      case 'accepted':
      case 'enrolled':
        return StitchChipVariant.success;
      case 'under_review':
      case 'review':
      case 'info_requested':
      case 'waitlisted':
        return StitchChipVariant.warn;
      case 'rejected':
        return StitchChipVariant.danger;
      case 'new':
      case 'applied':
        return StitchChipVariant.info;
      default:
        return StitchChipVariant.neutral;
    }
  }
}

class _PipelineSummary extends StatelessWidget {
  final Map<String, dynamic> pipeline;
  final List<Map<String, dynamic>> applications;

  const _PipelineSummary({
    required this.pipeline,
    required this.applications,
  });

  @override
  Widget build(BuildContext context) {
    final enrolled = applications
        .where((application) => application['display_status'] == 'enrolled')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920 ? 5 : 2;
        final spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _kpi(width, 'New', pipeline['new'], Icons.fiber_new_rounded),
            _kpi(width, 'Review', pipeline['under_review'], Icons.fact_check_rounded),
            _kpi(width, 'Accepted', pipeline['accepted'], Icons.task_alt_rounded),
            _kpi(width, 'Waitlisted', pipeline['waitlisted'], Icons.hourglass_top_rounded),
            _kpi(width, 'Enrolled', enrolled, Icons.school_rounded),
          ],
        );
      },
    );
  }

  Widget _kpi(double width, String label, dynamic value, IconData icon) {
    return SizedBox(
      width: width,
      child: StitchKpiCard(
        label: label,
        value: '${(value as num?)?.toInt() ?? 0}',
        hint: 'Applications',
        icon: icon,
      ),
    );
  }
}

class _AdmissionMetric extends StatelessWidget {
  final String label;
  final String value;

  const _AdmissionMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.stitchMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.stitchHeading,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _DetailSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.stitchHeading,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: AppTheme.stitchHeading,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdmissionsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdmissionsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: AppTheme.danger,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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

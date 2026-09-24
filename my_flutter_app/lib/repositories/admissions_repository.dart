import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

/// Server-authoritative repository for Screen 15 — Admissions.
///
/// Reads the admissions pipeline through the verified RPC contract. Status
/// transitions and enrollment linking are performed only by server RPCs so the
/// client cannot bypass tenant, role, status, or school checks.
class AdmissionsRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  AdmissionsRepository({
    required SupabaseClient client,
    required RpcClient rpc,
  }) : this._(client, rpc);

  AdmissionsRepository._(this._client, this._rpc);

  Future<Map<String, dynamic>> fetchPipeline() => _rpc.getAdmissionsPipeline();

  Future<List<Map<String, dynamic>>> fetchDocuments(String applicationId) async {
    if (applicationId.trim().isEmpty) return const [];

    final raw = await _client
        .from('admissions_documents')
        .select(
          'id, application_id, document_type, document_url, created_at, updated_at',
        )
        .eq('application_id', applicationId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return _mapList(raw);
  }

  /// Existing student profiles eligible to be selected by staff when linking
  /// an accepted application. The RPC still re-validates role and school.
  Future<List<Map<String, dynamic>>> fetchStudentCandidates() async {
    final raw = await _client
        .from('profiles')
        .select('id, first_name, last_name, email, status')
        .eq('role', 'student')
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .order('last_name', ascending: true)
        .order('first_name', ascending: true);

    return _mapList(raw).map((profile) {
      final first = profile['first_name']?.toString().trim() ?? '';
      final last = profile['last_name']?.toString().trim() ?? '';
      return <String, dynamic>{
        ...profile,
        'full_name': '$first $last'.trim(),
      };
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> setStatus({
    required String applicationId,
    required String status,
    String? reviewNotes,
  }) async {
    const allowed = {
      'applied',
      'review',
      'info_requested',
      'accepted',
      'waitlisted',
      'rejected',
    };
    if (!allowed.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported admission status.');
    }

    final response = await _client.rpc(
      'set_admission_status',
      params: {
        'p_application_id': applicationId,
        'p_status': status,
        'p_review_notes': _nullableTrim(reviewNotes),
      },
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> createApplication({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String parentName,
    String? email,
    String? phone,
    String? parentEmail,
    String? parentPhone,
    String? requestedClassId,
    String? requestedAcademicYearId,
    String? previousSchool,
    String? middleName,
    String? gender,
    String? nationality,
    String? identityNumber,
    String? curriculum,
    String? attendanceType,
    String? guardianRelationship,
    String? guardianAddress,
    String? guardianOccupation,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medicalNotes,
  }) async {
    final response = await _client.rpc('create_admission_application', params: {
      'p_first_name': firstName.trim(),
      'p_last_name': lastName.trim(),
      'p_date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'p_email': _nullableTrim(email) ?? '',
      'p_parent_name': parentName.trim(),
      'p_requested_class_id': _nullableTrim(requestedClassId),
      'p_requested_academic_year_id': _nullableTrim(requestedAcademicYearId),
      'p_phone': _nullableTrim(phone),
      'p_parent_email': _nullableTrim(parentEmail),
      'p_parent_phone': _nullableTrim(parentPhone),
      'p_previous_school': _nullableTrim(previousSchool),
      'p_middle_name': _nullableTrim(middleName),
      'p_gender': _nullableTrim(gender),
      'p_nationality': _nullableTrim(nationality),
      'p_identity_number': _nullableTrim(identityNumber),
      'p_curriculum': _nullableTrim(curriculum),
      'p_attendance_type': _nullableTrim(attendanceType),
      'p_guardian_relationship': _nullableTrim(guardianRelationship),
      'p_guardian_address': _nullableTrim(guardianAddress),
      'p_guardian_occupation': _nullableTrim(guardianOccupation),
      'p_emergency_contact_name': _nullableTrim(emergencyContactName),
      'p_emergency_contact_phone': _nullableTrim(emergencyContactPhone),
      'p_medical_notes': _nullableTrim(medicalNotes),
    });
    return _asMap(response);
  }

  Future<Map<String, dynamic>> enrollAcceptedApplication({
    required String applicationId,
    required String classSectionId,
    required String academicYearId,
    String? rollNumber,
    String? admissionNumber,
  }) async {
    final response = await _client.rpc('enroll_accepted_application', params: {
      'p_application_id': applicationId,
      'p_class_section_id': classSectionId,
      'p_academic_year_id': academicYearId,
      'p_roll_number': _nullableTrim(rollNumber),
      'p_admission_number': _nullableTrim(admissionNumber),
    });
    return _asMap(response);
  }

  Future<Map<String, dynamic>> frontDeskLookup(String query) async {
    final response = await _client.rpc('reception_directory_lookup', params: {
      'p_query': query.trim(),
      'p_limit': 30,
    });
    return _asMap(response);
  }

  Future<void> createFrontDeskEnquiry({
    required String schoolId,
    required String profileId,
    required String contactName,
    required String subject,
    String? phone,
    String? email,
    String enquiryType = 'general',
    String? notes,
  }) async {
    await _client.from('front_desk_enquiries').insert({
      'school_id': schoolId,
      'created_by_profile_id': profileId,
      'contact_name': contactName.trim(),
      'contact_phone': _nullableTrim(phone),
      'contact_email': _nullableTrim(email),
      'enquiry_type': enquiryType,
      'subject': subject.trim(),
      'notes': _nullableTrim(notes),
    });
  }

  Future<Map<String, dynamic>> fetchFrontDeskWorkspace() async {
    return _asMap(await _client.rpc('get_front_desk_workspace'));
  }

  Future<void> createAppointment({
    required String schoolId, required String profileId, required String visitorName,
    required String purpose, required DateTime appointmentAt, String? phone, String? email, String? notes,
  }) async {
    await _client.from('front_desk_appointments').insert({
      'school_id': schoolId, 'created_by_profile_id': profileId, 'visitor_name': visitorName.trim(),
      'visitor_phone': _nullableTrim(phone), 'visitor_email': _nullableTrim(email), 'purpose': purpose.trim(),
      'appointment_at': appointmentAt.toIso8601String(), 'notes': _nullableTrim(notes),
    });
  }

  Future<void> checkInVisitor({
    required String schoolId, required String profileId, required String visitorName,
    required String purpose, String? phone, String? organization, String? notes, String? appointmentId,
  }) async {
    await _client.from('front_desk_visits').insert({
      'school_id': schoolId, 'created_by_profile_id': profileId, 'visitor_name': visitorName.trim(),
      'visitor_phone': _nullableTrim(phone), 'organization': _nullableTrim(organization), 'purpose': purpose.trim(),
      'notes': _nullableTrim(notes), 'appointment_id': _nullableTrim(appointmentId),
    });
    if (_nullableTrim(appointmentId) != null) {
      await _client.from('front_desk_appointments').update({'status': 'arrived', 'updated_at': DateTime.now().toIso8601String()}).eq('id', appointmentId!);
    }
  }

  Future<void> checkOutVisitor(String visitId) async {
    await _client.rpc('check_out_front_desk_visitor', params: {'p_visit_id': visitId});
  }

  Future<void> setEnquiryStatus(String enquiryId, String status) async {
    await _client.rpc('set_front_desk_enquiry_status', params: {'p_enquiry_id': enquiryId, 'p_status': status});
  }

  Future<Map<String, dynamic>> linkEnrolledStudent({
    required String applicationId,
    required String studentProfileId,
  }) async {
    final response = await _client.rpc(
      'link_admission_to_enrolled_student',
      params: {
        'p_application_id': applicationId,
        'p_student_profile_id': studentProfileId,
      },
    );
    return _asMap(response);
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

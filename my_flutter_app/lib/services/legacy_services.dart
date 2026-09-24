import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/models.dart';


/// Handles all authentication operations with Supabase.
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a magic link for passwordless login (used for inviting admins).
  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  /// Invite a user by email (Super Admin only — uses admin API via Edge Function).
  /// This sends an invite email and creates the auth.users record.
  Future<void> inviteUserByEmail(String email) async {
    await _client.functions.invoke('invite-user', body: {'email': email});
  }

  /// Reset password for a user.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}

/// Handles all profile-related database operations.
class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  /// Fetch all profiles for the currently logged-in user (across all schools).
  Future<List<ProfileModel>> getUserProfiles() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('profiles')
        .select('*, schools(*)')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);

    return (response as List)
        .map((m) => ProfileModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all profiles for a school.
  Future<List<ProfileModel>> getSchoolProfiles(String schoolId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('first_name', ascending: true);

    return (response as List)
        .map((m) => ProfileModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single profile by ID.
  Future<ProfileModel?> getProfileById(String profileId) async {
    final response = await _client
        .from('profiles')
        .select('*, schools(id, name, subdomain, status)')
        .eq('id', profileId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (response == null) return null;
    return ProfileModel.fromMap(response);
  }

  /// Create a new profile (used by school admin to add users).
  Future<ProfileModel> createProfile({
    required String schoolId,
    required String role,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final response = await _client.from('profiles').insert({
      'school_id': schoolId,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'user_id': userId,
      'status': 'active',
    }).select().single();
    return ProfileModel.fromMap(response);
  }

  /// Invite a school user through the server-side Auth Admin workflow.
  Future<void> inviteSchoolUser({
    required String role,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
  }) async {
    final response = await _client.functions.invoke('invite-school-user', body: {
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
    });
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(message ?? 'Unable to invite user');
    }
  }

  /// Update a profile.
  Future<ProfileModel> updateProfile({
    required String profileId,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final response = await _client
        .from('profiles')
        .update(updates)
        .eq('id', profileId)
        .select()
        .single();
    return ProfileModel.fromMap(response);
  }

  /// Soft-delete a profile.
  Future<void> deleteProfile(String profileId) async {
    await _client.from('profiles').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'status': 'inactive',
    }).eq('id', profileId);
  }
}

/// Handles all school (tenant) management operations.
class SchoolService {
  final SupabaseClient _client;

  SchoolService(this._client);

  /// Fetch all schools (super admin only).
  Future<List<SchoolModel>> getAllSchools() async {
    final response = await _client
        .from('schools')
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return response
        .map((m) => SchoolModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Create a new school tenant (super admin only).
  Future<SchoolModel> createSchool({
    required String name,
    required String subdomain,
    Map<String, dynamic>? settings,
  }) async {
    final response = await _client.from('schools').insert({
      'name': name,
      'subdomain': subdomain.toLowerCase(),
      'settings': settings ?? {},
      'status': 'active',
    }).select().single();
    return SchoolModel.fromMap(response);
  }

  /// Update school details.
  Future<SchoolModel> updateSchool({
    required String schoolId,
    String? name,
    Map<String, dynamic>? settings,
    String? status,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (settings != null) updates['settings'] = settings;
    if (status != null) updates['status'] = status;

    final response = await _client
        .from('schools')
        .update(updates)
        .eq('id', schoolId)
        .select()
        .single();
    return SchoolModel.fromMap(response);
  }

  /// Suspend or activate a school.
  Future<void> setSchoolStatus(String schoolId, String status) async {
    assert(status == 'active' || status == 'suspended');
    await _client.from('schools').update({'status': status}).eq('id', schoolId);
  }

  /// Fetch all profiles within a school (for school admin).
  Future<List<ProfileModel>> getSchoolProfiles(String schoolId, {String? role}) async {
    var query = _client
        .from('profiles')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (role != null) {
      query = query.eq('role', role);
    }

    final response = await query.order('first_name', ascending: true);
    return response
        .map((m) => ProfileModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Map a parent profile to a student profile.
  Future<void> linkParentToStudent({
    required String schoolId,
    required String parentProfileId,
    required String studentProfileId,
    required String relationshipType,
  }) async {
    await _client.from('user_relationships').upsert({
      'school_id': schoolId,
      'parent_id': parentProfileId,
      'student_id': studentProfileId,
      'relationship_type': relationshipType,
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// PHASE 2 SERVICES: ACADEMIC STRUCTURE & ENROLLMENTS
// ─────────────────────────────────────────────────────────────────

class AcademicStructureService {
  final SupabaseClient _client;

  AcademicStructureService(this._client);

  // ── ACADEMIC YEARS ─────────────────────────
  Future<List<AcademicYearModel>> getAcademicYears(String schoolId) async {
    final response = await _client
        .from('academic_years')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('start_date', ascending: false);

    return response
        .map((m) => AcademicYearModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<AcademicYearModel> createAcademicYear({
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
  }) async {
    if (isCurrent) {
      // Unset previous current academic year
      await _client
          .from('academic_years')
          .update({'is_current': false})
          .eq('school_id', schoolId);
    }

    final response = await _client.from('academic_years').insert({
      'school_id': schoolId,
      'name': name,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_current': isCurrent,
    }).select().single();

    return AcademicYearModel.fromMap(response);
  }

  Future<void> setCurrentAcademicYear(String schoolId, String yearId) async {
    await _client
        .from('academic_years')
        .update({'is_current': false})
        .eq('school_id', schoolId);

    await _client
        .from('academic_years')
        .update({'is_current': true})
        .eq('id', yearId);
  }

  // ── CLASSES (GRADE LEVELS) ────────────────
  Future<List<ClassModel>> getClasses(String schoolId) async {
    final response = await _client
        .from('classes')
        .select('*, academic_years(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('name', ascending: true);

    return response
        .map((m) => ClassModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<ClassModel> createClass({
    required String schoolId,
    required String name,
    required String academicYearId,
  }) async {
    final response = await _client.from('classes').insert({
      'school_id': schoolId,
      'name': name,
      'academic_year_id': academicYearId,
    }).select('*, academic_years(*)').single();

    return ClassModel.fromMap(response);
  }

  // ── CLASS SECTIONS ─────────────────────────
  Future<List<ClassSectionModel>> getClassSections(String schoolId, {String? classId}) async {
    var query = _client
        .from('class_sections')
        .select('*, classes(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (classId != null) {
      query = query.eq('class_id', classId);
    }

    final response = await query.order('name', ascending: true);
    return response
        .map((m) => ClassSectionModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<ClassSectionModel> createClassSection({
    required String schoolId,
    required String classId,
    required String name,
    String? room,
  }) async {
    final response = await _client.from('class_sections').insert({
      'school_id': schoolId,
      'class_id': classId,
      'name': name,
      'room': room,
    }).select('*, classes(*)').single();

    return ClassSectionModel.fromMap(response);
  }

  // ── SUBJECTS ───────────────────────────────
  Future<List<SubjectModel>> getSubjects(String schoolId) async {
    final response = await _client
        .from('subjects')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('name', ascending: true);

    return response
        .map((m) => SubjectModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<SubjectModel> createSubject({
    required String schoolId,
    required String name,
    String? code,
  }) async {
    final response = await _client.from('subjects').insert({
      'school_id': schoolId,
      'name': name,
      'code': code,
    }).select().single();

    return SubjectModel.fromMap(response);
  }

  // ── CLASS TEACHER ASSIGNMENTS ──────────────
  Future<List<ClassTeacherModel>> getClassTeachers(String schoolId, {String? classSectionId}) async {
    var query = _client
        .from('class_teachers')
        .select('*, profiles!class_teachers_teacher_profile_id_fkey(*), subjects(*), class_sections(*, classes(*))')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (classSectionId != null) {
      query = query.eq('class_section_id', classSectionId);
    }

    final response = await query;
    return response
        .map((m) => ClassTeacherModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<ClassTeacherModel> assignTeacher({
    required String schoolId,
    required String classSectionId,
    required String teacherProfileId,
    String? subjectId,
    bool isPrimaryHomeroomTeacher = false,
  }) async {
    final response = await _client.from('class_teachers').insert({
      'school_id': schoolId,
      'class_section_id': classSectionId,
      'teacher_profile_id': teacherProfileId,
      'subject_id': subjectId,
      'is_primary_homeroom_teacher': isPrimaryHomeroomTeacher,
    }).select('*, profiles!class_teachers_teacher_profile_id_fkey(*), subjects(*), class_sections(*, classes(*))').single();

    return ClassTeacherModel.fromMap(response);
  }

  // ── STUDENT ENROLLMENTS ───────────────────
  Future<List<StudentEnrollmentModel>> getEnrollments(String schoolId, {String? classSectionId}) async {
    var query = _client
        .from('student_enrollments')
        .select('*, profiles!student_enrollments_student_profile_id_fkey(*), class_sections(*, classes(*)), academic_years(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (classSectionId != null) {
      query = query.eq('class_section_id', classSectionId);
    }

    final response = await query;
    return response
        .map((m) => StudentEnrollmentModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<StudentEnrollmentModel> enrollStudent({
    required String schoolId,
    required String studentProfileId,
    required String classSectionId,
    required String academicYearId,
    String? rollNumber,
  }) async {
    final response = await _client.from('student_enrollments').upsert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'class_section_id': classSectionId,
      'academic_year_id': academicYearId,
      'roll_number': rollNumber,
      'status': 'active',
    }).select('*, profiles!student_enrollments_student_profile_id_fkey(*), class_sections(*, classes(*)), academic_years(*)').single();

    return StudentEnrollmentModel.fromMap(response);
  }

  // ── PARENT-STUDENT RELATIONSHIPS ─────────
  Future<List<UserRelationshipModel>> getParentStudentRelationships(String schoolId) async {
    final response = await _client
        .from('user_relationships')
        .select('*, parent:profiles!user_relationships_parent_id_fkey(*), student:profiles!user_relationships_student_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    return response
        .map((m) => UserRelationshipModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<UserRelationshipModel> createRelationship({
    required String schoolId,
    required String parentProfileId,
    required String studentProfileId,
    required String relationshipType,
  }) async {
    final response = await _client.from('user_relationships').upsert({
      'school_id': schoolId,
      'parent_id': parentProfileId,
      'student_id': studentProfileId,
      'relationship_type': relationshipType,
    }).select('*, parent:profiles!user_relationships_parent_id_fkey(*), student:profiles!user_relationships_student_id_fkey(*)').single();

    return UserRelationshipModel.fromMap(response);
  }
}


// ─────────────────────────────────────────────────────────────────
// PHASE 3 SERVICES: SCHOOL OPERATIONS & LEAVE
// ─────────────────────────────────────────────────────────────────

class SchoolOperationsService {
  final SupabaseClient _client;

  SchoolOperationsService(this._client);

  // ── DAILY STUDENT ATTENDANCE ──────────────────────────────────

  /// Returns attendance records for [schoolId], optionally filtered by [date]
  /// and/or [classSectionId].
  Future<List<AttendanceEntryModel>> getAttendanceEntries(
    String schoolId, {
    DateTime? date,
    String? classSectionId,
  }) async {
    var query = _client
        .from('daily_attendance')
        .select(
          '*, profiles!daily_attendance_student_profile_id_fkey(*), class_sections(*, classes(*))',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (date != null) {
      query = query.eq('date', date.toIso8601String().split('T')[0]);
    }
    if (classSectionId != null) {
      query = query.eq('class_section_id', classSectionId);
    }

    final response = await query.order('date', ascending: false);
    return (response as List)
        .map((m) => AttendanceEntryModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Upserts (mark or update) a student's attendance record for a given day.
  Future<AttendanceEntryModel> markAttendance({
    required String schoolId,
    required String studentProfileId,
    required String classSectionId,
    required DateTime date,
    required String status,
    String? remarks,
  }) async {
    final response = await _client.from('daily_attendance').upsert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'class_section_id': classSectionId,
      'date': date.toIso8601String().split('T')[0],
      'status': status,
      'remarks': remarks,
    }, onConflict: 'student_profile_id,date').select(
      '*, profiles!daily_attendance_student_profile_id_fkey(*), class_sections(*, classes(*))',
    ).single();

    return AttendanceEntryModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  // ── STAFF ATTENDANCE ─────────────────────────────────────────

  Future<List<StaffAttendanceModel>> getStaffAttendance(
    String schoolId, {
    DateTime? date,
  }) async {
    var query = _client
        .from('staff_attendance')
        .select('*, profiles!staff_attendance_staff_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (date != null) {
      query = query.eq('date', date.toIso8601String().split('T')[0]);
    }

    final response = await query.order('date', ascending: false);
    return (response as List)
        .map((m) => StaffAttendanceModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Records clock-in for today (upsert by staff_profile_id + date).
  Future<StaffAttendanceModel> clockIn(String schoolId, String staffProfileId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await _client.from('staff_attendance').upsert({
      'school_id': schoolId,
      'staff_profile_id': staffProfileId,
      'date': today,
      'clock_in': DateTime.now().toIso8601String(),
      'status': 'present',
    }, onConflict: 'staff_profile_id,date').select(
      '*, profiles!staff_attendance_staff_profile_id_fkey(*)',
    ).single();

    return StaffAttendanceModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Updates clock-out time for today's record.
  Future<StaffAttendanceModel> clockOut(String schoolId, String staffProfileId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await _client
        .from('staff_attendance')
        .update({'clock_out': DateTime.now().toIso8601String()})
        .eq('staff_profile_id', staffProfileId)
        .eq('date', today)
        .select('*, profiles!staff_attendance_staff_profile_id_fkey(*)')
        .single();

    return StaffAttendanceModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  // ── STAFF LEAVE REQUESTS ──────────────────────────────────────

  /// Returns leave requests for [schoolId]. If [staffProfileId] is given,
  /// returns only that staff member's requests (used in teacher view).
  Future<List<StaffLeaveRequestModel>> getLeaveRequests(
    String schoolId, {
    String? staffProfileId,
  }) async {
    var query = _client
        .from('staff_leaves')
        .select(
          '*, staff:profiles!staff_leaves_staff_profile_id_fkey(*), approved_by:profiles!staff_leaves_approved_by_profile_id_fkey(*)',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (staffProfileId != null) {
      query = query.eq('staff_profile_id', staffProfileId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => StaffLeaveRequestModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Submits a new leave request for a staff member.
  Future<StaffLeaveRequestModel> submitLeaveRequest({
    required String schoolId,
    required String staffProfileId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final response = await _client.from('staff_leaves').insert({
      'school_id': schoolId,
      'staff_profile_id': staffProfileId,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'reason': reason,
      'status': 'pending',
    }).select(
      '*, staff:profiles!staff_leaves_staff_profile_id_fkey(*), approved_by:profiles!staff_leaves_approved_by_profile_id_fkey(*)',
    ).single();

    return StaffLeaveRequestModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Approves or rejects a leave request (school admin only).
  Future<StaffLeaveRequestModel> updateLeaveStatus(
    String leaveId,
    String status,
    String approvedByProfileId,
  ) async {
    assert(status == 'approved' || status == 'rejected');
    final response = await _client
        .from('staff_leaves')
        .update({
          'status': status,
          'approved_by_profile_id': approvedByProfileId,
        })
        .eq('id', leaveId)
        .select(
          '*, staff:profiles!staff_leaves_staff_profile_id_fkey(*), approved_by:profiles!staff_leaves_approved_by_profile_id_fkey(*)',
        )
        .single();

    return StaffLeaveRequestModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  // ── ANNOUNCEMENTS ─────────────────────────────────────────────

  /// Returns announcements visible to the current session's role for [schoolId].
  /// RLS on the server enforces target_role visibility automatically.
  Future<List<SchoolAnnouncementModel>> getAnnouncements(String schoolId) async {
    final response = await _client
        .from('announcements')
        .select('*, profiles!announcements_author_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List)
        .map((m) => SchoolAnnouncementModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Posts a new announcement (admin or teacher).
  Future<SchoolAnnouncementModel> createAnnouncement({
    required String schoolId,
    required String title,
    required String content,
    required String targetRole,
    required String authorProfileId,
  }) async {
    final response = await _client.from('announcements').insert({
      'school_id': schoolId,
      'title': title,
      'content': content,
      'target_role': targetRole,
      'author_profile_id': authorProfileId,
    }).select('*, profiles!announcements_author_profile_id_fkey(*)').single();

    return SchoolAnnouncementModel.fromMap(Map<String, dynamic>.from(response as Map));
  }

  // ── TEACHER SECTION HELPER ────────────────────────────────────

  /// Returns the class sections assigned to [teacherProfileId] (via class_teachers).
  Future<List<ClassSectionModel>> getTeacherSections(
    String schoolId,
    String teacherProfileId,
  ) async {
    final response = await _client
        .from('class_teachers')
        .select('class_sections(*, classes(*))')
        .eq('school_id', schoolId)
        .eq('teacher_profile_id', teacherProfileId)
        .isFilter('deleted_at', null);

    final sections = <ClassSectionModel>[];
    final seen = <String>{};
    for (final row in response as List) {
      final sectionMap = (row as Map)['class_sections'];
      if (sectionMap != null) {
        final section = ClassSectionModel.fromMap(
          Map<String, dynamic>.from(sectionMap as Map),
        );
        if (seen.add(section.id)) sections.add(section);
      }
    }
    return sections;
  }
}

// ─────────────────────────────────────────────────────────────────
// PHASE 4 SERVICES: GRADEBOOK, REPORT CARDS & LMS
// ─────────────────────────────────────────────────────────────────

class AcademicGradebookService {
  final SupabaseClient _client;

  AcademicGradebookService(this._client);

  // ── GRADING TERMS ──────────────────────────────────────────────
  Future<List<GradingTermModel>> getGradingTerms(String schoolId) async {
    final response = await _client
        .from('grading_terms')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);

    return (response as List)
        .map((m) => GradingTermModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<GradingTermModel> createGradingTerm({
    required String schoolId,
    required String academicYearId,
    required String name,
    double weight = 1.0,
  }) async {
    final response = await _client.from('grading_terms').insert({
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'name': name,
      'weight': weight,
    }).select().single();

    return GradingTermModel.fromMap(response);
  }

  // ── ASSESSMENT CATEGORIES ──────────────────────────────────────
  Future<List<AssessmentCategoryModel>> getAssessmentCategories(String schoolId) async {
    final response = await _client
        .from('assessment_categories')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);

    return (response as List)
        .map((m) => AssessmentCategoryModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<AssessmentCategoryModel> createAssessmentCategory({
    required String schoolId,
    required String name,
    double weight = 1.0,
  }) async {
    final response = await _client.from('assessment_categories').insert({
      'school_id': schoolId,
      'name': name,
      'weight': weight,
    }).select().single();

    return AssessmentCategoryModel.fromMap(response);
  }

  // ── ASSESSMENTS ────────────────────────────────────────────────
  Future<List<AssessmentModel>> getAssessments(
    String schoolId, {
    String? classSectionId,
    String? subjectId,
    String? termId,
  }) async {
    var query = _client
        .from('assessments')
        .select(
          '*, subjects(*), class_sections(*, classes(*)), grading_terms(*), assessment_categories(*)',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (classSectionId != null) query = query.eq('class_section_id', classSectionId);
    if (subjectId != null) query = query.eq('subject_id', subjectId);
    if (termId != null) query = query.eq('term_id', termId);

    final response = await query.order('date_administered', ascending: false);
    return (response as List)
        .map((m) => AssessmentModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<AssessmentModel> createAssessment({
    required String schoolId,
    required String classSectionId,
    required String subjectId,
    required String termId,
    required String categoryId,
    required String title,
    required double maxPoints,
    required DateTime dateAdministered,
  }) async {
    final response = await _client.from('assessments').insert({
      'school_id': schoolId,
      'class_section_id': classSectionId,
      'subject_id': subjectId,
      'term_id': termId,
      'category_id': categoryId,
      'title': title,
      'max_points': maxPoints,
      'date_administered': dateAdministered.toIso8601String().split('T')[0],
    }).select(
      '*, subjects(*), class_sections(*, classes(*)), grading_terms(*), assessment_categories(*)',
    ).single();

    return AssessmentModel.fromMap(response);
  }

  // ── GRADE RECORDS ──────────────────────────────────────────────
  Future<List<GradeRecordModel>> getGradeRecords(String assessmentId) async {
    final response = await _client
        .from('grade_records')
        .select('*, profiles!grade_records_student_profile_id_fkey(*), assessments(*)')
        .eq('assessment_id', assessmentId)
        .isFilter('deleted_at', null);

    return (response as List)
        .map((m) => GradeRecordModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<List<GradeRecordModel>> getStudentGrades(String studentProfileId) async {
    final response = await _client
        .from('grade_records')
        .select('*, assessments(*, subjects(*), grading_terms(*), assessment_categories(*))')
        .eq('student_profile_id', studentProfileId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List)
        .map((m) => GradeRecordModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> saveGradeRecord({
    required String schoolId,
    required String assessmentId,
    required String studentProfileId,
    required double pointsObtained,
    String? remarks,
  }) async {
    await _client.from('grade_records').upsert({
      'school_id': schoolId,
      'assessment_id': assessmentId,
      'student_profile_id': studentProfileId,
      'points_obtained': pointsObtained,
      'teacher_remarks': remarks,
    }, onConflict: 'assessment_id,student_profile_id');
  }

  // ── REPORT CARDS ───────────────────────────────────────────────
  Future<List<ReportCardModel>> getReportCards(
    String schoolId, {
    String? studentProfileId,
    String? termId,
  }) async {
    var query = _client
        .from('report_cards')
        .select(
          '*, profiles!report_cards_student_profile_id_fkey(*), academic_years(*), grading_terms(*)',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (studentProfileId != null) query = query.eq('student_profile_id', studentProfileId);
    if (termId != null) query = query.eq('term_id', termId);

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => ReportCardModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<ReportCardModel> generateReportCard({
    required String schoolId,
    required String studentProfileId,
    required String academicYearId,
    required String termId,
    double? gpa,
    String? teacherComments,
  }) async {
    final response = await _client.from('report_cards').upsert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'academic_year_id': academicYearId,
      'term_id': termId,
      'gpa': gpa,
      'teacher_comments': teacherComments,
      'principal_approved': false,
    }, onConflict: 'student_profile_id,academic_year_id,term_id').select(
      '*, profiles!report_cards_student_profile_id_fkey(*), academic_years(*), grading_terms(*)',
    ).single();

    return ReportCardModel.fromMap(response);
  }

  Future<void> setReportCardApproval(String reportCardId, bool approved) async {
    await _client
        .from('report_cards')
        .update({'principal_approved': approved})
        .eq('id', reportCardId);
  }
}

class LmsService {
  final SupabaseClient _client;

  LmsService(this._client);

  // ── COURSES ───────────────────────────────────────────────────
  Future<List<CourseModel>> getCourses(String schoolId, {String? teacherProfileId}) async {
    var query = _client
        .from('courses')
        .select('*, profiles!courses_teacher_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (teacherProfileId != null) {
      query = query.eq('teacher_profile_id', teacherProfileId);
    }

    final response = await query.order('name', ascending: true);
    return (response as List)
        .map((m) => CourseModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<CourseModel> createCourse({
    required String schoolId,
    required String name,
    String? description,
    String? teacherProfileId,
  }) async {
    final response = await _client.from('courses').insert({
      'school_id': schoolId,
      'name': name,
      'description': description,
      'teacher_profile_id': teacherProfileId,
    }).select('*, profiles!courses_teacher_profile_id_fkey(*)').single();

    return CourseModel.fromMap(response);
  }

  // ── LESSONS ───────────────────────────────────────────────────
  Future<List<LessonModel>> getLessons(String schoolId, String courseId) async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('school_id', schoolId)
        .eq('course_id', courseId)
        .isFilter('deleted_at', null)
        .order('order_index', ascending: true);

    return (response as List)
        .map((m) => LessonModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<LessonModel> createLesson({
    required String schoolId,
    required String courseId,
    required String title,
    String? contentUrl,
    int orderIndex = 0,
  }) async {
    final response = await _client.from('lessons').insert({
      'school_id': schoolId,
      'course_id': courseId,
      'title': title,
      'content_url': contentUrl,
      'order_index': orderIndex,
    }).select().single();

    return LessonModel.fromMap(response);
  }

  // ── ASSIGNMENTS ───────────────────────────────────────────────
  Future<List<AssignmentModel>> getAssignments(String schoolId, {String? lessonId}) async {
    var query = _client
        .from('assignments')
        .select('*, lessons(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (lessonId != null) query = query.eq('lesson_id', lessonId);

    final response = await query.order('due_date', ascending: false);
    return (response as List)
        .map((m) => AssignmentModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<AssignmentModel> createAssignment({
    required String schoolId,
    required String lessonId,
    required String title,
    String? description,
    required DateTime dueDate,
    required double maxPoints,
  }) async {
    final response = await _client.from('assignments').insert({
      'school_id': schoolId,
      'lesson_id': lessonId,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'max_points': maxPoints,
    }).select('*, lessons(*)').single();

    return AssignmentModel.fromMap(response);
  }

  // ── SUBMISSIONS ───────────────────────────────────────────────
  Future<List<SubmissionModel>> getSubmissions(String assignmentId) async {
    final response = await _client
        .from('submissions')
        .select(
          '*, profiles!submissions_student_profile_id_fkey(*), assignments(*), graded_by:profiles!submissions_graded_by_profile_id_fkey(*)',
        )
        .eq('assignment_id', assignmentId)
        .isFilter('deleted_at', null);

    return (response as List)
        .map((m) => SubmissionModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<SubmissionModel> submitAssignment({
    required String schoolId,
    required String assignmentId,
    required String studentProfileId,
    required String contentUrl,
  }) async {
    final response = await _client.from('submissions').upsert({
      'school_id': schoolId,
      'assignment_id': assignmentId,
      'student_profile_id': studentProfileId,
      'content_url': contentUrl,
      'submitted_at': DateTime.now().toIso8601String(),
    }, onConflict: 'assignment_id,student_profile_id').select(
      '*, profiles!submissions_student_profile_id_fkey(*), assignments(*)',
    ).single();

    return SubmissionModel.fromMap(response);
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
    required String gradedByProfileId,
  }) async {
    await _client.from('submissions').update({
      'grade': grade,
      'feedback': feedback,
      'graded_by_profile_id': gradedByProfileId,
    }).eq('id', submissionId);
  }
}

// ─────────────────────────────────────────────────────────────────
// PHASE 5 SERVICES: BUS TRACKING, MARKETPLACE & AI TUTOR
// ─────────────────────────────────────────────────────────────────

class BusTrackingService {
  final SupabaseClient _client;

  BusTrackingService(this._client);

  // ── ROUTES ────────────────────────────────────────────────────
  Future<List<BusRouteModel>> getBusRoutes(String schoolId) async {
    final response = await _client
        .from('bus_routes')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('route_name', ascending: true);

    return (response as List)
        .map((m) => BusRouteModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<BusRouteModel> createBusRoute({
    required String schoolId,
    required String routeName,
    String? driverName,
    String? driverPhone,
    required String vehicleNumber,
  }) async {
    final response = await _client.from('bus_routes').insert({
      'school_id': schoolId,
      'route_name': routeName,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'vehicle_number': vehicleNumber,
    }).select().single();

    return BusRouteModel.fromMap(response);
  }

  // ── STOPS ─────────────────────────────────────────────────────
  Future<List<BusStopModel>> getBusStops(String schoolId, String routeId) async {
    final response = await _client
        .from('bus_stops')
        .select()
        .eq('school_id', schoolId)
        .eq('route_id', routeId)
        .isFilter('deleted_at', null)
        .order('order_index', ascending: true);

    return (response as List)
        .map((m) => BusStopModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<BusStopModel> createBusStop({
    required String schoolId,
    required String routeId,
    required String stopName,
    required double latitude,
    required double longitude,
    int orderIndex = 0,
  }) async {
    final response = await _client.from('bus_stops').insert({
      'school_id': schoolId,
      'route_id': routeId,
      'stop_name': stopName,
      'latitude': latitude,
      'longitude': longitude,
      'order_index': orderIndex,
    }).select().single();

    return BusStopModel.fromMap(response);
  }

  // ── STUDENTS ──────────────────────────────────────────────────
  Future<List<BusStudentModel>> getBusStudents(String schoolId, {String? routeId}) async {
    var query = _client
        .from('bus_students')
        .select('*, profiles!bus_students_student_profile_id_fkey(*), bus_routes(*), bus_stops(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (routeId != null) query = query.eq('route_id', routeId);

    final response = await query;
    return (response as List)
        .map((m) => BusStudentModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  // ── TELEMETRY ─────────────────────────────────────────────────
  Future<BusTelemetryModel?> getLatestTelemetry(String schoolId, String routeId) async {
    final response = await _client
        .from('bus_telemetry')
        .select()
        .eq('school_id', schoolId)
        .eq('route_id', routeId)
        .isFilter('deleted_at', null)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return BusTelemetryModel.fromMap(response);
  }

  Future<BusTelemetryModel> sendTelemetryPing({
    required String schoolId,
    required String routeId,
    required double latitude,
    required double longitude,
    required double speed,
  }) async {
    final response = await _client.from('bus_telemetry').insert({
      'school_id': schoolId,
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'recorded_at': DateTime.now().toIso8601String(),
    }).select().single();

    return BusTelemetryModel.fromMap(response);
  }
}

class MarketplaceService {
  final SupabaseClient _client;

  MarketplaceService(this._client);

  // ── ITEMS ─────────────────────────────────────────────────────
  Future<List<MarketplaceItemModel>> getItems(String schoolId, {String? status}) async {
    var query = _client
        .from('marketplace_items')
        .select('*, profiles!marketplace_items_seller_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (status != null) {
      query = query.eq('status', status);
    } else {
      query = query.neq('status', 'hidden');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => MarketplaceItemModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<MarketplaceItemModel> createItem({
    required String schoolId,
    required String title,
    String? description,
    required double price,
    int stockQuantity = 1,
    String? imageUrl,
    required String sellerProfileId,
  }) async {
    final response = await _client.from('marketplace_items').insert({
      'school_id': schoolId,
      'title': title,
      'description': description,
      'price': price,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'seller_profile_id': sellerProfileId,
      'status': 'available',
    }).select('*, profiles!marketplace_items_seller_profile_id_fkey(*)').single();

    return MarketplaceItemModel.fromMap(response);
  }

  // ── ORDERS ────────────────────────────────────────────────────
  Future<List<MarketplaceOrderModel>> getOrders(String schoolId, {String? buyerProfileId}) async {
    var query = _client
        .from('marketplace_orders')
        .select('*, profiles!marketplace_orders_buyer_profile_id_fkey(*), marketplace_order_items(*, marketplace_items(*))')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (buyerProfileId != null) query = query.eq('buyer_profile_id', buyerProfileId);

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => MarketplaceOrderModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<MarketplaceOrderModel> placeOrder({
    required String schoolId,
    required String buyerProfileId,
    required double totalAmount,
    required List<Map<String, dynamic>> items, // [{'item_id': String, 'quantity': int, 'price': double}]
  }) async {
    final orderRes = await _client.from('marketplace_orders').insert({
      'school_id': schoolId,
      'buyer_profile_id': buyerProfileId,
      'total_amount': totalAmount,
      'status': 'pending',
    }).select('*, profiles!marketplace_orders_buyer_profile_id_fkey(*)').single();

    final order = MarketplaceOrderModel.fromMap(orderRes);

    for (final item in items) {
      await _client.from('marketplace_order_items').insert({
        'school_id': schoolId,
        'order_id': order.id,
        'item_id': item['item_id'],
        'quantity': item['quantity'],
        'price_at_purchase': item['price'],
      });
    }

    return order;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client
        .from('marketplace_orders')
        .update({'status': status})
        .eq('id', orderId);
  }
}

// ─────────────────────────────────────────────────────────────────
// PHASE 6 SERVICE: SCHOOL FINANCE
// ─────────────────────────────────────────────────────────────────

class SchoolFinanceService {
  final SupabaseClient _client;

  SchoolFinanceService(this._client);

  // ── FEE TYPES ────────────────────────────────────────────────
  Future<List<FeeTypeModel>> getFeeTypes(String schoolId) async {
    final response = await _client
        .from('fee_types')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('name', ascending: true);

    return (response as List)
        .map((m) => FeeTypeModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<FeeTypeModel> createFeeType({
    required String schoolId,
    required String name,
    String? description,
    required double amount,
  }) async {
    final response = await _client.from('fee_types').insert({
      'school_id': schoolId,
      'name': name,
      'description': description,
      'amount': amount,
    }).select().single();

    return FeeTypeModel.fromMap(response);
  }

  // ── INVOICES ──────────────────────────────────────────────────
  Future<List<InvoiceModel>> getInvoices(String schoolId, {String? studentProfileId}) async {
    var query = _client
        .from('invoices')
        .select('*, profiles!invoices_student_profile_id_fkey(*), academic_years(*), invoice_items(*, fee_types(*))')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (studentProfileId != null) {
      query = query.eq('student_profile_id', studentProfileId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => InvoiceModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<InvoiceModel> createInvoice({
    required String schoolId,
    required String studentProfileId,
    required String academicYearId,
    required double totalAmount,
    required DateTime dueDate,
    required List<Map<String, dynamic>> items, // [{'fee_type_id': str, 'amount': double}]
  }) async {
    final invoiceRes = await _client.from('invoices').insert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'academic_year_id': academicYearId,
      'total_amount': totalAmount,
      'paid_amount': 0.0,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'status': 'unpaid',
    }).select('*, profiles!invoices_student_profile_id_fkey(*), academic_years(*)').single();

    final invoice = InvoiceModel.fromMap(invoiceRes);

    for (final item in items) {
      await _client.from('invoice_items').insert({
        'school_id': schoolId,
        'invoice_id': invoice.id,
        'fee_type_id': item['fee_type_id'],
        'amount': item['amount'],
      });
    }

    return invoice;
  }

  // Batch-generate invoices for all enrolled students in a class section
  Future<int> generateBatchInvoices({
    required String schoolId,
    required String classSectionId,
    required String academicYearId,
    required List<Map<String, dynamic>> feeItems,
    required DateTime dueDate,
  }) async {
    // Get enrolled students in the class section
    final enrollments = await _client
        .from('student_enrollments')
        .select('student_profile_id')
        .eq('school_id', schoolId)
        .eq('class_section_id', classSectionId)
        .isFilter('deleted_at', null);

    final students = (enrollments as List)
        .map((e) => e['student_profile_id'] as String)
        .toList();

    final totalAmount = feeItems.fold<double>(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

    for (final studentId in students) {
      await createInvoice(
        schoolId: schoolId,
        studentProfileId: studentId,
        academicYearId: academicYearId,
        totalAmount: totalAmount,
        dueDate: dueDate,
        items: feeItems,
      );
    }

    return students.length;
  }

  // ── PAYMENTS ──────────────────────────────────────────────────
  Future<PaymentModel> recordPayment({
    required String schoolId,
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    required double currentPaidAmount,
    required double totalAmount,
  }) async {
    final txRef = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

    final paymentRes = await _client.from('payments').insert({
      'school_id': schoolId,
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_reference': txRef,
      'paid_at': DateTime.now().toIso8601String(),
    }).select().single();

    // Update invoice paid_amount and status
    final newPaidAmount = currentPaidAmount + amount;
    final newStatus = newPaidAmount >= totalAmount ? 'paid' : 'partial';

    await _client.from('invoices').update({
      'paid_amount': newPaidAmount,
      'status': newStatus,
    }).eq('id', invoiceId);

    return PaymentModel.fromMap(paymentRes);
  }

  // ── BURSARIES ─────────────────────────────────────────────────
  Future<List<BursaryModel>> getBursaries(String schoolId) async {
    final response = await _client
        .from('bursaries')
        .select()
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('name', ascending: true);

    return (response as List)
        .map((m) => BursaryModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<BursaryModel> createBursary({
    required String schoolId,
    required String name,
    double? discountPercentage,
    double? discountAmount,
  }) async {
    final response = await _client.from('bursaries').insert({
      'school_id': schoolId,
      'name': name,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
    }).select().single();

    return BursaryModel.fromMap(response);
  }

  Future<List<StudentBursaryModel>> getStudentBursaries(String schoolId, {String? studentProfileId}) async {
    var query = _client
        .from('student_bursaries')
        .select('*, profiles!student_bursaries_student_profile_id_fkey(*), bursaries(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (studentProfileId != null) {
      query = query.eq('student_profile_id', studentProfileId);
    }

    final response = await query;
    return (response as List)
        .map((m) => StudentBursaryModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<StudentBursaryModel> assignStudentBursary({
    required String schoolId,
    required String studentProfileId,
    required String bursaryId,
    required String academicYearId,
  }) async {
    final response = await _client.from('student_bursaries').upsert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'bursary_id': bursaryId,
      'academic_year_id': academicYearId,
    }, onConflict: 'student_profile_id,bursary_id,academic_year_id')
        .select('*, profiles!student_bursaries_student_profile_id_fkey(*), bursaries(*)')
        .single();

    return StudentBursaryModel.fromMap(response);
  }

  // ── STAFF PAYROLL ─────────────────────────────────────────────
  Future<List<StaffPayrollModel>> getStaffPayroll(String schoolId) async {
    final response = await _client
        .from('staff_payroll')
        .select('*, profiles!staff_payroll_staff_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('payment_date', ascending: false);

    return (response as List)
        .map((m) => StaffPayrollModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<StaffPayrollModel> createPayrollEntry({
    required String schoolId,
    required String staffProfileId,
    required double baseSalary,
    double allowances = 0.0,
    double deductions = 0.0,
    required DateTime paymentDate,
  }) async {
    final response = await _client.from('staff_payroll').insert({
      'school_id': schoolId,
      'staff_profile_id': staffProfileId,
      'base_salary': baseSalary,
      'allowances': allowances,
      'deductions': deductions,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'status': 'pending',
    }).select('*, profiles!staff_payroll_staff_profile_id_fkey(*)').single();

    return StaffPayrollModel.fromMap(response);
  }

  Future<void> processPayroll(String payrollId) async {
    await _client
        .from('staff_payroll')
        .update({'status': 'processed'})
        .eq('id', payrollId);
  }

  // ── EXPENSES ──────────────────────────────────────────────────
  Future<List<ExpenseModel>> getExpenses(String schoolId) async {
    final response = await _client
        .from('expenses')
        .select('*, profiles!expenses_spent_by_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('spent_at', ascending: false);

    return (response as List)
        .map((m) => ExpenseModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<ExpenseModel> logExpense({
    required String schoolId,
    required String title,
    required String category,
    required double amount,
    required String spentByProfileId,
    required DateTime spentAt,
  }) async {
    final response = await _client.from('expenses').insert({
      'school_id': schoolId,
      'title': title,
      'category': category,
      'amount': amount,
      'spent_by_profile_id': spentByProfileId,
      'spent_at': spentAt.toIso8601String().split('T')[0],
    }).select('*, profiles!expenses_spent_by_profile_id_fkey(*)').single();

    return ExpenseModel.fromMap(response);
  }

  // ── BUDGETS ───────────────────────────────────────────────────
  Future<List<BudgetModel>> getBudgets(String schoolId, String academicYearId) async {
    final response = await _client
        .from('budgets')
        .select()
        .eq('school_id', schoolId)
        .eq('academic_year_id', academicYearId)
        .isFilter('deleted_at', null)
        .order('department_name', ascending: true);

    return (response as List)
        .map((m) => BudgetModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<BudgetModel> createBudget({
    required String schoolId,
    required String departmentName,
    required String academicYearId,
    required double allocatedAmount,
  }) async {
    final response = await _client.from('budgets').upsert({
      'school_id': schoolId,
      'department_name': departmentName,
      'academic_year_id': academicYearId,
      'allocated_amount': allocatedAmount,
      'spent_amount': 0.0,
    }, onConflict: 'school_id,department_name,academic_year_id').select().single();

    return BudgetModel.fromMap(response);
  }
}





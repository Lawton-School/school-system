// Core data models for Phase 1 & Phase 2 - Auth, Profiles & Academic Structure

class SchoolModel {
  final String id;
  final String name;
  final String subdomain;
  final Map<String, dynamic> settings;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.subdomain,
    required this.settings,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    return SchoolModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      subdomain: (map['subdomain'] as String?) ?? '',
      settings: (map['settings'] as Map<String, dynamic>?) ?? {},
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subdomain': subdomain,
        'settings': settings,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isActive => status == 'active';

  @override
  String toString() => 'SchoolModel(id: $id, name: $name, subdomain: $subdomain)';
}

class ProfileModel {
  final String id;
  final String? userId;
  final String schoolId;
  final String role;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined / transient
  final SchoolModel? school;

  const ProfileModel({
    required this.id,
    this.userId,
    required this.schoolId,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.school,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] as String?) ?? '',
      userId: map['user_id'] as String?,
      schoolId: (map['school_id'] as String?) ?? '',
      role: (map['role'] as String?) ?? '',
      firstName: (map['first_name'] as String?) ?? '',
      lastName: (map['last_name'] as String?) ?? '',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      school: map['schools'] != null && map['schools'] is Map
          ? SchoolModel.fromMap(Map<String, dynamic>.from(map['schools'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'school_id': schoolId,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get fullName => '$firstName $lastName';
  bool get isActive => status == 'active';

  @override
  String toString() => 'ProfileModel(id: $id, name: $fullName, role: $role, schoolId: $schoolId)';
}

/// Represents the active session context a user has chosen (school + role).
class ActiveSession {
  final String schoolId;
  final String schoolName;
  final String profileId;
  final String role;

  const ActiveSession({
    required this.schoolId,
    required this.schoolName,
    required this.profileId,
    required this.role,
  });

  @override
  String toString() =>
      'ActiveSession(school: $schoolName, profile: $profileId, role: $role)';
}

// ─────────────────────────────────────────────────────────────────
// PHASE 2 MODELS: ACADEMIC STRUCTURE & ENROLLMENTS
// ─────────────────────────────────────────────────────────────────

class AcademicYearModel {
  final String id;
  final String schoolId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicYearModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicYearModel.fromMap(Map<String, dynamic> map) {
    return AcademicYearModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isCurrent: (map['is_current'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'is_current': isCurrent,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ClassModel {
  final String id;
  final String schoolId;
  final String name;
  final String academicYearId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final AcademicYearModel? academicYear;

  const ClassModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.academicYearId,
    required this.createdAt,
    required this.updatedAt,
    this.academicYear,
  });

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      academicYearId: map['academic_year_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      academicYear: map['academic_years'] != null
          ? AcademicYearModel.fromMap(map['academic_years'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'academic_year_id': academicYearId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ClassSectionModel {
  final String id;
  final String schoolId;
  final String classId;
  final String name;
  final String? room;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ClassModel? classModel;

  const ClassSectionModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.name,
    this.room,
    required this.createdAt,
    required this.updatedAt,
    this.classModel,
  });

  factory ClassSectionModel.fromMap(Map<String, dynamic> map) {
    return ClassSectionModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      classId: map['class_id'] as String,
      name: map['name'] as String,
      room: map['room'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      classModel: map['classes'] != null
          ? ClassModel.fromMap(map['classes'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'class_id': classId,
        'name': name,
        'room': room,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get displayName => classModel != null ? '${classModel!.name} - $name' : name;
}

class SubjectModel {
  final String id;
  final String schoolId;
  final String name;
  final String? code;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubjectModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.code,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      code: map['code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'code': code,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ClassTeacherModel {
  final String id;
  final String schoolId;
  final String classSectionId;
  final String teacherProfileId;
  final String? subjectId;
  final bool isPrimaryHomeroomTeacher;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? teacher;
  final SubjectModel? subject;
  final ClassSectionModel? section;

  const ClassTeacherModel({
    required this.id,
    required this.schoolId,
    required this.classSectionId,
    required this.teacherProfileId,
    this.subjectId,
    required this.isPrimaryHomeroomTeacher,
    required this.createdAt,
    required this.updatedAt,
    this.teacher,
    this.subject,
    this.section,
  });

  factory ClassTeacherModel.fromMap(Map<String, dynamic> map) {
    return ClassTeacherModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      classSectionId: map['class_section_id'] as String,
      teacherProfileId: map['teacher_profile_id'] as String,
      subjectId: map['subject_id'] as String?,
      isPrimaryHomeroomTeacher: (map['is_primary_homeroom_teacher'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      teacher: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      subject: map['subjects'] != null
          ? SubjectModel.fromMap(map['subjects'] as Map<String, dynamic>)
          : null,
      section: map['class_sections'] != null
          ? ClassSectionModel.fromMap(map['class_sections'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'class_section_id': classSectionId,
        'teacher_profile_id': teacherProfileId,
        'subject_id': subjectId,
        'is_primary_homeroom_teacher': isPrimaryHomeroomTeacher,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class StudentEnrollmentModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String classSectionId;
  final String academicYearId;
  final String? rollNumber;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final ClassSectionModel? section;
  final AcademicYearModel? academicYear;

  const StudentEnrollmentModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.classSectionId,
    required this.academicYearId,
    this.rollNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.section,
    this.academicYear,
  });

  factory StudentEnrollmentModel.fromMap(Map<String, dynamic> map) {
    return StudentEnrollmentModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      classSectionId: map['class_section_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      rollNumber: map['roll_number'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      section: map['class_sections'] != null
          ? ClassSectionModel.fromMap(map['class_sections'] as Map<String, dynamic>)
          : null,
      academicYear: map['academic_years'] != null
          ? AcademicYearModel.fromMap(map['academic_years'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'class_section_id': classSectionId,
        'academic_year_id': academicYearId,
        'roll_number': rollNumber,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class UserRelationshipModel {
  final String id;
  final String schoolId;
  final String parentId;
  final String studentId;
  final String relationshipType;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? parent;
  final ProfileModel? student;

  const UserRelationshipModel({
    required this.id,
    required this.schoolId,
    required this.parentId,
    required this.studentId,
    required this.relationshipType,
    required this.createdAt,
    required this.updatedAt,
    this.parent,
    this.student,
  });

  factory UserRelationshipModel.fromMap(Map<String, dynamic> map) {
    return UserRelationshipModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      parentId: map['parent_id'] as String,
      studentId: map['student_id'] as String,
      relationshipType: map['relationship_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      parent: map['parent'] != null
          ? ProfileModel.fromMap(map['parent'] as Map<String, dynamic>)
          : null,
      student: map['student'] != null
          ? ProfileModel.fromMap(map['student'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'parent_id': parentId,
        'student_id': studentId,
        'relationship_type': relationshipType,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────
// PHASE 3 MODELS: SCHOOL OPERATIONS & LEAVE
// ─────────────────────────────────────────────────────────────────

class AttendanceEntryModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String classSectionId;
  final DateTime date;
  final String status; // present | absent | late | excused
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final ClassSectionModel? section;

  const AttendanceEntryModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.classSectionId,
    required this.date,
    required this.status,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.section,
  });

  factory AttendanceEntryModel.fromMap(Map<String, dynamic> map) {
    return AttendanceEntryModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      classSectionId: map['class_section_id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: map['status'] as String,
      remarks: map['remarks'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      section: map['class_sections'] != null
          ? ClassSectionModel.fromMap(map['class_sections'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'class_section_id': classSectionId,
        'date': date.toIso8601String().split('T')[0],
        'status': status,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get studentName => student?.fullName ?? studentProfileId;
  String get sectionName => section?.displayName ?? classSectionId;
  String get dateLabel {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class StaffAttendanceModel {
  final String id;
  final String schoolId;
  final String staffProfileId;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String status; // present | late | absent
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? staff;

  const StaffAttendanceModel({
    required this.id,
    required this.schoolId,
    required this.staffProfileId,
    required this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.staff,
  });

  factory StaffAttendanceModel.fromMap(Map<String, dynamic> map) {
    return StaffAttendanceModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      staffProfileId: map['staff_profile_id'] as String,
      date: DateTime.parse(map['date'] as String),
      clockIn: map['clock_in'] != null ? DateTime.parse(map['clock_in'] as String) : null,
      clockOut: map['clock_out'] != null ? DateTime.parse(map['clock_out'] as String) : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      staff: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'staff_profile_id': staffProfileId,
        'date': date.toIso8601String().split('T')[0],
        'clock_in': clockIn?.toIso8601String(),
        'clock_out': clockOut?.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get staffName => staff?.fullName ?? staffProfileId;

  String get clockInLabel {
    if (clockIn == null) return '—';
    return '${clockIn!.hour.toString().padLeft(2, '0')}:${clockIn!.minute.toString().padLeft(2, '0')}';
  }

  String get clockOutLabel {
    if (clockOut == null) return '—';
    return '${clockOut!.hour.toString().padLeft(2, '0')}:${clockOut!.minute.toString().padLeft(2, '0')}';
  }
}

class StaffLeaveRequestModel {
  final String id;
  final String schoolId;
  final String staffProfileId;
  final String leaveType; // sick | annual | unpaid | other
  final DateTime startDate;
  final DateTime endDate;
  final String status; // pending | approved | rejected
  final String? reason;
  final String? approvedByProfileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? staff;
  final ProfileModel? approvedBy;

  const StaffLeaveRequestModel({
    required this.id,
    required this.schoolId,
    required this.staffProfileId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.approvedByProfileId,
    required this.createdAt,
    required this.updatedAt,
    this.staff,
    this.approvedBy,
  });

  factory StaffLeaveRequestModel.fromMap(Map<String, dynamic> map) {
    return StaffLeaveRequestModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      staffProfileId: map['staff_profile_id'] as String,
      leaveType: map['leave_type'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      status: map['status'] as String,
      reason: map['reason'] as String?,
      approvedByProfileId: map['approved_by_profile_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      staff: map['staff'] != null
          ? ProfileModel.fromMap(map['staff'] as Map<String, dynamic>)
          : null,
      approvedBy: map['approved_by'] != null
          ? ProfileModel.fromMap(map['approved_by'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'staff_profile_id': staffProfileId,
        'leave_type': leaveType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'status': status,
        'reason': reason,
        'approved_by_profile_id': approvedByProfileId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get employeeName => staff?.fullName ?? staffProfileId;
  String get dateRange => '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}';
}

class SchoolAnnouncementModel {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final String? authorProfileId;
  final String targetRole; // all | teachers | parents | students
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? author;

  const SchoolAnnouncementModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    this.authorProfileId,
    required this.targetRole,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory SchoolAnnouncementModel.fromMap(Map<String, dynamic> map) {
    return SchoolAnnouncementModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      authorProfileId: map['author_profile_id'] as String?,
      targetRole: map['target_role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      author: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'title': title,
        'content': content,
        'author_profile_id': authorProfileId,
        'target_role': targetRole,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // Compatibility getters for existing UI code
  String get message => content;
  String get audience => targetRole;
  String get createdBy => author?.fullName ?? 'Unknown';
  String get createdAtLabel => '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}

// ─────────────────────────────────────────────────────────────────
// PHASE 4 MODELS: GRADEBOOK, REPORT CARDS & LMS
// ─────────────────────────────────────────────────────────────────

class GradingTermModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String name; // e.g. "Term 1"
  final double weight;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradingTermModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.name,
    required this.weight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GradingTermModel.fromMap(Map<String, dynamic> map) {
    return GradingTermModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      name: map['name'] as String,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'name': name,
        'weight': weight,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AssessmentCategoryModel {
  final String id;
  final String schoolId;
  final String name; // e.g. "Exams", "Homework", "CALA", "Coursework"
  final double weight;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssessmentCategoryModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.weight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssessmentCategoryModel.fromMap(Map<String, dynamic> map) {
    return AssessmentCategoryModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'weight': weight,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AssessmentModel {
  final String id;
  final String schoolId;
  final String classSectionId;
  final String subjectId;
  final String termId;
  final String categoryId;
  final String title;
  final double maxPoints;
  final DateTime dateAdministered;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final SubjectModel? subject;
  final ClassSectionModel? section;
  final GradingTermModel? term;
  final AssessmentCategoryModel? category;

  const AssessmentModel({
    required this.id,
    required this.schoolId,
    required this.classSectionId,
    required this.subjectId,
    required this.termId,
    required this.categoryId,
    required this.title,
    required this.maxPoints,
    required this.dateAdministered,
    required this.createdAt,
    required this.updatedAt,
    this.subject,
    this.section,
    this.term,
    this.category,
  });

  factory AssessmentModel.fromMap(Map<String, dynamic> map) {
    return AssessmentModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      classSectionId: map['class_section_id'] as String,
      subjectId: map['subject_id'] as String,
      termId: map['term_id'] as String,
      categoryId: map['category_id'] as String,
      title: map['title'] as String,
      maxPoints: (map['max_points'] as num).toDouble(),
      dateAdministered: DateTime.parse(map['date_administered'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      subject: map['subjects'] != null
          ? SubjectModel.fromMap(map['subjects'] as Map<String, dynamic>)
          : null,
      section: map['class_sections'] != null
          ? ClassSectionModel.fromMap(map['class_sections'] as Map<String, dynamic>)
          : null,
      term: map['grading_terms'] != null
          ? GradingTermModel.fromMap(map['grading_terms'] as Map<String, dynamic>)
          : null,
      category: map['assessment_categories'] != null
          ? AssessmentCategoryModel.fromMap(map['assessment_categories'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'class_section_id': classSectionId,
        'subject_id': subjectId,
        'term_id': termId,
        'category_id': categoryId,
        'title': title,
        'max_points': maxPoints,
        'date_administered': dateAdministered.toIso8601String().split('T')[0],
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class GradeRecordModel {
  final String id;
  final String schoolId;
  final String assessmentId;
  final String studentProfileId;
  final double pointsObtained;
  final String? teacherRemarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final AssessmentModel? assessment;

  const GradeRecordModel({
    required this.id,
    required this.schoolId,
    required this.assessmentId,
    required this.studentProfileId,
    required this.pointsObtained,
    this.teacherRemarks,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.assessment,
  });

  factory GradeRecordModel.fromMap(Map<String, dynamic> map) {
    return GradeRecordModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      assessmentId: map['assessment_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      pointsObtained: (map['points_obtained'] as num).toDouble(),
      teacherRemarks: map['teacher_remarks'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      assessment: map['assessments'] != null
          ? AssessmentModel.fromMap(map['assessments'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'assessment_id': assessmentId,
        'student_profile_id': studentProfileId,
        'points_obtained': pointsObtained,
        'teacher_remarks': teacherRemarks,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ReportCardModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String academicYearId;
  final String termId;
  final double? gpa;
  final String? teacherComments;
  final bool principalApproved;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final AcademicYearModel? academicYear;
  final GradingTermModel? term;

  const ReportCardModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.academicYearId,
    required this.termId,
    this.gpa,
    this.teacherComments,
    required this.principalApproved,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.academicYear,
    this.term,
  });

  factory ReportCardModel.fromMap(Map<String, dynamic> map) {
    return ReportCardModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      termId: map['term_id'] as String,
      gpa: (map['gpa'] as num?)?.toDouble(),
      teacherComments: map['teacher_comments'] as String?,
      principalApproved: (map['principal_approved'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      academicYear: map['academic_years'] != null
          ? AcademicYearModel.fromMap(map['academic_years'] as Map<String, dynamic>)
          : null,
      term: map['grading_terms'] != null
          ? GradingTermModel.fromMap(map['grading_terms'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'academic_year_id': academicYearId,
        'term_id': termId,
        'gpa': gpa,
        'teacher_comments': teacherComments,
        'principal_approved': principalApproved,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── LMS MODELS ───────────────────────────────────────────────────

class CourseModel {
  final String id;
  final String schoolId;
  final String name;
  final String? description;
  final String? teacherProfileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? teacher;

  const CourseModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    this.teacherProfileId,
    required this.createdAt,
    required this.updatedAt,
    this.teacher,
  });

  factory CourseModel.fromMap(Map<String, dynamic> map) {
    return CourseModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      teacherProfileId: map['teacher_profile_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      teacher: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'description': description,
        'teacher_profile_id': teacherProfileId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class LessonModel {
  final String id;
  final String schoolId;
  final String courseId;
  final String title;
  final String? contentUrl;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonModel({
    required this.id,
    required this.schoolId,
    required this.courseId,
    required this.title,
    this.contentUrl,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonModel.fromMap(Map<String, dynamic> map) {
    return LessonModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      courseId: map['course_id'] as String,
      title: map['title'] as String,
      contentUrl: map['content_url'] as String?,
      orderIndex: (map['order_index'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'course_id': courseId,
        'title': title,
        'content_url': contentUrl,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AssignmentModel {
  final String id;
  final String schoolId;
  final String lessonId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final double maxPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final LessonModel? lesson;

  const AssignmentModel({
    required this.id,
    required this.schoolId,
    required this.lessonId,
    required this.title,
    this.description,
    required this.dueDate,
    required this.maxPoints,
    required this.createdAt,
    required this.updatedAt,
    this.lesson,
  });

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      lessonId: map['lesson_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: DateTime.parse(map['due_date'] as String),
      maxPoints: (map['max_points'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lesson: map['lessons'] != null
          ? LessonModel.fromMap(map['lessons'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'lesson_id': lessonId,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'max_points': maxPoints,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class SubmissionModel {
  final String id;
  final String schoolId;
  final String assignmentId;
  final String studentProfileId;
  final DateTime submittedAt;
  final String contentUrl;
  final double? grade;
  final String? feedback;
  final String? gradedByProfileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final AssignmentModel? assignment;
  final ProfileModel? gradedBy;

  const SubmissionModel({
    required this.id,
    required this.schoolId,
    required this.assignmentId,
    required this.studentProfileId,
    required this.submittedAt,
    required this.contentUrl,
    this.grade,
    this.feedback,
    this.gradedByProfileId,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.assignment,
    this.gradedBy,
  });

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      assignmentId: map['assignment_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      contentUrl: map['content_url'] as String,
      grade: (map['grade'] as num?)?.toDouble(),
      feedback: map['feedback'] as String?,
      gradedByProfileId: map['graded_by_profile_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      assignment: map['assignments'] != null
          ? AssignmentModel.fromMap(map['assignments'] as Map<String, dynamic>)
          : null,
      gradedBy: map['graded_by'] != null
          ? ProfileModel.fromMap(map['graded_by'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'assignment_id': assignmentId,
        'student_profile_id': studentProfileId,
        'submitted_at': submittedAt.toIso8601String(),
        'content_url': contentUrl,
        'grade': grade,
        'feedback': feedback,
        'graded_by_profile_id': gradedByProfileId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────
// PHASE 5 MODELS: BUS TRACKING, AI TUTOR & MARKETPLACE
// ─────────────────────────────────────────────────────────────────

// ── 1. BUS TRACKING MODELS ───────────────────────────────────────

class BusRouteModel {
  final String id;
  final String schoolId;
  final String routeName;
  final String? driverName;
  final String? driverPhone;
  final String vehicleNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusRouteModel({
    required this.id,
    required this.schoolId,
    required this.routeName,
    this.driverName,
    this.driverPhone,
    required this.vehicleNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusRouteModel.fromMap(Map<String, dynamic> map) {
    return BusRouteModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      routeName: map['route_name'] as String,
      driverName: map['driver_name'] as String?,
      driverPhone: map['driver_phone'] as String?,
      vehicleNumber: map['vehicle_number'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'route_name': routeName,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'vehicle_number': vehicleNumber,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class BusStopModel {
  final String id;
  final String schoolId;
  final String routeId;
  final String stopName;
  final double latitude;
  final double longitude;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusStopModel({
    required this.id,
    required this.schoolId,
    required this.routeId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusStopModel.fromMap(Map<String, dynamic> map) {
    return BusStopModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      routeId: map['route_id'] as String,
      stopName: map['stop_name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      orderIndex: (map['order_index'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'route_id': routeId,
        'stop_name': stopName,
        'latitude': latitude,
        'longitude': longitude,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class BusStudentModel {
  final String id;
  final String schoolId;
  final String routeId;
  final String studentProfileId;
  final String? stopId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final BusRouteModel? route;
  final BusStopModel? stop;

  const BusStudentModel({
    required this.id,
    required this.schoolId,
    required this.routeId,
    required this.studentProfileId,
    this.stopId,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.route,
    this.stop,
  });

  factory BusStudentModel.fromMap(Map<String, dynamic> map) {
    return BusStudentModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      routeId: map['route_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      stopId: map['stop_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      route: map['bus_routes'] != null
          ? BusRouteModel.fromMap(map['bus_routes'] as Map<String, dynamic>)
          : null,
      stop: map['bus_stops'] != null
          ? BusStopModel.fromMap(map['bus_stops'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'route_id': routeId,
        'student_profile_id': studentProfileId,
        'stop_id': stopId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class BusTelemetryModel {
  final String id;
  final String schoolId;
  final String routeId;
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusTelemetryModel({
    required this.id,
    required this.schoolId,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusTelemetryModel.fromMap(Map<String, dynamic> map) {
    return BusTelemetryModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      routeId: map['route_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'route_id': routeId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'recorded_at': recordedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── 2. AI TUTOR MODELS ───────────────────────────────────────────

class AiSessionModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String? subjectId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final SubjectModel? subject;

  const AiSessionModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    this.subjectId,
    required this.createdAt,
    required this.updatedAt,
    this.subject,
  });

  factory AiSessionModel.fromMap(Map<String, dynamic> map) {
    return AiSessionModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      subjectId: map['subject_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      subject: map['subjects'] != null
          ? SubjectModel.fromMap(map['subjects'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'subject_id': subjectId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AiMessageModel {
  final String id;
  final String schoolId;
  final String sessionId;
  final String sender; // 'user' | 'ai'
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiMessageModel({
    required this.id,
    required this.schoolId,
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiMessageModel.fromMap(Map<String, dynamic> map) {
    return AiMessageModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      sessionId: map['session_id'] as String,
      sender: map['sender'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'session_id': sessionId,
        'sender': sender,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isUser => sender == 'user';
}

class StudentLearningProfileModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final List<String> strengths;
  final List<String> weaknesses;
  final DateTime lastEvaluatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentLearningProfileModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.strengths,
    required this.weaknesses,
    required this.lastEvaluatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentLearningProfileModel.fromMap(Map<String, dynamic> map) {
    final strList = (map['strengths'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final weakList = (map['weaknesses'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return StudentLearningProfileModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      strengths: strList,
      weaknesses: weakList,
      lastEvaluatedAt: DateTime.parse(map['last_evaluated_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'last_evaluated_at': lastEvaluatedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── 3. MARKETPLACE MODELS ────────────────────────────────────────

class MarketplaceItemModel {
  final String id;
  final String schoolId;
  final String title;
  final String? description;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final String sellerProfileId;
  final String status; // 'available' | 'sold_out' | 'hidden'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? seller;

  const MarketplaceItemModel({
    required this.id,
    required this.schoolId,
    required this.title,
    this.description,
    required this.price,
    required this.stockQuantity,
    this.imageUrl,
    required this.sellerProfileId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.seller,
  });

  factory MarketplaceItemModel.fromMap(Map<String, dynamic> map) {
    return MarketplaceItemModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      stockQuantity: (map['stock_quantity'] as int?) ?? 1,
      imageUrl: map['image_url'] as String?,
      sellerProfileId: map['seller_profile_id'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      seller: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'title': title,
        'description': description,
        'price': price,
        'stock_quantity': stockQuantity,
        'image_url': imageUrl,
        'seller_profile_id': sellerProfileId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class MarketplaceOrderModel {
  final String id;
  final String schoolId;
  final String buyerProfileId;
  final double totalAmount;
  final String status; // 'pending' | 'completed' | 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? buyer;
  final List<MarketplaceOrderItemModel>? items;

  const MarketplaceOrderModel({
    required this.id,
    required this.schoolId,
    required this.buyerProfileId,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.buyer,
    this.items,
  });

  factory MarketplaceOrderModel.fromMap(Map<String, dynamic> map) {
    return MarketplaceOrderModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      buyerProfileId: map['buyer_profile_id'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      buyer: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      items: map['marketplace_order_items'] != null
          ? (map['marketplace_order_items'] as List)
              .map((i) => MarketplaceOrderItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'buyer_profile_id': buyerProfileId,
        'total_amount': totalAmount,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class MarketplaceOrderItemModel {
  final String id;
  final String schoolId;
  final String orderId;
  final String itemId;
  final int quantity;
  final double priceAtPurchase;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final MarketplaceItemModel? item;

  const MarketplaceOrderItemModel({
    required this.id,
    required this.schoolId,
    required this.orderId,
    required this.itemId,
    required this.quantity,
    required this.priceAtPurchase,
    required this.createdAt,
    required this.updatedAt,
    this.item,
  });

  factory MarketplaceOrderItemModel.fromMap(Map<String, dynamic> map) {
    return MarketplaceOrderItemModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      orderId: map['order_id'] as String,
      itemId: map['item_id'] as String,
      quantity: (map['quantity'] as int?) ?? 1,
      priceAtPurchase: (map['price_at_purchase'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      item: map['marketplace_items'] != null
          ? MarketplaceItemModel.fromMap(map['marketplace_items'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'order_id': orderId,
        'item_id': itemId,
        'quantity': quantity,
        'price_at_purchase': priceAtPurchase,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────
// PHASE 6 MODELS: BURSARIES, PAYMENTS & SCHOOL FINANCE
// ─────────────────────────────────────────────────────────────────

class FeeTypeModel {
  final String id;
  final String schoolId;
  final String name;
  final String? description;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeTypeModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeTypeModel.fromMap(Map<String, dynamic> map) {
    return FeeTypeModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'description': description,
        'amount': amount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class InvoiceModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String academicYearId;
  final double totalAmount;
  final double paidAmount;
  final DateTime dueDate;
  final String status; // 'paid' | 'partial' | 'unpaid'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final AcademicYearModel? academicYear;
  final List<InvoiceItemModel>? items;

  const InvoiceModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.academicYearId,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.academicYear,
    this.items,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      academicYear: map['academic_years'] != null
          ? AcademicYearModel.fromMap(map['academic_years'] as Map<String, dynamic>)
          : null,
      items: map['invoice_items'] != null
          ? (map['invoice_items'] as List)
              .map((i) => InvoiceItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'academic_year_id': academicYearId,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  double get balanceRemaining => (totalAmount - paidAmount).clamp(0.0, double.infinity);
  bool get isFullyPaid => status == 'paid' || balanceRemaining <= 0;
}

class InvoiceItemModel {
  final String id;
  final String schoolId;
  final String invoiceId;
  final String feeTypeId;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final FeeTypeModel? feeType;

  const InvoiceItemModel({
    required this.id,
    required this.schoolId,
    required this.invoiceId,
    required this.feeTypeId,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.feeType,
  });

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      invoiceId: map['invoice_id'] as String,
      feeTypeId: map['fee_type_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      feeType: map['fee_types'] != null
          ? FeeTypeModel.fromMap(map['fee_types'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'invoice_id': invoiceId,
        'fee_type_id': feeTypeId,
        'amount': amount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class PaymentModel {
  final String id;
  final String schoolId;
  final String invoiceId;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final DateTime paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentModel({
    required this.id,
    required this.schoolId,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      invoiceId: map['invoice_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      transactionReference: map['transaction_reference'] as String?,
      paidAt: DateTime.parse(map['paid_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_reference': transactionReference,
        'paid_at': paidAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class BursaryModel {
  final String id;
  final String schoolId;
  final String name;
  final double? discountPercentage;
  final double? discountAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BursaryModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.discountPercentage,
    this.discountAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BursaryModel.fromMap(Map<String, dynamic> map) {
    return BursaryModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      name: map['name'] as String,
      discountPercentage: (map['discount_percentage'] as num?)?.toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get discountLabel => discountPercentage != null
      ? '${discountPercentage!.toStringAsFixed(0)}% Off'
      : '\$${discountAmount!.toStringAsFixed(2)} Off';
}

class StudentBursaryModel {
  final String id;
  final String schoolId;
  final String studentProfileId;
  final String bursaryId;
  final String academicYearId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? student;
  final BursaryModel? bursary;

  const StudentBursaryModel({
    required this.id,
    required this.schoolId,
    required this.studentProfileId,
    required this.bursaryId,
    required this.academicYearId,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.bursary,
  });

  factory StudentBursaryModel.fromMap(Map<String, dynamic> map) {
    return StudentBursaryModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      studentProfileId: map['student_profile_id'] as String,
      bursaryId: map['bursary_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      student: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
      bursary: map['bursaries'] != null
          ? BursaryModel.fromMap(map['bursaries'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_profile_id': studentProfileId,
        'bursary_id': bursaryId,
        'academic_year_id': academicYearId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class StaffPayrollModel {
  final String id;
  final String schoolId;
  final String staffProfileId;
  final double baseSalary;
  final double allowances;
  final double deductions;
  final DateTime paymentDate;
  final String status; // 'pending' | 'processed' | 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? staff;

  const StaffPayrollModel({
    required this.id,
    required this.schoolId,
    required this.staffProfileId,
    required this.baseSalary,
    required this.allowances,
    required this.deductions,
    required this.paymentDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.staff,
  });

  factory StaffPayrollModel.fromMap(Map<String, dynamic> map) {
    return StaffPayrollModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      staffProfileId: map['staff_profile_id'] as String,
      baseSalary: (map['base_salary'] as num).toDouble(),
      allowances: (map['allowances'] as num?)?.toDouble() ?? 0.0,
      deductions: (map['deductions'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      staff: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'staff_profile_id': staffProfileId,
        'base_salary': baseSalary,
        'allowances': allowances,
        'deductions': deductions,
        'payment_date': paymentDate.toIso8601String().split('T')[0],
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  double get netSalary => baseSalary + allowances - deductions;
}

class ExpenseModel {
  final String id;
  final String schoolId;
  final String title;
  final String category;
  final double amount;
  final String? spentByProfileId;
  final DateTime spentAt;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final ProfileModel? spentBy;

  const ExpenseModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.category,
    required this.amount,
    this.spentByProfileId,
    required this.spentAt,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    this.spentBy,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      spentByProfileId: map['spent_by_profile_id'] as String?,
      spentAt: DateTime.parse(map['spent_at'] as String),
      receiptUrl: map['receipt_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      spentBy: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'title': title,
        'category': category,
        'amount': amount,
        'spent_by_profile_id': spentByProfileId,
        'spent_at': spentAt.toIso8601String().split('T')[0],
        'receipt_url': receiptUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class BudgetModel {
  final String id;
  final String schoolId;
  final String departmentName;
  final String academicYearId;
  final double allocatedAmount;
  final double spentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.schoolId,
    required this.departmentName,
    required this.academicYearId,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      departmentName: map['department_name'] as String,
      academicYearId: map['academic_year_id'] as String,
      allocatedAmount: (map['allocated_amount'] as num).toDouble(),
      spentAmount: (map['spent_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'department_name': departmentName,
        'academic_year_id': academicYearId,
        'allocated_amount': allocatedAmount,
        'spent_amount': spentAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  double get remainingBudget => (allocatedAmount - spentAmount).clamp(0.0, double.infinity);
  double get utilizationPercentage => allocatedAmount > 0 ? (spentAmount / allocatedAmount) * 100.0 : 0.0;
}

// ─────────────────────────────────────────────────────────────────
// PHASE 012 TYPED MODELS & MULTI-CURRENCY SUPPORT
// ─────────────────────────────────────────────────────────────────

class FinanceCurrencySummary {
  final String currency;
  final double totalInvoiced;
  final double totalPaid;
  final double outstanding;
  final double settledPercent;
  final int overdueCount;
  final String? nextDueDate;

  const FinanceCurrencySummary({
    required this.currency,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.outstanding,
    required this.settledPercent,
    this.overdueCount = 0,
    this.nextDueDate,
  });

  factory FinanceCurrencySummary.fromMap(Map<String, dynamic> map) {
    final invoiced = (map['total_invoiced'] as num?)?.toDouble() ?? (map['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (map['total_paid'] as num?)?.toDouble() ?? (map['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final out = (map['outstanding'] as num?)?.toDouble() ?? (invoiced - paid).clamp(0.0, double.infinity);
    final pct = (map['settled_percent'] as num?)?.toDouble() ?? (invoiced > 0 ? (paid / invoiced) * 100.0 : 100.0);

    return FinanceCurrencySummary(
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'USD',
      totalInvoiced: invoiced,
      totalPaid: paid,
      outstanding: out,
      settledPercent: pct,
      overdueCount: (map['overdue_count'] as num?)?.toInt() ?? 0,
      nextDueDate: map['next_due_date'] as String?,
    );
  }

  String get formattedOutstanding => '$currency ${outstanding.toStringAsFixed(2)}';
  String get formattedPaid => '$currency ${totalPaid.toStringAsFixed(2)}';
  String get formattedTotal => '$currency ${totalInvoiced.toStringAsFixed(2)}';
}

class AuthorizedChild {
  final String studentId;
  final String fullName;
  final String className;
  final String? campus;
  final String relationshipType;

  const AuthorizedChild({
    required this.studentId,
    required this.fullName,
    required this.className,
    this.campus,
    this.relationshipType = 'guardian',
  });

  factory AuthorizedChild.fromRelationshipMap(Map<String, dynamic> map) {
    final student = map['student'] as Map<String, dynamic>? ?? {};
    return AuthorizedChild(
      studentId: map['student_id'] as String? ?? student['id'] as String? ?? '',
      fullName: student['full_name'] as String? ?? 'Student',
      className: student['class_name'] as String? ?? 'Enrolled Class',
      campus: student['campus_name'] as String?,
      relationshipType: map['relationship_type'] as String? ?? 'guardian',
    );
  }
}

class TeacherScheduleItem {
  final String time;
  final String subject;
  final String classSectionName;
  final String room;
  final int studentCount;
  final String status;
  final String statusVariant;

  const TeacherScheduleItem({
    required this.time,
    required this.subject,
    required this.classSectionName,
    required this.room,
    required this.studentCount,
    required this.status,
    this.statusVariant = 'neutral',
  });

  factory TeacherScheduleItem.fromMap(Map<String, dynamic> map) {
    return TeacherScheduleItem(
      time: map['time'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      classSectionName: map['class'] as String? ?? map['class_section_name'] as String? ?? '',
      room: map['room'] as String? ?? '',
      studentCount: (map['students'] as num?)?.toInt() ?? (map['student_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      statusVariant: map['status_variant'] as String? ?? 'neutral',
    );
  }
}

class TeacherPriorityActionItem {
  final String title;
  final String meta;
  final String action;
  final String type;

  const TeacherPriorityActionItem({
    required this.title,
    required this.meta,
    required this.action,
    required this.type,
  });

  factory TeacherPriorityActionItem.fromMap(Map<String, dynamic> map) {
    return TeacherPriorityActionItem(
      title: map['title'] as String? ?? '',
      meta: map['meta'] as String? ?? '',
      action: map['action'] as String? ?? 'Open',
      type: map['type'] as String? ?? 'attendance',
    );
  }
}

class TeacherDashboardMetrics {
  final int classesToday;
  final int classesCompleted;
  final int classesRemaining;
  final int attendancePending;
  final int submissionsToMark;
  final int assignmentsToMark;
  final int unreadMessages;
  final int unreadParentSenders;
  final List<TeacherScheduleItem> schedule;
  final List<TeacherPriorityActionItem> priorityActions;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> announcements;

  const TeacherDashboardMetrics({
    this.classesToday = 0,
    this.classesCompleted = 0,
    this.classesRemaining = 0,
    this.attendancePending = 0,
    this.submissionsToMark = 0,
    this.assignmentsToMark = 0,
    this.unreadMessages = 0,
    this.unreadParentSenders = 0,
    this.schedule = const [],
    this.priorityActions = const [],
    this.classes = const [],
    this.assignments = const [],
    this.announcements = const [],
  });

  factory TeacherDashboardMetrics.fromMap(Map<String, dynamic> map) {
    final kpis = map['kpis'] as Map<String, dynamic>? ?? map;

    return TeacherDashboardMetrics(
      classesToday: (kpis['classes_today'] as num?)?.toInt() ?? 0,
      classesCompleted: (kpis['classes_completed'] as num?)?.toInt() ?? 0,
      classesRemaining: (kpis['classes_remaining'] as num?)?.toInt() ?? 0,
      attendancePending: (kpis['attendance_pending'] as num?)?.toInt() ?? 0,
      submissionsToMark: (kpis['to_mark_submissions'] as num?)?.toInt() ?? (kpis['submissions_to_mark'] as num?)?.toInt() ?? 0,
      assignmentsToMark: (kpis['to_mark_assignments'] as num?)?.toInt() ?? (kpis['assignments_to_mark'] as num?)?.toInt() ?? 0,
      unreadMessages: (kpis['unread_messages'] as num?)?.toInt() ?? 0,
      unreadParentSenders: (kpis['unread_parents'] as num?)?.toInt() ?? (kpis['unread_parent_senders'] as num?)?.toInt() ?? 0,
      schedule: (map['schedule'] as List<dynamic>?)
              ?.map((e) => TeacherScheduleItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      priorityActions: (map['priority_actions'] as List<dynamic>?)
              ?.map((e) => TeacherPriorityActionItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      classes: (map['my_classes'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      assignments: (map['assignments_marking'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      announcements: (map['announcements'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
    );
  }
}

class ParentActivityItem {
  final String title;
  final String meta;
  final String badge;
  final String variant;

  const ParentActivityItem({
    required this.title,
    required this.meta,
    required this.badge,
    this.variant = 'primary',
  });

  factory ParentActivityItem.fromMap(Map<String, dynamic> map) {
    return ParentActivityItem(
      title: map['title'] as String? ?? '',
      meta: map['meta'] as String? ?? '',
      badge: map['badge'] as String? ?? '',
      variant: map['variant'] as String? ?? 'primary',
    );
  }
}

class ParentDashboardData {
  final String studentId;
  final String studentName;
  final String className;
  final double? attendanceRate;
  final String attendanceHint;
  final double? academicAverage;
  final String academicHint;
  final List<FinanceCurrencySummary> currencySummaries;
  final int assignmentsDueCount;
  final String assignmentsHint;
  final String? nextLesson;
  final String? latestResult;
  final String? nextFeeDate;
  final List<ParentActivityItem> recentActivity;
  final List<Map<String, dynamic>> announcements;

  const ParentDashboardData({
    required this.studentId,
    required this.studentName,
    required this.className,
    this.attendanceRate,
    this.attendanceHint = 'No attendance recorded',
    this.academicAverage,
    this.academicHint = 'No assessments recorded',
    this.currencySummaries = const [],
    this.assignmentsDueCount = 0,
    this.assignmentsHint = '0 overdue',
    this.nextLesson,
    this.latestResult,
    this.nextFeeDate,
    this.recentActivity = const [],
    this.announcements = const [],
  });

  factory ParentDashboardData.fromMap(String studentId, String studentName, String className, Map<String, dynamic> map) {
    final kpis = map['kpis'] as Map<String, dynamic>? ?? {};
    
    // Parse currency summaries preserving separation
    final currencyList = <FinanceCurrencySummary>[];
    if (map['finance'] != null && map['finance']['by_currency'] is List) {
      for (final item in map['finance']['by_currency']) {
        if (item is Map) currencyList.add(FinanceCurrencySummary.fromMap(Map<String, dynamic>.from(item)));
      }
    } else if (map['currencies'] is List) {
      for (final item in map['currencies']) {
        if (item is Map) currencyList.add(FinanceCurrencySummary.fromMap(Map<String, dynamic>.from(item)));
      }
    } else if (kpis['outstanding_fees'] != null) {
      final feeStr = kpis['outstanding_fees'].toString();
      final numeric = double.tryParse(feeStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      currencyList.add(FinanceCurrencySummary(
        currency: 'USD',
        totalInvoiced: numeric,
        totalPaid: 0.0,
        outstanding: numeric,
        settledPercent: 0.0,
      ));
    }

    final attStr = kpis['attendance']?.toString() ?? '';
    final attNum = double.tryParse(attStr.replaceAll('%', ''));

    final avgStr = kpis['academic_average']?.toString() ?? '';
    final avgNum = double.tryParse(avgStr.replaceAll('%', ''));

    return ParentDashboardData(
      studentId: studentId,
      studentName: studentName,
      className: className,
      attendanceRate: attNum,
      attendanceHint: kpis['attendance_hint'] as String? ?? 'Present record',
      academicAverage: avgNum,
      academicHint: kpis['academic_hint'] as String? ?? 'Term 1 progress',
      currencySummaries: currencyList,
      assignmentsDueCount: (kpis['assignments_due'] as num?)?.toInt() ?? 0,
      assignmentsHint: kpis['assignments_hint'] as String? ?? '0 overdue',
      nextLesson: map['next_lesson'] as String?,
      latestResult: map['latest_result'] as String?,
      nextFeeDate: map['next_fee_date'] as String?,
      recentActivity: (map['recent_academic_activity'] as List<dynamic>?)
              ?.map((e) => ParentActivityItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      announcements: (map['announcements'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
    );
  }
}

class DirectMessageItem {
  final String id;
  final String schoolId;
  final String senderProfileId;
  final String recipientProfileId;
  final String message;
  final DateTime createdAt;
  final String? senderName;
  final String? senderRole;
  final bool isFromMe;

  const DirectMessageItem({
    required this.id,
    required this.schoolId,
    required this.senderProfileId,
    required this.recipientProfileId,
    required this.message,
    required this.createdAt,
    this.senderName,
    this.senderRole,
    this.isFromMe = false,
  });

  factory DirectMessageItem.fromMap(Map<String, dynamic> map, String myProfileId) {
    final sender = map['sender'] as Map<String, dynamic>?;
    final senderId = map['sender_profile_id'] as String? ?? '';

    return DirectMessageItem(
      id: map['id'] as String,
      schoolId: map['school_id'] as String? ?? '',
      senderProfileId: senderId,
      recipientProfileId: map['recipient_profile_id'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      senderName: sender?['full_name'] as String?,
      senderRole: sender?['role'] as String?,
      isFromMe: senderId == myProfileId,
    );
  }

  bool get isMe => isFromMe;
}





import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/database/app_database.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';
import '../services/services.dart';

/// The Supabase client singleton provider.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provides the SharedPreferences instance (must be overridden at app start).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at app start with ProviderScope overrides.');
});

/// Drift offline SQLite database — singleton, must be overridden at app start.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden at app start with ProviderScope overrides.');
});

/// Typed RPC client wrapping Supabase for all authoritative PostgreSQL function calls.
final rpcClientProvider = Provider<RpcClient>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RpcClient(client);
});

// ─────────────────────────────────────────────────────────────────
// AUTH PROVIDER
// ─────────────────────────────────────────────────────────────────

/// Streams the current Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The current authenticated user (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// ─────────────────────────────────────────────────────────────────
// SESSION / ACTIVE CONTEXT PROVIDER
// ─────────────────────────────────────────────────────────────────

/// Notifier that manages the user's active session context (school + role).
class ActiveSessionNotifier extends StateNotifier<ActiveSession?> {
  final SharedPreferences _prefs;
  final RpcClient _rpc;

  DateTime? _lastHeartbeat;

  ActiveSessionNotifier(this._prefs, this._rpc) : super(null) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final schoolId = _prefs.getString(AppConstants.prefActiveSchoolId);
    final role = _prefs.getString(AppConstants.prefActiveRole);
    final profileId = _prefs.getString(AppConstants.prefActiveProfileId);
    final schoolName = _prefs.getString('active_school_name');

    if (schoolId != null && role != null && profileId != null && schoolName != null) {
      state = ActiveSession(
        schoolId: schoolId,
        schoolName: schoolName,
        profileId: profileId,
        role: role,
      );
      _triggerHeartbeat();
    }
  }

  Future<void> setActiveSession(ActiveSession session) async {
    await Future.wait([
      _prefs.setString(AppConstants.prefActiveSchoolId, session.schoolId),
      _prefs.setString(AppConstants.prefActiveRole, session.role),
      _prefs.setString(AppConstants.prefActiveProfileId, session.profileId),
      _prefs.setString('active_school_name', session.schoolName),
    ]);
    state = session;
    await _triggerHeartbeat(force: true);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _prefs.remove(AppConstants.prefActiveSchoolId),
      _prefs.remove(AppConstants.prefActiveRole),
      _prefs.remove(AppConstants.prefActiveProfileId),
      _prefs.remove('active_school_name'),
    ]);
    state = null;
  }

  Future<void> _triggerHeartbeat({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastHeartbeat != null && now.difference(_lastHeartbeat!).inMinutes < 15) {
      return;
    }
    try {
      await _rpc.touchActiveProfile(force: force);
      _lastHeartbeat = now;
    } catch (_) {}
  }
}

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, ActiveSession?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final rpc = ref.watch(rpcClientProvider);
  return ActiveSessionNotifier(prefs, rpc);
});

// ─────────────────────────────────────────────────────────────────
// PROFILES PROVIDER (all profiles for current logged-in user)
// ─────────────────────────────────────────────────────────────────

/// Fetches all profiles (across all schools) for the authenticated user.
final userProfilesProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return ProfileService(client).getUserProfiles();
});

final schoolProfilesProvider = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return ProfileService(client).getSchoolProfiles(schoolId);
});

// ─────────────────────────────────────────────────────────────────
// SCHOOLS PROVIDER (for super admin)
// ─────────────────────────────────────────────────────────────────

/// Fetches all schools — usable by super admins.
final allSchoolsProvider = FutureProvider<List<SchoolModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getAllSchools();
});

// ─────────────────────────────────────────────────────────────────
// PHASE 2 PROVIDERS: ACADEMIC STRUCTURE & ENROLLMENTS
// ─────────────────────────────────────────────────────────────────

final academicYearsProvider = FutureProvider.family<List<AcademicYearModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getAcademicYears(schoolId);
});

final classesProvider = FutureProvider.family<List<ClassModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getClasses(schoolId);
});

final classSectionsProvider = FutureProvider.family<List<ClassSectionModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getClassSections(schoolId);
});

final subjectsProvider = FutureProvider.family<List<SubjectModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getSubjects(schoolId);
});

final classTeachersProvider = FutureProvider.family<List<ClassTeacherModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getClassTeachers(schoolId);
});

final enrollmentsProvider = FutureProvider.family<List<StudentEnrollmentModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getEnrollments(schoolId);
});

final parentRelationshipsProvider = FutureProvider.family<List<UserRelationshipModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicStructureService(client).getParentStudentRelationships(schoolId);
});

final studentGuardiansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentProfileId) async {
  final rpc = ref.watch(rpcClientProvider);
  return rpc.getStudentGuardians(studentProfileId);
});

final attendanceEntriesProvider = FutureProvider.family<List<AttendanceEntryModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getAttendanceEntries(schoolId);
});

/// Provider for a teacher's own leave requests — pass 'schoolId|profileId'
final myLeaveRequestsProvider = FutureProvider.family<List<StaffLeaveRequestModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getLeaveRequests(args.$1, staffProfileId: args.$2);
});

/// Provider for all leave requests in a school (school admin view)
final leaveRequestsProvider = FutureProvider.family<List<StaffLeaveRequestModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getLeaveRequests(schoolId);
});

final announcementsProvider = FutureProvider.family<List<SchoolAnnouncementModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getAnnouncements(schoolId);
});

final staffAttendanceProvider = FutureProvider.family<List<StaffAttendanceModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getStaffAttendance(schoolId);
});

/// Returns sections assigned to a teacher — pass 'schoolId|teacherProfileId'
final teacherSectionsProvider = FutureProvider.family<List<ClassSectionModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolOperationsService(client).getTeacherSections(args.$1, args.$2);
});

// ─────────────────────────────────────────────────────────────────
// PHASE 4 PROVIDERS: GRADEBOOK, REPORT CARDS & LMS
// ─────────────────────────────────────────────────────────────────

final gradingTermsProvider = FutureProvider.family<List<GradingTermModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getGradingTerms(schoolId);
});

final assessmentCategoriesProvider = FutureProvider.family<List<AssessmentCategoryModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getAssessmentCategories(schoolId);
});

final assessmentsProvider = FutureProvider.family<List<AssessmentModel>, (String, String?, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getAssessments(
    args.$1,
    classSectionId: args.$2,
    subjectId: args.$3,
  );
});

final gradeRecordsProvider = FutureProvider.family<List<GradeRecordModel>, String>((ref, assessmentId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getGradeRecords(assessmentId);
});

final studentGradesProvider = FutureProvider.family<List<GradeRecordModel>, String>((ref, studentProfileId) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getStudentGrades(studentProfileId);
});

final reportCardsProvider = FutureProvider.family<List<ReportCardModel>, (String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getReportCards(args.$1, termId: args.$2);
});

final studentReportCardsProvider = FutureProvider.family<List<ReportCardModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AcademicGradebookService(client).getReportCards(args.$1, studentProfileId: args.$2);
});

final coursesProvider = FutureProvider.family<List<CourseModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return LmsService(client).getCourses(schoolId);
});

final lessonsProvider = FutureProvider.family<List<LessonModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return LmsService(client).getLessons(args.$1, args.$2);
});

final assignmentsProvider = FutureProvider.family<List<AssignmentModel>, (String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return LmsService(client).getAssignments(args.$1, lessonId: args.$2);
});

final submissionsProvider = FutureProvider.family<List<SubmissionModel>, String>((ref, assignmentId) async {
  final client = ref.watch(supabaseClientProvider);
  return LmsService(client).getSubmissions(assignmentId);
});

// ─────────────────────────────────────────────────────────────────
// PHASE 5 PROVIDERS: BUS TRACKING, MARKETPLACE & AI TUTOR
// ─────────────────────────────────────────────────────────────────

// ── BUS PROVIDERS ──
final busRoutesProvider = FutureProvider.family<List<BusRouteModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return BusTrackingService(client).getBusRoutes(schoolId);
});

final busStopsProvider = FutureProvider.family<List<BusStopModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return BusTrackingService(client).getBusStops(args.$1, args.$2);
});

final busStudentsProvider = FutureProvider.family<List<BusStudentModel>, (String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return BusTrackingService(client).getBusStudents(args.$1, routeId: args.$2);
});

final busTelemetryProvider = FutureProvider.family<BusTelemetryModel?, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return BusTrackingService(client).getLatestTelemetry(args.$1, args.$2);
});

// ── MARKETPLACE PROVIDERS ──
final marketplaceItemsProvider = FutureProvider.family<List<MarketplaceItemModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return MarketplaceService(client).getItems(schoolId);
});

final marketplaceOrdersProvider = FutureProvider.family<List<MarketplaceOrderModel>, (String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return MarketplaceService(client).getOrders(args.$1, buyerProfileId: args.$2);
});

// ── AI TUTOR PROVIDERS ──
final aiSessionProvider = FutureProvider.family<AiSessionModel, (String, String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AiTutorService(client).getOrCreateSession(
    schoolId: args.$1,
    studentProfileId: args.$2,
    subjectId: args.$3,
  );
});

final aiMessagesProvider = FutureProvider.family<List<AiMessageModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AiTutorService(client).getMessages(args.$1, args.$2);
});

final studentLearningProfileProvider = FutureProvider.family<StudentLearningProfileModel, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return AiTutorService(client).getLearningProfile(args.$1, args.$2);
});

// ── TEACHER AI PROVIDER ──
final teacherAiServiceProvider = Provider<TeacherAiService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TeacherAiService(client);
});


// ─────────────────────────────────────────────────────────────────
// PHASE 6 PROVIDERS: SCHOOL FINANCE
// ─────────────────────────────────────────────────────────────────

final feeTypesProvider = FutureProvider.family<List<FeeTypeModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getFeeTypes(schoolId);
});

final invoicesProvider = FutureProvider.family<List<InvoiceModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getInvoices(schoolId);
});

final studentInvoicesProvider = FutureProvider.family<List<InvoiceModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getInvoices(args.$1, studentProfileId: args.$2);
});

final bursariesProvider = FutureProvider.family<List<BursaryModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getBursaries(schoolId);
});

final studentBursariesProvider = FutureProvider.family<List<StudentBursaryModel>, (String, String?)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getStudentBursaries(args.$1, studentProfileId: args.$2);
});

final staffPayrollProvider = FutureProvider.family<List<StaffPayrollModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getStaffPayroll(schoolId);
});

final expensesProvider = FutureProvider.family<List<ExpenseModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getExpenses(schoolId);
});

final budgetsProvider = FutureProvider.family<List<BudgetModel>, (String, String)>((ref, args) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolFinanceService(client).getBudgets(args.$1, args.$2);
});

/// Screen 12: Finance Dashboard summary KPIs from authoritative RPC.
/// Returns: invoiced, collected, outstanding, expenses, collection_rate, overdue_count
final financeDashboardMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final rpc = ref.watch(rpcClientProvider);
  try {
    return await rpc.getFinanceDashboardMetrics();
  } catch (e) {
    debugPrint('[Finance] Dashboard metrics error: $e');
    return const <String, dynamic>{};
  }
});





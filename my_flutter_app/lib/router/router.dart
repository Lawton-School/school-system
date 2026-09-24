import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/profile_picker_screen.dart';
import '../screens/super_admin/super_admin_shell.dart';
import '../screens/school_admin/school_admin_shell.dart';
import '../screens/school_admin/academic_years_screen.dart';
import '../screens/school_admin/classes_sections_screen.dart';
import '../screens/school_admin/subjects_screen.dart';
import '../screens/school_admin/teacher_assignment_screen.dart';
import '../screens/school_admin/student_enrollment_screen.dart';
import '../screens/school_admin/parent_student_mapping_screen.dart';
import '../screens/school_admin/gradebook_setup_screen.dart';
import '../screens/school_admin/school_reports_screen.dart';
import '../screens/school_admin/notifications_screen.dart';
import '../screens/school_admin/report_cards_screen.dart';
import '../screens/school_admin/admissions_screen.dart';
import '../screens/operations/bus_tracking_screen.dart';
import '../screens/operations/marketplace_screen.dart';
import '../screens/operations/sync_diagnostics_screen.dart';
import '../screens/finance/school_finance_screen.dart';
import '../screens/finance/invoices_screen.dart';
import '../screens/finance/payments_ledger_screen.dart';
import '../screens/finance/parent_fees_screen.dart';
import '../screens/teacher/teacher_shell.dart';
import '../screens/teacher/teacher_operations_screen.dart';
import '../screens/teacher/teacher_ai_assistant_screen.dart';
import '../screens/parent/parent_shell.dart';
import '../screens/parent/parent_academics_screen.dart';
import '../screens/parent/parent_messages_screen.dart';
import '../screens/student/student_shell.dart';
import '../screens/student/ai_tutor_screen.dart';

// ─────────────────────────────────────────────────────────────────
// ROUTE NAMES
// ─────────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const profilePicker = '/profile-picker';

  // Super Admin
  static const superAdminDashboard = '/super-admin';
  static const superAdminSchools = '/super-admin/schools';
  static const superAdminCreateSchool = '/super-admin/schools/create';

  // School Admin
  static const schoolAdminDashboard = '/school-admin';
  static const schoolAdminUsers = '/school-admin/users';
  static const schoolAdminCreateUser = '/school-admin/users/create';
  static const schoolAdminStructure = '/school-admin/academic-structure';

  // Phase 2: Academic Structure
  static const academicYears = '/school-admin/academic-years';
  static const classesSections = '/school-admin/classes-sections';
  static const subjects = '/school-admin/subjects';
  static const teacherAssignments = '/school-admin/teacher-assignments';
  static const studentEnrollments = '/school-admin/enrollments';
  static const parentStudentMapping = '/school-admin/parent-student-mapping';

  // Phase 3: Operations & Admissions
  static const schoolAdminOperations = '/school-admin/operations';
  static const schoolAdminAdmissions = '/school-admin/admissions';

  // Phase 4: Gradebook & LMS
  static const schoolAdminGradebook = '/school-admin/gradebook-setup';
  static const schoolAdminReportCards = '/school-admin/report-cards';
  static const schoolAdminReports = '/school-admin/reports';
  static const schoolAdminNotifications = '/school-admin/notifications';

  // Phase 5: Operations & Auxiliary Modules
  static const schoolAdminBus = '/school-admin/bus-fleet';
  static const schoolAdminMarketplace = '/school-admin/marketplace';

  // Phase 6: Finance & Payments
  static const schoolAdminFinance = '/school-admin/finance';
  static const schoolAdminInvoices = '/school-admin/finance/invoices';
  static const schoolAdminPayments = '/school-admin/finance/payments';
  static const parentFees = '/parent/fees';

  // Phase 7: Sync Diagnostics
  static const syncDiagnostics = '/sync-diagnostics';

  // Teacher
  static const teacherDashboard = '/teacher';
  static const teacherOperations = '/teacher/operations';
  static const teacherAiAssistant = '/teacher/ai-assistant';

  // Parent
  static const parentDashboard = '/parent';
  static const parentAcademics = '/parent/academics';
  static const parentMessages = '/parent/messages';

  // Student
  static const studentDashboard = '/student';
  static const aiTutor = '/student/ai-tutor';
}

// ─────────────────────────────────────────────────────────────────
// ROUTER PROVIDER
// ─────────────────────────────────────────────────────────────────

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final activeSession = ref.watch(activeSessionProvider);
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final user = client.auth.currentUser;
      final isLoggedIn = user != null;
      final isOnLogin = state.uri.toString() == AppRoutes.login;
      final isOnProfilePicker = state.uri.toString() == AppRoutes.profilePicker;

      if (!isLoggedIn) {
        return isOnLogin ? null : AppRoutes.login;
      }

      if (isLoggedIn && activeSession == null) {
        return isOnProfilePicker ? null : AppRoutes.profilePicker;
      }

      if (isLoggedIn && activeSession != null && (isOnLogin || isOnProfilePicker)) {
        return _dashboardForRole(activeSession.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.profilePicker,
        builder: (context, state) => const ProfilePickerScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => SuperAdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.superAdminDashboard,
            builder: (context, state) => const SuperAdminDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.superAdminSchools,
            builder: (context, state) => const SuperAdminSchoolsPage(),
          ),
          GoRoute(
            path: AppRoutes.superAdminCreateSchool,
            builder: (context, state) => const CreateSchoolPage(),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => SchoolAdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.schoolAdminDashboard,
            builder: (context, state) => const SchoolAdminDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminUsers,
            builder: (context, state) => const SchoolAdminUsersPage(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminCreateUser,
            builder: (context, state) => const CreateUserPage(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminStructure,
            builder: (context, state) => const AcademicStructurePage(),
          ),
          GoRoute(
            path: AppRoutes.academicYears,
            builder: (context, state) => const AcademicYearsScreen(),
          ),
          GoRoute(
            path: AppRoutes.classesSections,
            builder: (context, state) => const ClassesSectionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.subjects,
            builder: (context, state) => const SubjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherAssignments,
            builder: (context, state) => const TeacherAssignmentScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentEnrollments,
            builder: (context, state) => const StudentEnrollmentScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentStudentMapping,
            builder: (context, state) => const ParentStudentMappingScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminOperations,
            builder: (context, state) => const SchoolAdminOperationsPage(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminAdmissions,
            builder: (context, state) => const AdmissionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminGradebook,
            builder: (context, state) => const GradebookSetupScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminBus,
            builder: (context, state) => const BusTrackingScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminMarketplace,
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminFinance,
            builder: (context, state) => const SchoolFinanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminInvoices,
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminPayments,
            builder: (context, state) => const PaymentsLedgerScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminReports,
            builder: (context, state) => const ReportsAnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminReportCards,
            builder: (context, state) => const ReportCardsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdminNotifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.syncDiagnostics,
            builder: (context, state) => const SyncDiagnosticsScreen(),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.teacherDashboard,
            builder: (context, state) => const TeacherDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.teacherOperations,
            builder: (context, state) => const TeacherOperationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherAiAssistant,
            builder: (context, state) => const TeacherAiAssistantScreen(),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.parentDashboard,
            builder: (context, state) => const ParentDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.parentFees,
            builder: (context, state) => const ParentFeesScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentAcademics,
            builder: (context, state) => const ParentAcademicsScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentMessages,
            builder: (context, state) => const ParentMessagesScreen(),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (context, state) => const StudentDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.aiTutor,
            builder: (context, state) => const AiTutorScreen(),
          ),
        ],
      ),
    ],
  );
});

String _dashboardForRole(String role) {
  switch (role) {
    case AppRoles.superAdmin:
      return AppRoutes.superAdminDashboard;
    case AppRoles.schoolAdmin:
      return AppRoutes.schoolAdminDashboard;
    case AppRoles.teacher:
      return AppRoutes.teacherDashboard;
    case AppRoles.parent:
      return AppRoutes.parentDashboard;
    case AppRoles.student:
      return AppRoutes.studentDashboard;
    case AppRoles.financeManager:
      return AppRoutes.schoolAdminFinance;
    case AppRoles.registrar:
      return AppRoutes.schoolAdminAdmissions;
    default:
      return AppRoutes.profilePicker;
  }
}

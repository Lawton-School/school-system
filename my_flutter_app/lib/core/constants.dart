// Application-wide constants

class AppConstants {
  AppConstants._();

  // Supabase Configuration (Connected to ZivoConnect Live Cloud Project)
  static const String supabaseUrl = 'https://drxnnhjxjpyadwccaxnk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyeG5uaGp4anB5YWR3Y2NheG5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMTc4NjEsImV4cCI6MjEwMTg5Mzg2MX0.q1vONwqQuqbYmn0GemxJimh5qkiRBIaKkgi5NyehkLU';

  // OpenRouter DeepSeek Configuration for Live AI Tutor.
  // Supply with: --dart-define=OPENROUTER_API_KEY=...
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');
  static const String aiModel = 'deepseek/deepseek-chat';

  // Local DB
  static const String localDbName = 'ems_local.db';

  // Shared Preferences Keys
  static const String prefActiveSchoolId = 'active_school_id';
  static const String prefActiveRole = 'active_role';
  static const String prefActiveProfileId = 'active_profile_id';

  // App metadata
  static const String appName = 'ZivoConnect';
  static const String appVersion = '1.0.0';
}

class AppRoles {
  AppRoles._();

  static const String superAdmin = 'super_admin';
  static const String schoolAdmin = 'school_admin';
  static const String teacher = 'teacher';
  static const String parent = 'parent';
  static const String student = 'student';
  static const String financeManager = 'finance_manager';
  static const String registrar = 'registrar';

  static const List<String> all = [
    superAdmin,
    schoolAdmin,
    teacher,
    parent,
    student,
    financeManager,
    registrar,
  ];

  static String displayName(String role) {
    switch (role) {
      case superAdmin:
        return 'Super Admin';
      case schoolAdmin:
        return 'School Admin';
      case teacher:
        return 'Teacher';
      case parent:
        return 'Parent';
      case student:
        return 'Student';
      case financeManager:
        return 'Finance Manager';
      case registrar:
        return 'Registrar';
      default:
        return role;
    }
  }
}

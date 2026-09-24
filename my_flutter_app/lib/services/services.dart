// ZivoConnect service barrel.
//
// Legacy non-AI services remain available without forcing a risky rewrite of
// the large historical service file during the security cutover. The two AI
// service class names are intentionally hidden and replaced by secure
// Supabase Edge Function implementations.

export 'legacy_services.dart' hide AiTutorService, TeacherAiService;
export 'secure_ai_services.dart';
export 'profile_switch_service.dart';

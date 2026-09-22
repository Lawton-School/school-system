import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/rpc_client.dart';

/// Central Auth Session Controller
/// Provides:
/// - Authenticated user
/// - Active profile, school, and role
/// - Logout and profile switching
/// - Throttled touch_active_profile heartbeat on active profile resolution
class AuthSessionController extends StateNotifier<ActiveSession?> {
  final SharedPreferences _prefs;
  final SupabaseClient _client;
  final RpcClient _rpc;

  DateTime? _lastHeartbeatTime;

  AuthSessionController(this._prefs, this._client, this._rpc) : super(null) {
    _loadFromPrefs();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

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
      // Trigger throttled heartbeat
      _sendHeartbeatThrottled();
    }
  }

  /// Sets the active profile / school context and fires touch_active_profile heartbeat
  Future<void> setActiveSession(ActiveSession session) async {
    await Future.wait([
      _prefs.setString(AppConstants.prefActiveSchoolId, session.schoolId),
      _prefs.setString(AppConstants.prefActiveRole, session.role),
      _prefs.setString(AppConstants.prefActiveProfileId, session.profileId),
      _prefs.setString('active_school_name', session.schoolName),
    ]);
    state = session;
    await _sendHeartbeatThrottled(force: true);
  }

  /// Clear the active session and preferences
  Future<void> clearSession() async {
    await Future.wait([
      _prefs.remove(AppConstants.prefActiveSchoolId),
      _prefs.remove(AppConstants.prefActiveRole),
      _prefs.remove(AppConstants.prefActiveProfileId),
      _prefs.remove('active_school_name'),
    ]);
    state = null;
  }

  /// Sign out completely from Supabase and clear session
  Future<void> signOut() async {
    await clearSession();
    await _client.auth.signOut();
  }

  /// Throttled heartbeat to call touch_active_profile(platform, app_version)
  Future<void> _sendHeartbeatThrottled({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastHeartbeatTime != null && now.difference(_lastHeartbeatTime!).inMinutes < 15) {
      return;
    }

    try {
      await _rpc.touchActiveProfile(force: force);
      _lastHeartbeatTime = now;
      debugPrint('[AuthSessionController] touch_active_profile sent successfully for profile ${state?.profileId}');
    } catch (e) {
      debugPrint('[AuthSessionController] touch_active_profile error: $e');
    }
  }
}

/// Provider for AuthSessionController
final authSessionControllerProvider = StateNotifierProvider<AuthSessionController, ActiveSession?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final client = ref.watch(supabaseClientProvider);
  final rpc = ref.watch(rpcClientProvider);
  return AuthSessionController(prefs, client, rpc);
});

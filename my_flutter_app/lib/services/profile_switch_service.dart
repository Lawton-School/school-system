import 'package:supabase_flutter/supabase_flutter.dart';

class SwitchedProfileContext {
  final String profileId;
  final String schoolId;
  final String role;
  final String firstName;
  final String lastName;

  const SwitchedProfileContext({
    required this.profileId,
    required this.schoolId,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  factory SwitchedProfileContext.fromMap(Map<String, dynamic> map) {
    final profileId = map['profile_id']?.toString() ?? '';
    final schoolId = map['school_id']?.toString() ?? '';
    final role = map['role']?.toString() ?? '';

    if (profileId.isEmpty || schoolId.isEmpty || role.isEmpty) {
      throw StateError('Profile switch returned incomplete context.');
    }

    return SwitchedProfileContext(
      profileId: profileId,
      schoolId: schoolId,
      role: role,
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
    );
  }
}

/// Server-authoritative active-profile switching.
///
/// The Edge Function derives school/role/profile claims from the selected
/// profile owned by the authenticated user. Flutter never sends role or tenant
/// claims itself.
class ProfileSwitchService {
  final SupabaseClient _client;

  ProfileSwitchService(this._client);

  Future<SwitchedProfileContext> switchProfile(String profileId) async {
    if (_client.auth.currentSession == null) {
      throw StateError('An authenticated session is required.');
    }

    final response = await _client.functions.invoke(
      'switch-profile',
      body: {'profile_id': profileId},
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError('Could not switch profile (${response.status}).');
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('Profile switch returned an invalid response.');
    }

    final activeRaw = data['active_profile'];
    if (activeRaw is! Map) {
      throw StateError('Profile switch returned no active profile.');
    }

    final active = SwitchedProfileContext.fromMap(
      Map<String, dynamic>.from(activeRaw),
    );

    if (data['refresh_session'] == true) {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session == null) {
        throw StateError('Session refresh failed after profile switch.');
      }
    }

    final user = _client.auth.currentUser;
    final metadata = user?.appMetadata ?? const <String, dynamic>{};
    final jwtProfileId = metadata['profile_id']?.toString();
    final jwtSchoolId = metadata['school_id']?.toString();
    final jwtRole = metadata['role']?.toString();

    if (jwtProfileId != active.profileId ||
        jwtSchoolId != active.schoolId ||
        jwtRole != active.role) {
      throw StateError('Refreshed session does not match the selected profile.');
    }

    return active;
  }
}

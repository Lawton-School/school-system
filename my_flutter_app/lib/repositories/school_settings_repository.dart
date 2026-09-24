import 'package:supabase_flutter/supabase_flutter.dart';

class SchoolSettingsRepository {
  final SupabaseClient _client;

  const SchoolSettingsRepository(this._client);

  Future<Map<String, dynamic>> fetchConfiguration() async {
    final response = await _client.rpc('get_school_configuration');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profilePatch,
  ) async {
    final response = await _client.rpc(
      'patch_school_configuration',
      params: {
        'p_profile_patch': profilePatch,
        'p_settings_patch': <String, dynamic>{},
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }
}

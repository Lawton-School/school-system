import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'legacy_services.dart' as legacy;

/// Server-authoritative facade for Super Admin school operations.
///
/// The frozen Super Admin UI still consumes [SchoolModel], but reads the
/// authoritative cross-tenant directory RPC rather than querying `schools`
/// directly from Flutter. Operational status changes also go through the
/// validated RPC contract.
class SchoolService extends legacy.SchoolService {
  final SupabaseClient _client;

  SchoolService(this._client) : super(_client);

  @override
  Future<List<SchoolModel>> getAllSchools() async {
    final response = await _client.rpc('get_super_admin_schools_directory');
    final payload = Map<String, dynamic>.from(response as Map);
    final schools = (payload['schools'] as List<dynamic>?) ?? const [];

    return schools
        .whereType<Map>()
        .map((raw) {
          final row = Map<String, dynamic>.from(raw);
          return SchoolModel.fromMap({
            'id': row['school_id'],
            'name': row['name'],
            'subdomain': row['subdomain'],
            'settings': const <String, dynamic>{},
            'status': row['status'],
            'created_at': row['created_at'],
            // The directory RPC does not expose updated_at. Preserve the
            // existing model contract without inventing a backend field.
            'updated_at': row['created_at'],
          });
        })
        .toList(growable: false);
  }

  @override
  Future<void> setSchoolStatus(String schoolId, String status) async {
    if (status != 'active' && status != 'suspended') {
      throw ArgumentError.value(
        status,
        'status',
        'School status must be active or suspended.',
      );
    }

    await _client.rpc(
      'set_school_operational_status',
      params: {
        'p_school_id': schoolId,
        'p_status': status,
      },
    );
  }
}

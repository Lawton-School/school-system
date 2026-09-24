import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/school_settings_repository.dart';

final schoolSettingsRepositoryProvider = Provider<SchoolSettingsRepository>((ref) {
  return SchoolSettingsRepository(ref.watch(supabaseClientProvider));
});

final schoolConfigurationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(schoolSettingsRepositoryProvider).fetchConfiguration();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationCenterProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.fetchCenter(limit: 80);
});

class NotificationController {
  final Ref _ref;
  final NotificationRepository _repository;

  NotificationController(this._ref, this._repository);

  Future<void> markRead(String notificationId) async {
    await _repository.markRead(notificationId);
    _ref.invalidate(notificationCenterProvider);
  }

  Future<int> markAllRead() async {
    final count = await _repository.markAllRead();
    _ref.invalidate(notificationCenterProvider);
    return count;
  }

  void subscribe({
    required String activeProfileId,
  }) {
    _repository.subscribeToRealtime(
      activeProfileId: activeProfileId,
      onChanged: () => _ref.invalidate(notificationCenterProvider),
    );
  }

  void disposeRealtime() => _repository.disposeRealtime();
}

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController(
    ref,
    ref.watch(notificationRepositoryProvider),
  );
});

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/providers.dart';
import 'database/app_database.dart';

enum SyncStatus { online, offline, syncing, error }

enum SyncAction { insert, update, delete }

enum ConflictStrategy { serverWins, lastWriteWins }

class SyncQueueEntry {
  final String id;
  final String schoolId;
  final String tableName;
  final SyncAction action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const SyncQueueEntry({
    required this.id,
    required this.schoolId,
    required this.tableName,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Create from a Drift-generated [OfflineQueueEntry] row.
  factory SyncQueueEntry.fromRow(OfflineQueueEntry row) {
    return SyncQueueEntry(
      id: row.id,
      schoolId: row.schoolId,
      tableName: row.targetTable,
      action: SyncAction.values.firstWhere(
        (e) => e.name == row.action,
        orElse: () => SyncAction.insert,
      ),
      payload: Map<String, dynamic>.from(
        jsonDecode(row.payload) as Map,
      ),
      createdAt: row.createdAt,
      retryCount: row.retryCount,
      lastError: row.lastError,
    );
  }

  SyncQueueEntry copyWith({
    int? retryCount,
    String? lastError,
  }) {
    return SyncQueueEntry(
      id: id,
      schoolId: schoolId,
      tableName: tableName,
      action: action,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

class SyncEngineState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final int pendingCount;
  final int syncedCount;
  final String? errorMessage;
  final List<SyncQueueEntry> pendingQueue;

  const SyncEngineState({
    this.status = SyncStatus.online,
    this.lastSyncTime,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.errorMessage,
    this.pendingQueue = const [],
  });

  SyncEngineState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    int? pendingCount,
    int? syncedCount,
    String? errorMessage,
    List<SyncQueueEntry>? pendingQueue,
  }) {
    return SyncEngineState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      errorMessage: errorMessage,
      pendingQueue: pendingQueue ?? this.pendingQueue,
    );
  }
}

class SyncEngine extends StateNotifier<SyncEngineState> {
  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final AppDatabase _db;

  static const String _watermarkPrefix = 'sync_watermark_';

  SyncEngine(this._client, this._prefs, this._db)
      : super(const SyncEngineState()) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final rows = await (_db.select(_db.offlineQueueEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final queue = rows.map(SyncQueueEntry.fromRow).toList();

    final watermarkStr = _prefs.getString('${_watermarkPrefix}global');
    final lastSync =
        watermarkStr != null ? DateTime.tryParse(watermarkStr) : null;

    state = state.copyWith(
      pendingQueue: queue,
      pendingCount: queue.length,
      lastSyncTime: lastSync,
      status: SyncStatus.online,
    );
  }

  /// Enqueue an optimistic mutation (e.g. attendance marked offline, grade entered).
  Future<void> enqueueAction({
    required String schoolId,
    required String tableName,
    required SyncAction action,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        'queue_${DateTime.now().millisecondsSinceEpoch}_${payload['id'] ?? ''}';

    await _db.into(_db.offlineQueueEntries).insert(
          OfflineQueueEntriesCompanion.insert(
            id: id,
            schoolId: schoolId,
            targetTable: tableName,
            action: action.name,
            payload: jsonEncode(payload),
            createdAt: DateTime.now(),
          ),
        );

    final rows = await (_db.select(_db.offlineQueueEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final queue = rows.map(SyncQueueEntry.fromRow).toList();
    state = state.copyWith(pendingQueue: queue, pendingCount: queue.length);
  }

  /// Resolve conflict strategy based on the target table.
  ConflictStrategy getConflictStrategy(String tableName) {
    switch (tableName) {
      case 'invoices':
      case 'payments':
      case 'bursaries':
      case 'report_cards':
        return ConflictStrategy.serverWins;
      case 'daily_attendance':
      case 'grade_records':
      case 'profiles':
      case 'submissions':
      default:
        return ConflictStrategy.lastWriteWins;
    }
  }

  /// Run full bidirectional delta sync and outbox queue flush.
  Future<void> syncAll(String schoolId) async {
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    try {
      int flushed = 0;
      final rows = await (_db.select(_db.offlineQueueEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      for (final row in rows) {
        try {
          final payload =
              Map<String, dynamic>.from(jsonDecode(row.payload) as Map);

          if (row.action == SyncAction.insert.name ||
              row.action == SyncAction.update.name) {
            await _client.from(row.targetTable).upsert(payload);
          } else if (row.action == SyncAction.delete.name) {
            if (payload['id'] != null) {
              await _client.from(row.targetTable).update({
                'deleted_at': DateTime.now().toIso8601String(),
              }).eq('id', payload['id']);
            }
          }

          // Success — remove from queue
          await (_db.delete(_db.offlineQueueEntries)
                ..where((t) => t.id.equals(row.id)))
              .go();
          flushed++;
        } catch (e) {
          debugPrint('Sync failed for entry ${row.id}: $e');
          // Increment retry count & record error
          await (_db.update(_db.offlineQueueEntries)
                ..where((t) => t.id.equals(row.id)))
              .write(OfflineQueueEntriesCompanion(
            retryCount: Value(row.retryCount + 1),
            lastError: Value(e.toString()),
          ));
        }
      }

      // Re-read remaining queue
      final remaining = await (_db.select(_db.offlineQueueEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      // Update watermark
      final now = DateTime.now();
      await _prefs.setString('${_watermarkPrefix}global', now.toIso8601String());

      state = state.copyWith(
        status: remaining.isEmpty ? SyncStatus.online : SyncStatus.error,
        lastSyncTime: now,
        syncedCount: state.syncedCount + flushed,
        pendingQueue: remaining.map(SyncQueueEntry.fromRow).toList(),
        pendingCount: remaining.length,
        errorMessage: remaining.isNotEmpty
            ? '${remaining.length} item(s) failed to sync'
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Manually toggle simulated offline mode for testing.
  void toggleOfflineMode() {
    if (state.status == SyncStatus.offline) {
      state = state.copyWith(status: SyncStatus.online);
    } else {
      state = state.copyWith(status: SyncStatus.offline);
    }
  }
}

final syncEngineProvider =
    StateNotifierProvider<SyncEngine, SyncEngineState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(appDatabaseProvider);
  return SyncEngine(client, prefs, db);
});

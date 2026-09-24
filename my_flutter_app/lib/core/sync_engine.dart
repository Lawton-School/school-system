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

  /// Only these mutations have deliberately designed offline semantics today.
  /// Finance, report-card publication/approval, tenant changes and other
  /// server-authoritative operations must never be silently queued here.
  static const Set<String> _offlineSafeTables = {
    'daily_attendance',
    'grade_records',
  };

  SyncEngine(this._client, this._prefs, this._db)
      : super(const SyncEngineState()) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final rows = await (_db.select(_db.offlineQueueEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final queue = rows.map(SyncQueueEntry.fromRow).toList(growable: false);

    state = state.copyWith(
      pendingQueue: queue,
      pendingCount: queue.length,
      status: SyncStatus.online,
    );
  }

  Future<void> enqueueAction({
    required String schoolId,
    required String tableName,
    required SyncAction action,
    required Map<String, dynamic> payload,
  }) async {
    if (!_offlineSafeTables.contains(tableName)) {
      throw StateError(
        'Offline queue rejected unsafe/server-authoritative table: $tableName',
      );
    }
    if (action == SyncAction.delete) {
      throw StateError(
        'Offline delete is not supported for $tableName.',
      );
    }

    final payloadSchoolId = payload['school_id']?.toString();
    if (payloadSchoolId == null || payloadSchoolId != schoolId) {
      throw StateError(
        'Offline payload school_id must match the active school.',
      );
    }

    final identity = switch (tableName) {
      'daily_attendance' =>
        '${payload['student_profile_id'] ?? ''}_${payload['date'] ?? ''}',
      'grade_records' =>
        '${payload['assessment_id'] ?? ''}_${payload['student_profile_id'] ?? ''}',
      _ => '',
    };
    final id =
        'queue_${DateTime.now().microsecondsSinceEpoch}_${tableName}_$identity';

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

    await _refreshQueueState();
  }

  /// Flush only the safe offline outbox entries for one school.
  ///
  /// This is intentionally not described as a bidirectional sync engine: the
  /// current implementation is an outbox flush plus separate read caches.
  Future<void> syncAll(String schoolId) async {
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    try {
      int flushed = 0;
      final rows = await (_db.select(_db.offlineQueueEntries)
            ..where((t) => t.schoolId.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      for (final row in rows) {
        try {
          if (!_offlineSafeTables.contains(row.targetTable)) {
            throw StateError(
              'Queued table ${row.targetTable} is no longer offline-safe.',
            );
          }

          final payload =
              Map<String, dynamic>.from(jsonDecode(row.payload) as Map);
          if (payload['school_id']?.toString() != schoolId) {
            throw StateError('Queued payload school mismatch.');
          }

          if (row.action != SyncAction.insert.name &&
              row.action != SyncAction.update.name) {
            throw StateError(
              'Unsupported queued action ${row.action} for ${row.targetTable}.',
            );
          }

          switch (row.targetTable) {
            case 'daily_attendance':
              await _client.from('daily_attendance').upsert(
                    payload,
                    onConflict: 'student_profile_id,date',
                  );
            case 'grade_records':
              await _client.from('grade_records').upsert(
                    payload,
                    onConflict: 'assessment_id,student_profile_id',
                  );
          }

          await (_db.delete(_db.offlineQueueEntries)
                ..where((t) => t.id.equals(row.id)))
              .go();
          flushed++;
        } catch (e) {
          debugPrint('Sync failed for entry ${row.id}: $e');
          await (_db.update(_db.offlineQueueEntries)
                ..where((t) => t.id.equals(row.id)))
              .write(
            OfflineQueueEntriesCompanion(
              retryCount: Value(row.retryCount + 1),
              lastError: Value(e.toString()),
            ),
          );
        }
      }

      final activeSchoolRemaining = await (_db.select(_db.offlineQueueEntries)
            ..where((t) => t.schoolId.equals(schoolId)))
          .get();
      final allRemaining = await (_db.select(_db.offlineQueueEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      final now = DateTime.now();
      await _prefs.setString(
        '$_watermarkPrefix$schoolId',
        now.toIso8601String(),
      );

      state = state.copyWith(
        status: activeSchoolRemaining.isEmpty
            ? SyncStatus.online
            : SyncStatus.error,
        lastSyncTime: now,
        syncedCount: state.syncedCount + flushed,
        pendingQueue:
            allRemaining.map(SyncQueueEntry.fromRow).toList(growable: false),
        pendingCount: allRemaining.length,
        errorMessage: activeSchoolRemaining.isNotEmpty
            ? '${activeSchoolRemaining.length} item(s) failed to sync for the active school'
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _refreshQueueState() async {
    final rows = await (_db.select(_db.offlineQueueEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final queue = rows.map(SyncQueueEntry.fromRow).toList(growable: false);
    state = state.copyWith(
      pendingQueue: queue,
      pendingCount: queue.length,
    );
  }

  /// Manual offline simulation retained for diagnostics/tests. Real network
  /// connectivity detection is still a separate platform-level task.
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

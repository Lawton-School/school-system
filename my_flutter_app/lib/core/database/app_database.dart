import 'package:drift/drift.dart';
import 'connection/connection.dart' as conn;

part 'app_database.g.dart';

/// Drift Table for Outbox Mutations (Offline Queue)
class OfflineQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get targetTable => text()(); // The Supabase table to sync to
  TextColumn get action => text()(); // insert, update, delete
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift Table for Authoritative KPI / Metrics Cache
class CachedKpis extends Table {
  TextColumn get kpiKey => text()(); // e.g. school_admin_dashboard, teacher_dashboard
  TextColumn get schoolId => text()();
  TextColumn get data => text()(); // Authoritative JSON payload
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {kpiKey, schoolId};
}

/// Drift Table for Authoritative Roster & List Cache
class CachedRosters extends Table {
  TextColumn get rosterKey => text()(); // e.g. roll_call_10A_2026-09-21
  TextColumn get schoolId => text()();
  TextColumn get data => text()(); // Authoritative JSON array payload
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {rosterKey, schoolId};
}

@DriftDatabase(tables: [OfflineQueueEntries, CachedKpis, CachedRosters])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(conn.openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

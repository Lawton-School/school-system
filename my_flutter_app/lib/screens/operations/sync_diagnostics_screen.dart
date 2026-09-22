import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync_engine.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';

class SyncDiagnosticsScreen extends ConsumerWidget {
  const SyncDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider.notifier);
    final session = ref.watch(activeSessionProvider);
    final schoolId = session?.schoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sync & Diagnostics'),
        actions: [
          IconButton(
            icon: Icon(
              syncState.status == SyncStatus.offline
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
              color: syncState.status == SyncStatus.offline
                  ? AppTheme.warning
                  : AppTheme.success,
            ),
            tooltip: 'Toggle Offline Simulation',
            onPressed: () => syncEngine.toggleOfflineMode(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner Card
            _buildStatusCard(context, syncState, syncEngine, schoolId),
            const SizedBox(height: 20),

            // Sync Rules & Conflict Strategy Summary
            _buildConflictMatrixCard(context),
            const SizedBox(height: 20),

            // Outbox Queue List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Outbox Mutations (${syncState.pendingCount})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (syncState.pendingCount > 0)
                  ElevatedButton.icon(
                    onPressed: syncState.status == SyncStatus.syncing
                        ? null
                        : () => syncEngine.syncAll(schoolId),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Flush Outbox'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (syncState.pendingQueue.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.success),
                        SizedBox(height: 10),
                        Text('Outbox is clean. All local changes are synced to cloud.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...syncState.pendingQueue.map((entry) => _buildQueueItemCard(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, SyncEngineState state, SyncEngine engine, String schoolId) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.status) {
      case SyncStatus.syncing:
        statusColor = AppTheme.primary;
        statusText = 'Synchronizing Delta Changes...';
        statusIcon = Icons.sync_rounded;
        break;
      case SyncStatus.offline:
        statusColor = AppTheme.warning;
        statusText = 'Offline Mode (Local Storage Only)';
        statusIcon = Icons.cloud_off_rounded;
        break;
      case SyncStatus.error:
        statusColor = AppTheme.danger;
        statusText = 'Sync Error Occurred';
        statusIcon = Icons.error_outline_rounded;
        break;
      case SyncStatus.online:
        statusColor = AppTheme.success;
        statusText = 'Online & Cloud Synchronized';
        statusIcon = Icons.cloud_done_rounded;
        break;
    }

    final watermark = state.lastSyncTime != null
        ? '${state.lastSyncTime!.hour}:${state.lastSyncTime!.minute.toString().padLeft(2, '0')}:${state.lastSyncTime!.second.toString().padLeft(2, '0')}'
        : 'Never';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withAlpha(25),
                  radius: 22,
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Last Sync Watermark: $watermark',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Pending Mutations', value: '${state.pendingCount}', color: AppTheme.warning),
                _StatItem(label: 'Processed Syncs', value: '${state.syncedCount}', color: AppTheme.success),
                _StatItem(label: 'Engine Engine', value: 'Delta LWW', color: AppTheme.accent),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.status == SyncStatus.syncing ? null : () => engine.syncAll(schoolId),
                icon: state.status == SyncStatus.syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded),
                label: Text(state.status == SyncStatus.syncing ? 'Syncing...' : 'Force Full Bidirectional Sync'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictMatrixCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rule_rounded, color: AppTheme.secondary, size: 20),
                SizedBox(width: 8),
                Text('Conflict Resolution Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            _buildMatrixRow('Financial Ledgers & Invoices', 'Server-Wins (Strict Authority)', AppTheme.primary),
            _buildMatrixRow('Official Report Cards Approvals', 'Server-Wins (Admin Lock)', AppTheme.primary),
            _buildMatrixRow('Daily Attendance Records', 'Last-Write-Wins (Timestamp)', AppTheme.success),
            _buildMatrixRow('Assignment Grades & Submissions', 'Last-Write-Wins (Teacher Priority)', AppTheme.success),
            _buildMatrixRow('Tombstone Soft Deletions', 'Remote Purge (deleted_at filter)', AppTheme.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixRow(String scope, String rule, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(scope, style: const TextStyle(fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(rule, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemCard(SyncQueueEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.warning.withAlpha(25),
          child: Text(entry.action.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warning)),
        ),
        title: Text('${entry.tableName.toUpperCase()} (${entry.action.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Queued: ${entry.createdAt.hour}:${entry.createdAt.minute.toString().padLeft(2, '0')} • Retries: ${entry.retryCount}'),
        trailing: entry.lastError != null
            ? const Tooltip(
                message: 'Sync error on last attempt',
                child: Icon(Icons.error_outline_rounded, color: AppTheme.danger),
              )
            : const Icon(Icons.schedule_rounded, color: AppTheme.textMuted),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// Reusable Sync Status Badge that appears in App Bars across Shells
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncEngineProvider);

    Color color;
    IconData icon;
    String label;

    switch (state.status) {
      case SyncStatus.syncing:
        color = AppTheme.primary;
        icon = Icons.sync_rounded;
        label = 'Syncing';
        break;
      case SyncStatus.offline:
        color = AppTheme.warning;
        icon = Icons.cloud_off_rounded;
        label = 'Offline (${state.pendingCount})';
        break;
      case SyncStatus.error:
        color = AppTheme.danger;
        icon = Icons.error_outline_rounded;
        label = 'Error';
        break;
      case SyncStatus.online:
        color = AppTheme.success;
        icon = Icons.cloud_done_rounded;
        label = 'Online';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncDiagnosticsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

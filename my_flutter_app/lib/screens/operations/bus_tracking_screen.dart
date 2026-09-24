import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class BusTrackingScreen extends ConsumerStatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  ConsumerState<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends ConsumerState<BusTrackingScreen> {
  BusRouteModel? _selectedRoute;
  RealtimeChannel? _telemetryChannel;
  String? _subscribedRouteId;

  @override
  void dispose() {
    if (_telemetryChannel != null) {
      ref.read(supabaseClientProvider).removeChannel(_telemetryChannel!);
      _telemetryChannel = null;
    }
    super.dispose();
  }

  void _subscribeTelemetry(String schoolId, String routeId) {
    if (_subscribedRouteId == routeId) return;

    final client = ref.read(supabaseClientProvider);
    if (_telemetryChannel != null) {
      client.removeChannel(_telemetryChannel!);
    }

    _subscribedRouteId = routeId;
    _telemetryChannel = client.channel('fleet:$schoolId:$routeId');
    _telemetryChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bus_telemetry',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'route_id',
            value: routeId,
          ),
          callback: (_) {
            if (!mounted) return;
            ref.invalidate(busTelemetryProvider((schoolId, routeId)));
          },
        )
        .subscribe();
  }

  void _showAddRouteDialog(BuildContext context, String schoolId) {
    final nameCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bus Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Route Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle Number / Plate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverCtrl,
                decoration: const InputDecoration(labelText: 'Driver Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Driver Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty) return;
              final client = ref.read(supabaseClientProvider);
              await BusTrackingService(client).createBusRoute(
                schoolId: schoolId,
                routeName: nameCtrl.text.trim(),
                driverName: driverCtrl.text.trim().isNotEmpty ? driverCtrl.text.trim() : null,
                driverPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                vehicleNumber: plateCtrl.text.trim(),
              );
              ref.invalidate(busRoutesProvider(schoolId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Route'),
          ),
        ],
      ),
    );
  }

  void _showAddStopDialog(BuildContext context, String schoolId, String routeId) {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bus Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Stop Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final latitude = double.tryParse(latCtrl.text.trim());
              final longitude = double.tryParse(lngCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty || latitude == null || longitude == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a stop name and valid coordinates.')),
                );
                return;
              }
              final client = ref.read(supabaseClientProvider);
              await BusTrackingService(client).createBusStop(
                schoolId: schoolId,
                routeId: routeId,
                stopName: nameCtrl.text.trim(),
                latitude: latitude,
                longitude: longitude,
              );
              ref.invalidate(busStopsProvider((schoolId, routeId)));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final routesAsync = ref.watch(busRoutesProvider(schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Live Bus Tracking & Fleet')),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bus_rounded, size: 54, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('No bus routes configured yet.', style: TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRouteDialog(context, schoolId),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create First Route'),
                  ),
                ],
              ),
            );
          }

          _selectedRoute ??= routes.first;
          final selected = _selectedRoute!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _subscribeTelemetry(schoolId, selected.id);
          });

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.surfaceDark,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<BusRouteModel>(
                        initialValue: _selectedRoute,
                        decoration: const InputDecoration(
                          labelText: 'Select Route',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: routes
                            .map((r) => DropdownMenuItem(value: r, child: Text('${r.routeName} (${r.vehicleNumber})')))
                            .toList(),
                        onChanged: (route) {
                          if (route == null) return;
                          setState(() => _selectedRoute = route);
                          _subscribeTelemetry(schoolId, route.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _showAddRouteDialog(context, schoolId),
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Add Route',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTelemetryCard(schoolId, selected),
                      const SizedBox(height: 16),
                      _buildDriverInfoCard(selected),
                      const SizedBox(height: 16),
                      _buildStopsTimeline(schoolId, selected),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTelemetryCard(String schoolId, BusRouteModel route) {
    final telemetryAsync = ref.watch(busTelemetryProvider((schoolId, route.id)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors_rounded, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text('GPS Telemetry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(label: Text('Realtime feed')),
              ],
            ),
            const SizedBox(height: 14),
            telemetryAsync.when(
              data: (telemetry) {
                if (telemetry == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gps_off_rounded, color: AppTheme.textMuted),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No GPS telemetry has been received for this route. A real GPS device/provider must publish telemetry before live location is available.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final age = DateTime.now().difference(telemetry.recordedAt);
                final stale = age.inMinutes >= 10;
                final time = '${telemetry.recordedAt.day}/${telemetry.recordedAt.month} '
                    '${telemetry.recordedAt.hour}:${telemetry.recordedAt.minute.toString().padLeft(2, '0')}';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Wrap(
                    spacing: 30,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      _TelemetryStat(
                        label: 'Current Speed',
                        value: '${telemetry.speed.toStringAsFixed(1)} km/h',
                        color: AppTheme.primaryLight,
                      ),
                      _TelemetryStat(
                        label: 'Coordinates',
                        value: '${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)}',
                        color: AppTheme.secondary,
                      ),
                      _TelemetryStat(
                        label: stale ? 'Last Ping · Stale' : 'Last Ping',
                        value: time,
                        color: stale ? AppTheme.warning : AppTheme.success,
                      ),
                    ],
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(BusRouteModel route) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primary,
              radius: 24,
              child: Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle: ${route.vehicleNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Driver: ${route.driverName ?? "Not assigned"} • ${route.driverPhone ?? "No phone"}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsTimeline(String schoolId, BusRouteModel route) {
    final stopsAsync = ref.watch(busStopsProvider((schoolId, route.id)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sequential Stops Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => _showAddStopDialog(context, schoolId, route.id),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('Add Stop'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            stopsAsync.when(
              data: (stops) {
                if (stops.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('No bus stops configured on this route.', style: TextStyle(color: AppTheme.textMuted))),
                  );
                }
                return Column(
                  children: stops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? AppTheme.success : AppTheme.primary,
                              ),
                              child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                            ),
                            if (index != stops.length - 1)
                              Container(width: 2, height: 36, color: AppTheme.borderDark),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.stopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  'Lat: ${stop.latitude.toStringAsFixed(4)}, Lng: ${stop.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading stops: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TelemetryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}

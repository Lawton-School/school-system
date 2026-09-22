import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _simulating = false;

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
                decoration: const InputDecoration(labelText: 'Route Name (e.g. Northern Route #1)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle Number / Plate (e.g. ABZ-4921)'),
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
    final latCtrl = TextEditingController(text: '-17.82485');
    final lngCtrl = TextEditingController(text: '31.05303');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bus Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Stop Name (e.g. Avondale Shopping Centre)'),
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
              if (nameCtrl.text.trim().isEmpty) return;
              final lat = double.tryParse(latCtrl.text.trim()) ?? -17.82485;
              final lng = double.tryParse(lngCtrl.text.trim()) ?? 31.05303;
              final client = ref.read(supabaseClientProvider);
              await BusTrackingService(client).createBusStop(
                schoolId: schoolId,
                routeId: routeId,
                stopName: nameCtrl.text.trim(),
                latitude: lat,
                longitude: lng,
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

  Future<void> _simulateDriverPing(String schoolId, String routeId) async {
    setState(() => _simulating = true);
    final client = ref.read(supabaseClientProvider);
    // Ping telemetry with moving coords
    await BusTrackingService(client).sendTelemetryPing(
      schoolId: schoolId,
      routeId: routeId,
      latitude: -17.82485 + (DateTime.now().second * 0.0001),
      longitude: 31.05303 + (DateTime.now().second * 0.0001),
      speed: 38.5,
    );
    ref.invalidate(busTelemetryProvider((schoolId, routeId)));
    if (mounted) {
      setState(() => _simulating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus GPS telemetry ping transmitted ✓')),
      );
    }
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
      appBar: AppBar(
        title: const Text('Live Bus Tracking & Fleet'),
      ),
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

          return Column(
            children: [
              // Route Selector Bar
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
                        onChanged: (v) => setState(() => _selectedRoute = v),
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

              // Live Telemetry Card & Map Mockup View
              if (_selectedRoute != null)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTelemetryCard(schoolId, _selectedRoute!),
                        const SizedBox(height: 16),
                        _buildDriverInfoCard(_selectedRoute!),
                        const SizedBox(height: 16),
                        _buildStopsTimeline(schoolId, _selectedRoute!),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Live GPS Radar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _simulating ? null : () => _simulateDriverPing(schoolId, route.id),
                  icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                  label: _simulating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ping GPS (Driver)'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            telemetryAsync.when(
              data: (t) {
                final speed = t != null ? '${t.speed.toStringAsFixed(1)} km/h' : '0.0 km/h (Stationary)';
                final lat = t != null ? t.latitude.toStringAsFixed(5) : '-17.82485';
                final lng = t != null ? t.longitude.toStringAsFixed(5) : '31.05303';
                final time = t != null ? '${t.recordedAt.hour}:${t.recordedAt.minute.toString().padLeft(2, '0')}' : 'Just now';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TelemetryStat(label: 'Current Speed', value: speed, color: AppTheme.primaryLight),
                      _TelemetryStat(label: 'Coordinates', value: '$lat, $lng', color: AppTheme.secondary),
                      _TelemetryStat(label: 'Last Ping', value: time, color: AppTheme.accent),
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
                  Text('Driver: ${route.driverName ?? "Assigned Fleet Driver"} • ${route.driverPhone ?? "No phone"}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
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
                              Container(
                                width: 2,
                                height: 36,
                                color: AppTheme.borderDark,
                              ),
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
                                Text('Lat: ${stop.latitude.toStringAsFixed(4)}, Lng: ${stop.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
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

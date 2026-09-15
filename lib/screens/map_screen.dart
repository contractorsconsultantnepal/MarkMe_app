import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/hazard_data.dart';
import '../models/hazard_zone.dart';
import '../services/geofence_service.dart';
import '../services/live_hazard_service.dart';
import '../services/river_basin_service.dart';
import '../data/river_basin_data.dart';
import '../utils/point_in_polygon.dart';
import '../widgets/hazard_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LiveHazardService _liveService = LiveHazardService();
  final RiverBasinService _riverService = RiverBasinService();
  late GeofenceService _geofence;
  LatLng? _userPosition;
  final Set<ZoneColor> _visibleColors = ZoneColor.values.toSet();

  List<HazardZone> _liveZones = [];
  List<HazardZone> _riverZones = [];
  bool _loadingLive = false;
  DateTime? _lastLiveRefresh;
  String? _liveError;
  Timer? _autoRefreshTimer;

  List<HazardZone> get _allZones => [...sampleHazardZones, ..._liveZones, ..._riverZones];

  @override
  void initState() {
    super.initState();
    _geofence = GeofenceService(_allZones);
    _geofence.start();
    _geofence.positionStream.listen((pos) {
      if (mounted) setState(() => _userPosition = pos);
    });

    _refreshLiveHazards();
    // Global feeds update every minute or so upstream; poll every 5 minutes
    // to stay current without hammering the free public APIs.
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refreshLiveHazards());
  }

  Future<void> _refreshLiveHazards() async {
    setState(() {
      _loadingLive = true;
      _liveError = null;
    });
    try {
      final results = await Future.wait([
        _liveService.fetchAll(),
        _riverService.computeBasinZones(),
      ]);
      if (!mounted) return;
      setState(() {
        _liveZones = results[0];
        _riverZones = results[1];
        _lastLiveRefresh = DateTime.now();
        _loadingLive = false;
      });
      // Geofence checks should include freshly fetched live hazards too.
      _geofence.dispose();
      _geofence = GeofenceService(_allZones);
      _geofence.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLive = false;
        _liveError = 'Could not reach live hazard feeds — showing cached/static zones.';
      });
    }
  }

  @override
  void dispose() {
    _geofence.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  List<HazardZone> get _visibleZones =>
      _allZones.where((z) => _visibleColors.contains(z.color)).toList();

  String get _feedStatus {
    if (_loadingLive) return 'Loading live hazard and basin data...';
    if (_lastLiveRefresh == null) return 'Static zones loaded; live feeds pending.';
    if (_liveZones.isEmpty && _riverZones.isEmpty) {
      return 'Live feeds returned no zones; showing the static dataset.';
    }
    return 'Loaded ${_liveZones.length} live hazards and ${_riverZones.length} basin zones.';
  }

  LatLng _zoneCenter(HazardZone zone) {
    if (zone.polygon.isEmpty) return const LatLng(27.7172, 85.3240);
    final latitude = zone.polygon.map((point) => point.latitude).reduce((a, b) => a + b) / zone.polygon.length;
    final longitude = zone.polygon.map((point) => point.longitude).reduce((a, b) => a + b) / zone.polygon.length;
    return LatLng(latitude, longitude);
  }

  void _showAllData() {
    final points = [
      ...sampleRiverBasins.expand((basin) => basin.courseLine),
      ..._allZones.expand((zone) => zone.polygon),
    ];
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _handleTap(TapPosition tapPos, LatLng point) {
    // Find the first visible zone whose polygon contains the tapped point.
    for (final zone in _visibleZones) {
      if (isPointInPolygon(point, zone.polygon)) {
        showHazardDetailSheet(context, zone);
        return;
      }
    }
  }

  Color _fillColor(ZoneColor c) {
    switch (c) {
      case ZoneColor.green:
        return Colors.green.withValues(alpha: 0.35);
      case ZoneColor.yellow:
        return Colors.amber.withValues(alpha: 0.35);
      case ZoneColor.blue:
        return Colors.blue.withValues(alpha: 0.35);
      case ZoneColor.red:
        return Colors.red.withValues(alpha: 0.4);
    }
  }

  Color _borderColor(ZoneColor c) {
    switch (c) {
      case ZoneColor.green:
        return Colors.green.shade800;
      case ZoneColor.yellow:
        return Colors.amber.shade800;
      case ZoneColor.blue:
        return Colors.blue.shade800;
      case ZoneColor.red:
        return Colors.red.shade900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarkMe — Hazard Map'),
        actions: [
          IconButton(
            icon: _loadingLive
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh live hazards',
            onPressed: _loadingLive ? null : _refreshLiveHazards,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Show all loaded hazards',
            onPressed: _showAllData,
          ),
          PopupMenuButton<ZoneColor>(
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: (color) {
              setState(() {
                if (_visibleColors.contains(color)) {
                  _visibleColors.remove(color);
                } else {
                  _visibleColors.add(color);
                }
              });
            },
            itemBuilder: (context) => ZoneColor.values.map((c) {
              return CheckedPopupMenuItem(
                value: c,
                checked: _visibleColors.contains(c),
                child: Text(c.label),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_liveError != null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(_liveError!, style: const TextStyle(fontSize: 12)),
            )
          else if (_lastLiveRefresh != null)
            Container(
              width: double.infinity,
              color: Colors.deepPurple.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Live feeds: ${_liveZones.length} global hazards + ${_riverZones.length} river-basin zones '
                '(USGS · NASA EONET · Open-Meteo) · updated ${_lastLiveRefresh!.toLocal().toString().split('.').first}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_lastLiveRefresh == null || _liveZones.isEmpty || _riverZones.isEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(_feedStatus, style: const TextStyle(fontSize: 12)),
            ),
          if (_liveZones.isNotEmpty || _riverZones.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [..._liveZones, ..._riverZones].take(8).map((zone) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: Icon(zone.isLive ? Icons.podcasts : Icons.layers, size: 16),
                      label: Text(zone.name, overflow: TextOverflow.ellipsis),
                      onPressed: () => _mapController.move(_zoneCenter(zone), 10),
                    ),
                  );
                }).toList(),
              ),
            ),
          Container(
            width: double.infinity,
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accuracy disclaimer: modeled and aggregated from public sources; not a substitute for official emergency guidance, professional survey, or local authority instructions.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (sampleRiverBasins.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'River dataset: ${sampleRiverBasins.first.source} · version ${sampleRiverBasins.first.sourceVersion} · last verified ${sampleRiverBasins.first.lastVerified.toLocal().toString().split('.').first}',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(27.7172, 85.3240), // Kathmandu default
                initialZoom: 6,
                onTap: _handleTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.markme_app',
                ),
                PolygonLayer(
                  polygons: _visibleZones
                      .map((zone) => Polygon(
                            points: zone.polygon,
                            color: _fillColor(zone.color),
                            borderColor: _borderColor(zone.color),
                            borderStrokeWidth: zone.isLive ? 3 : 2,
                            label: zone.name,
                          ))
                      .toList(),
                ),
                PolylineLayer(
                  polylines: sampleRiverBasins
                      .map((basin) => Polyline(
                            points: basin.courseLine,
                            color: Colors.lightBlue.shade700,
                            strokeWidth: basin.isGlofSource ? 3 : 2,
                          ))
                      .toList(),
                ),
                if (_userPosition != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _userPosition!,
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.my_location, color: Colors.deepPurple, size: 24),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_userPosition != null) {
            _mapController.move(_userPosition!, 13);
          }
        },
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}

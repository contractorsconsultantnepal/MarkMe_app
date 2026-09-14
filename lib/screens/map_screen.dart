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
  Set<ZoneColor> _visibleColors = ZoneColor.values.toSet();

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
        return Colors.green.withOpacity(0.35);
      case ZoneColor.yellow:
        return Colors.amber.withOpacity(0.35);
      case ZoneColor.blue:
        return Colors.blue.withOpacity(0.35);
      case ZoneColor.red:
        return Colors.red.withOpacity(0.4);
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

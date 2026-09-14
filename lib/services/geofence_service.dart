import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/hazard_zone.dart';
import '../utils/point_in_polygon.dart';
import 'notification_service.dart';

/// Watches the device's live location and fires a notification the moment
/// the user's position falls inside any `ZoneColor.red` polygon. Tracks
/// "currently inside" zone ids so it only alerts once per entry (not on
/// every location update), and clears the flag again once the user exits.
class GeofenceService {
  GeofenceService(this._zones);

  final List<HazardZone> _zones;
  final Set<String> _activeRedZoneIds = {};
  final Set<String> _activeGlofZoneIds = {};
  StreamSubscription<Position>? _sub;

  final _statusController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get positionStream => _statusController.stream;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    return true;
  }

  Future<void> start() async {
    final granted = await _ensurePermission();
    if (!granted) return;

    await NotificationService.instance.init();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // meters — re-check zones every ~15m of movement
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final point = LatLng(pos.latitude, pos.longitude);
      _statusController.add(point);
      _checkZones(point);
    });
  }

  void _checkZones(LatLng point) {
    final redZones = _zones.where((z) => z.color == ZoneColor.red);
    final currentlyInsideRed = <String>{};

    for (final zone in redZones) {
      if (isPointInPolygon(point, zone.polygon)) {
        currentlyInsideRed.add(zone.id);
        if (!_activeRedZoneIds.contains(zone.id)) {
          // Newly entered this red zone -> alert once.
          NotificationService.instance.showRedZoneAlert(
            zoneName: zone.name,
            hazardLabel: zone.category.label,
          );
        }
      }
    }
    _activeRedZoneIds
      ..clear()
      ..addAll(currentlyInsideRed);

    // GLOF river corridors alert on entry regardless of computed color —
    // being within 50m of a GLOF-prone river course is itself the risk.
    final glofZones = _zones.where((z) => z.category == HazardCategory.glof);
    final currentlyInsideGlof = <String>{};

    for (final zone in glofZones) {
      if (isPointInPolygon(point, zone.polygon)) {
        currentlyInsideGlof.add(zone.id);
        if (!_activeGlofZoneIds.contains(zone.id)) {
          NotificationService.instance.showGlofCorridorAlert(
            zoneName: zone.name,
            summary: zone.summary,
          );
        }
      }
    }
    _activeGlofZoneIds
      ..clear()
      ..addAll(currentlyInsideGlof);
  }

  void dispose() {
    _sub?.cancel();
    _statusController.close();
  }
}

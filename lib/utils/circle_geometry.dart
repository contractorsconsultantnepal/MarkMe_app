import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Builds an approximate circular polygon of [radiusKm] around [center].
/// Good enough for visualizing point-source hazards (earthquake epicenters,
/// volcano vents, wildfire origins) as an affected-area zone. Not geodesically
/// exact at very large radii or near the poles, but accurate enough for
/// hazard-awareness display purposes.
List<LatLng> circlePolygon(LatLng center, double radiusKm, {int points = 32}) {
  const earthRadiusKm = 6371.0;
  final lat1 = center.latitude * math.pi / 180;
  final lon1 = center.longitude * math.pi / 180;
  final angularDistance = radiusKm / earthRadiusKm;

  final result = <LatLng>[];
  for (int i = 0; i < points; i++) {
    final bearing = (i * 360 / points) * math.pi / 180;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );
    result.add(LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi));
  }
  return result;
}

import 'package:latlong2/latlong.dart';

/// Standard ray-casting point-in-polygon test.
/// Good enough for city/regional-scale hazard polygons; for very large
/// polygons spanning long distances consider a geodesic-aware library.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  bool inside = false;
  final n = polygon.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;

    final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);

    if (intersects) inside = !inside;
  }
  return inside;
}

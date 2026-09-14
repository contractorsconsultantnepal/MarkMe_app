import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Builds a ribbon/corridor polygon running `bufferMeters` on EACH side of
/// `line` (so total corridor width = 2 * bufferMeters). Used for:
///   - the mandated "50m both sides" GLOF river-corridor alert zone
///   - wider flood/flash-flood plain corridors
///
/// Uses a local flat-earth (equirectangular) projection around the line's
/// first point, which is accurate enough for corridors a few hundred meters
/// wide over river reaches of a few tens of km. For a country-scale or
/// production system, swap in a geodesic buffering library (e.g. via a
/// backend using GEOS/Turf) for full accuracy.
List<LatLng> buildRiverCorridor(List<LatLng> line, double bufferMeters) {
  if (line.length < 2) return [];

  final lat0 = line.first.latitude * math.pi / 180;
  const metersPerDegLat = 111320.0;
  final metersPerDegLon = 111320.0 * math.cos(lat0);

  // Project to local x/y meters.
  final pts = line
      .map((p) => _Vec(
            (p.longitude - line.first.longitude) * metersPerDegLon,
            (p.latitude - line.first.latitude) * metersPerDegLat,
          ))
      .toList();

  final left = <_Vec>[];
  final right = <_Vec>[];

  for (int i = 0; i < pts.length; i++) {
    // Direction at this vertex: average of incoming and outgoing segment
    // directions (falls back to the single available segment at endpoints).
    _Vec dir;
    if (i == 0) {
      dir = (pts[1] - pts[0]).normalized();
    } else if (i == pts.length - 1) {
      dir = (pts[i] - pts[i - 1]).normalized();
    } else {
      final d1 = (pts[i] - pts[i - 1]).normalized();
      final d2 = (pts[i + 1] - pts[i]).normalized();
      dir = (d1 + d2).normalized();
    }
    final normal = _Vec(-dir.y, dir.x); // perpendicular
    left.add(pts[i] + normal * bufferMeters);
    right.add(pts[i] - normal * bufferMeters);
  }

  // Corridor ring: left side forward, then right side backward to close.
  final ring = [...left, ...right.reversed];

  // Project back to lat/lon.
  return ring
      .map((v) => LatLng(
            line.first.latitude + v.y / metersPerDegLat,
            line.first.longitude + v.x / metersPerDegLon,
          ))
      .toList();
}

class _Vec {
  final double x, y;
  const _Vec(this.x, this.y);
  _Vec operator +(_Vec o) => _Vec(x + o.x, y + o.y);
  _Vec operator -(_Vec o) => _Vec(x - o.x, y - o.y);
  _Vec operator *(double s) => _Vec(x * s, y * s);
  double get length => math.sqrt(x * x + y * y);
  _Vec normalized() {
    final l = length;
    return l == 0 ? const _Vec(0, 0) : _Vec(x / l, y / l);
  }
}

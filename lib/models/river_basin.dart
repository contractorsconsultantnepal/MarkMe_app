import 'package:latlong2/latlong.dart';

/// A river's course, used to derive flood / flash-flood / GLOF corridor
/// zones. `courseLine` should run from upstream to downstream.
class RiverBasin {
  final String id;
  final String name;
  final List<LatLng> courseLine;

  /// True if this river is fed by a glacier/glacial lake with documented or
  /// monitored GLOF (Glacial Lake Outburst Flood) potential upstream.
  final bool isGlofSource;
  final String? glofSourceLakeName;

  /// Where to sample weather/river-discharge data for this basin (usually a
  /// point roughly mid-course, or near the most exposed downstream village).
  final LatLng weatherSamplePoint;

  final String downstreamNote;

  /// Basin dataset provenance and freshness metadata used to support trust and
  /// auditability in the premium product.
  final String source;
  final String sourceVersion;
  final DateTime lastVerified;

  const RiverBasin({
    required this.id,
    required this.name,
    required this.courseLine,
    required this.weatherSamplePoint,
    this.isGlofSource = false,
    this.glofSourceLakeName,
    this.downstreamNote = '',
    this.source = 'HydroSHEDS / OpenStreetMap waterway reference dataset',
    this.sourceVersion = 'v1',
    required this.lastVerified,
  });
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/hazard_zone.dart';
import '../utils/circle_geometry.dart';

/// Pulls live global hazard data from free, no-key public feeds and converts
/// each event into a [HazardZone] so it renders through the exact same
/// polygon + tap-to-inspect pipeline as the manually curated zones.
///
/// Sources:
///  - USGS Earthquake Hazards Program (public domain, no key, updates ~ every
///    minute): https://earthquake.usgs.gov/earthquakes/feed/v1.0/
///  - NASA EONET — Earth Observatory Natural Event Tracker (public domain,
///    no key): https://eonet.gsfc.nasa.gov/api/v3/events
///    Covers wildfires, severe storms/cyclones, volcanoes, and floods.
///
/// Both are government/public-agency sources, safe to poll client-side.
/// Consider adding a small server-side cache/proxy before shipping at scale
/// so you're not hammering these feeds directly from every device.
class LiveHazardService {
  static const _usgsSignificantWeek =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/significant_week.geojson';
  static const _usgs45Day =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson';
  static const _eonetEvents =
      'https://eonet.gsfc.nasa.gov/api/v3/events?status=open&limit=80&category=wildfires,severeStorms,volcanoes,floods';

  Future<List<HazardZone>> fetchAll() async {
    final results = await Future.wait([
      _fetchEarthquakes(),
      _fetchEonetEvents(),
    ], eagerError: false);

    return [...results[0], ...results[1]];
  }

  // ---------------- USGS earthquakes ----------------

  Future<List<HazardZone>> _fetchEarthquakes() async {
    try {
      // Merge "significant, past week" with "4.5+, past day" and dedupe by id
      // so both slow-building major quakes and today's moderate ones show up.
      final responses = await Future.wait([
        http.get(Uri.parse(_usgsSignificantWeek)),
        http.get(Uri.parse(_usgs45Day)),
      ]);

      final seenIds = <String>{};
      final zones = <HazardZone>[];

      for (final res in responses) {
        if (res.statusCode != 200) continue;
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final features = (json['features'] as List?) ?? [];

        for (final f in features) {
          final props = f['properties'] as Map<String, dynamic>;
          final geom = f['geometry'] as Map<String, dynamic>;
          final id = f['id'] as String;
          if (!seenIds.add(id)) continue;

          final coords = geom['coordinates'] as List;
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          final depthKm = coords.length > 2 ? (coords[2] as num).toDouble() : 0.0;
          final mag = (props['mag'] as num?)?.toDouble() ?? 0.0;
          final place = props['place'] as String? ?? 'Unknown location';
          final timeMs = props['time'] as int?;
          final tsunamiFlag = (props['tsunami'] as num?)?.toInt() ?? 0;

          zones.add(_earthquakeToZone(
            id: id,
            lat: lat,
            lon: lon,
            depthKm: depthKm,
            magnitude: mag,
            place: place,
            eventTime: timeMs != null
                ? DateTime.fromMillisecondsSinceEpoch(timeMs, isUtc: true)
                : DateTime.now().toUtc(),
            tsunamiWarning: tsunamiFlag == 1,
          ));
        }
      }
      return zones;
    } catch (_) {
      // Network failure / feed down -> fail soft, keep app usable offline.
      return [];
    }
  }

  HazardZone _earthquakeToZone({
    required String id,
    required double lat,
    required double lon,
    required double depthKm,
    required double magnitude,
    required String place,
    required DateTime eventTime,
    required bool tsunamiWarning,
  }) {
    // Simplified affected-radius heuristic — NOT a scientific shake-intensity
    // model. Swap for USGS ShakeMap MMI contours before any real deployment.
    final radiusKm = (magnitude * magnitude * 3).clamp(10, 300).toDouble();

    ZoneColor color;
    if (magnitude >= 6.5) {
      color = ZoneColor.red;
    } else if (magnitude >= 5.5) {
      color = ZoneColor.blue;
    } else if (magnitude >= 4.5) {
      color = ZoneColor.yellow;
    } else {
      color = ZoneColor.green;
    }
    if (tsunamiWarning) color = ZoneColor.red;

    final factors = <HazardFactor>[
      HazardFactor(
        name: 'Reported magnitude',
        contributionPercent: (magnitude / 9 * 60).clamp(0, 60),
        description: 'Magnitude $magnitude recorded by USGS seismic network.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Depth',
        contributionPercent: depthKm < 70 ? 20 : 8,
        description: depthKm < 70
            ? 'Shallow (${depthKm.toStringAsFixed(0)} km) — shallow quakes cause more surface shaking.'
            : 'Deep (${depthKm.toStringAsFixed(0)} km) — deeper quakes distribute energy over a wider, gentler area.',
        isHistorical: true,
      ),
      if (tsunamiWarning)
        const HazardFactor(
          name: 'Tsunami warning flag',
          contributionPercent: 20,
          description: 'USGS flagged this event with tsunami potential.',
          isHistorical: false,
        ),
    ];

    return HazardZone(
      id: 'usgs_$id',
      name: 'M$magnitude — $place',
      category: HazardCategory.earthquake,
      color: color,
      polygon: circlePolygon(LatLng(lat, lon), radiusKm),
      factors: factors,
      summary:
          'Live USGS report: magnitude $magnitude earthquake near $place, depth ${depthKm.toStringAsFixed(0)} km.',
      lastUpdated: eventTime,
      source: 'USGS Earthquake Hazards Program (live)',
      isLive: true,
    );
  }

  // ---------------- NASA EONET (wildfires, storms, volcanoes, floods) ----------------

  Future<List<HazardZone>> _fetchEonetEvents() async {
    try {
      final res = await http.get(Uri.parse(_eonetEvents));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final events = (json['events'] as List?) ?? [];

      final zones = <HazardZone>[];
      for (final e in events) {
        final categories = (e['categories'] as List?) ?? [];
        if (categories.isEmpty) continue;
        final categoryId = categories.first['id'] as String? ?? '';
        final geometryList = (e['geometry'] as List?) ?? [];
        if (geometryList.isEmpty) continue;

        // Use the most recent geometry point for events with a moving track
        // (e.g. cyclones).
        final latest = geometryList.last as Map<String, dynamic>;
        if (latest['type'] != 'Point') continue;
        final coords = latest['coordinates'] as List;
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final dateStr = latest['date'] as String?;
        final eventTime = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

        final mapped = _mapEonetCategory(categoryId);
        if (mapped == null) continue;

        zones.add(HazardZone(
          id: 'eonet_${e['id']}',
          name: e['title'] as String? ?? mapped.label,
          category: mapped,
          color: _eonetSeverityColor(mapped),
          polygon: circlePolygon(LatLng(lat, lon), _eonetRadiusKm(mapped)),
          factors: [
            const HazardFactor(
              name: 'Active NASA EONET event',
              contributionPercent: 40,
              description: 'Currently tracked as an open event by NASA Earth Observatory.',
              isHistorical: false,
            ),
          ],
          summary: 'Live NASA EONET report: ${e['title']}.',
          lastUpdated: eventTime,
          source: 'NASA EONET (live)',
          isLive: true,
        ));
      }
      return zones;
    } catch (_) {
      return [];
    }
  }

  HazardCategory? _mapEonetCategory(String eonetId) {
    switch (eonetId) {
      case 'wildfires':
        return HazardCategory.wildfire;
      case 'severeStorms':
        return HazardCategory.hurricane;
      case 'volcanoes':
        return HazardCategory.activeVolcano;
      case 'floods':
        return HazardCategory.flood;
      default:
        return null;
    }
  }

  double _eonetRadiusKm(HazardCategory category) {
    switch (category) {
      case HazardCategory.wildfire:
        return 20;
      case HazardCategory.hurricane:
        return 180; // storm systems affect a very wide area
      case HazardCategory.activeVolcano:
        return 15;
      case HazardCategory.flood:
        return 40;
      default:
        return 25;
    }
  }

  ZoneColor _eonetSeverityColor(HazardCategory category) {
    // EONET doesn't provide a severity score, so open events default to a
    // cautious tier per category. Refine with wind-speed/precip data per
    // source (e.g. NOAA NHC advisories for hurricanes) before production use.
    switch (category) {
      case HazardCategory.hurricane:
        return ZoneColor.blue;
      case HazardCategory.activeVolcano:
        return ZoneColor.red;
      default:
        return ZoneColor.yellow;
    }
  }
}

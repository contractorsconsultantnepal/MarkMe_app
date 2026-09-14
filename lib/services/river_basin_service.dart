import '../data/river_basin_data.dart';
import '../models/hazard_zone.dart';
import '../models/river_basin.dart';
import '../utils/polyline_buffer.dart';
import 'weather_flood_service.dart';

ZoneColor _toZoneColor(RiskTier t) {
  switch (t) {
    case RiskTier.green:
      return ZoneColor.green;
    case RiskTier.yellow:
      return ZoneColor.yellow;
    case RiskTier.blue:
      return ZoneColor.blue;
    case RiskTier.red:
      return ZoneColor.red;
  }
}

/// Turns each [RiverBasin] into up to three live hazard zones:
///  - a flood corridor (river-discharge driven, wider buffer)
///  - a flash-flood corridor (rainfall-intensity driven, medium buffer)
///  - for GLOF-source rivers only: a GLOF corridor exactly 50m either side
///    of the river course, as specified — this is the zone the geofence
///    service alerts on whenever the user is physically inside it,
///    independent of its computed color.
class RiverBasinService {
  final WeatherFloodService _weather = WeatherFloodService();

  /// Buffer width (each side) for the general flood-plain corridor.
  static const double floodBufferMeters = 400;

  /// Buffer width (each side) for the faster-onset flash-flood corridor.
  static const double flashFloodBufferMeters = 200;

  /// Mandated GLOF corridor width: 50m either side of the river course.
  static const double glofBufferMeters = 50;

  Future<List<HazardZone>> computeBasinZones({List<RiverBasin>? basins}) async {
    final list = basins ?? sampleRiverBasins;
    final zones = <HazardZone>[];

    for (final basin in list) {
      final reading = await _weather.fetchReading(
        basin.weatherSamplePoint.latitude,
        basin.weatherSamplePoint.longitude,
      );
      if (reading == null) continue; // feed unreachable — skip, fail soft
      final assessment = _weather.classify(reading);

      zones.add(_floodZone(basin, assessment));
      zones.add(_flashFloodZone(basin, assessment));
      if (basin.isGlofSource) {
        zones.add(_glofCorridorZone(basin, assessment));
      }
    }
    return zones;
  }

  HazardZone _floodZone(RiverBasin basin, FloodRiskAssessment a) {
    final r = a.reading;
    final ratio = r.dischargeRatio;
    return HazardZone(
      id: 'flood_${basin.id}',
      name: '${basin.name} — Flood Corridor',
      category: HazardCategory.flood,
      color: _toZoneColor(a.floodRisk),
      polygon: buildRiverCorridor(basin.courseLine, floodBufferMeters),
      factors: [
        HazardFactor(
          name: 'River discharge vs 7-day baseline',
          contributionPercent: ratio == null ? 20 : (ratio.clamp(0, 3) / 3 * 60),
          description: ratio == null
              ? 'No modeled river-discharge point here; risk based on 24h rain outlook only.'
              : 'Discharge is ${(ratio * 100).toStringAsFixed(0)}% of its recent 7-day average '
                  '(${r.riverDischargeToday?.toStringAsFixed(1)} m³/s today).',
          isHistorical: false,
        ),
        HazardFactor(
          name: 'Rainfall — next 24h forecast',
          contributionPercent: (r.precipNext24hMm / 100 * 40).clamp(0, 40),
          description: '${r.precipNext24hMm.toStringAsFixed(1)} mm forecast over the next 24 hours.',
          isHistorical: false,
        ),
      ],
      summary:
          '${basin.downstreamNote} Live flood-plain risk from river-discharge + rainfall data.',
      lastUpdated: DateTime.now(),
      source: 'Open-Meteo Flood API (GloFAS) + weather forecast (live)',
      isLive: true,
    );
  }

  HazardZone _flashFloodZone(RiverBasin basin, FloodRiskAssessment a) {
    final r = a.reading;
    return HazardZone(
      id: 'flashflood_${basin.id}',
      name: '${basin.name} — Flash Flood Corridor',
      category: HazardCategory.flashFlood,
      color: _toZoneColor(a.flashFloodRisk),
      polygon: buildRiverCorridor(basin.courseLine, flashFloodBufferMeters),
      factors: [
        HazardFactor(
          name: 'Rainfall — last 3 hours',
          contributionPercent: (r.precipLast3hMm / 60 * 70).clamp(0, 70),
          description: '${r.precipLast3hMm.toStringAsFixed(1)} mm fell in the last 3 hours near this basin.',
          isHistorical: true,
        ),
      ],
      summary: 'Sudden-onset risk from short-burst rainfall intensity — can rise within minutes.',
      lastUpdated: DateTime.now(),
      source: 'Open-Meteo weather forecast (live)',
      isLive: true,
    );
  }

  HazardZone _glofCorridorZone(RiverBasin basin, FloodRiskAssessment a) {
    // GLOF corridor severity blends the upstream lake's known status with
    // the live rainfall/discharge signal, since heavy rain and high
    // discharge both raise near-term outburst-triggering risk.
    final liveBump = a.flashFloodRisk == RiskTier.red || a.floodRisk == RiskTier.red
        ? ZoneColor.red
        : (a.flashFloodRisk == RiskTier.blue || a.floodRisk == RiskTier.blue)
            ? ZoneColor.blue
            : ZoneColor.yellow;

    return HazardZone(
      id: 'glof_corridor_${basin.id}',
      name: '${basin.name} — GLOF River Corridor (±50m)',
      category: HazardCategory.glof,
      color: liveBump,
      polygon: buildRiverCorridor(basin.courseLine, glofBufferMeters),
      factors: [
        HazardFactor(
          name: 'Upstream GLOF-monitored lake',
          contributionPercent: 40,
          description: 'Course is fed by ${basin.glofSourceLakeName ?? "a monitored glacial lake"}, '
              'a documented glacial-lake-outburst-flood source.',
          isHistorical: true,
        ),
        HazardFactor(
          name: 'Current rainfall/discharge signal',
          contributionPercent: 30,
          description: 'Live rain and river-discharge readings near this reach are elevated.',
          isHistorical: false,
        ),
      ],
      summary:
          'You are within 50m of a river course fed by a GLOF-prone glacial lake. '
          '${basin.downstreamNote}',
      lastUpdated: DateTime.now(),
      source: 'Manual GLOF lake registry + Open-Meteo (live)',
      isLive: true,
    );
  }
}

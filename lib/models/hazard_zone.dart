import 'package:latlong2/latlong.dart';

/// Whether a hazard originates from nature or from human activity/conflict.
enum HazardOrigin { natural, artificial }

/// The specific kind of hazard a zone represents.
enum HazardCategory {
  // Natural
  activeVolcano,
  flood,
  flashFlood,
  glof, // Glacial Lake Outburst Flood
  earthquake,
  tsunami,
  hurricane,
  lightning,
  wildfire,
  // Artificial
  gasFactory,
  militaryZone,
  civilWarField,
  explosives,
}

extension HazardCategoryLabel on HazardCategory {
  String get label {
    switch (this) {
      case HazardCategory.activeVolcano:
        return 'Active Volcano';
      case HazardCategory.flood:
        return 'Flood';
      case HazardCategory.flashFlood:
        return 'Flash Flood';
      case HazardCategory.glof:
        return 'Glacial Lake Outburst Flood (GLOF)';
      case HazardCategory.earthquake:
        return 'Earthquake';
      case HazardCategory.tsunami:
        return 'Tsunami';
      case HazardCategory.hurricane:
        return 'Hurricane / Cyclone';
      case HazardCategory.lightning:
        return 'Lightning';
      case HazardCategory.wildfire:
        return 'Wildfire';
      case HazardCategory.gasFactory:
        return 'Poisonous Gas Facility';
      case HazardCategory.militaryZone:
        return 'Military Action Zone';
      case HazardCategory.civilWarField:
        return 'Civil Conflict Zone';
      case HazardCategory.explosives:
        return 'Explosives / Blast Radius';
    }
  }

  HazardOrigin get origin {
    const artificial = {
      HazardCategory.gasFactory,
      HazardCategory.militaryZone,
      HazardCategory.civilWarField,
      HazardCategory.explosives,
    };
    return artificial.contains(this) ? HazardOrigin.artificial : HazardOrigin.natural;
  }
}

/// The four alert tiers MarkMe uses. Ordered low -> high severity as
/// green < yellow < blue < red. `blue` is used for "watch / monitored risk"
/// (e.g. a GLOF lake under observation) which sits between a routine
/// caution (yellow) and an active severe zone (red). Adjust this ordering
/// centrally if your risk model wants a different scale.
enum ZoneColor { green, yellow, blue, red }

extension ZoneColorMeta on ZoneColor {
  String get label {
    switch (this) {
      case ZoneColor.green:
        return 'Green — Low Risk';
      case ZoneColor.yellow:
        return 'Yellow — Moderate Risk';
      case ZoneColor.blue:
        return 'Blue — Watch / Elevated Risk';
      case ZoneColor.red:
        return 'Red — Severe / Active Risk';
    }
  }
}

/// A single factor that fed into a zone's computed intensity score.
/// e.g. { name: "Historical GLOF events (last 30y)", contributionPercent: 25 }
class HazardFactor {
  final String name;
  final double contributionPercent;
  final String description;
  final bool isHistorical; // true = based on past events, false = forecast/upcoming risk

  const HazardFactor({
    required this.name,
    required this.contributionPercent,
    required this.description,
    required this.isHistorical,
  });
}

class HazardZone {
  final String id;
  final String name;
  final HazardCategory category;
  final ZoneColor color;
  final List<LatLng> polygon;
  final List<HazardFactor> factors;
  final String summary;
  final DateTime lastUpdated;
  final String source; // e.g. "USGS", "NASA EONET", "Manual/OCHA curated"
  final String sourceUrl;
  final String confidenceNote;
  final String? dataLagNote;
  final bool isLive; // true = fetched from a live feed this session, false = static/curated

  const HazardZone({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.polygon,
    required this.factors,
    required this.summary,
    required this.lastUpdated,
    required this.source,
    this.sourceUrl = '',
    this.confidenceNote =
        'Modeled and aggregated from public sources; not a substitute for official emergency guidance, professional survey, or local authority instructions.',
    this.dataLagNote,
    this.isLive = false,
  });

  HazardOrigin get origin => category.origin;

  /// Weighted intensity score 0-100 derived from factor contributions.
  double get intensityScore =>
      factors.fold(0.0, (sum, f) => sum + f.contributionPercent).clamp(0, 100);
}

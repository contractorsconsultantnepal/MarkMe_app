import 'package:latlong2/latlong.dart';
import '../models/hazard_zone.dart';

/// Sample seed data so the app is usable out of the box.
///
/// In production, replace this static list with a repository that merges:
///  - Historical event archives (past disasters) per region
///  - Live/forecast feeds (USGS quakes, GDACS multi-hazard, weather warnings,
///    NASA FIRMS fire/volcanic thermal anomalies, ACLED/OCHA conflict data)
///  - A manually curated layer for hazards with no public API
///    (military zones, explosive depots, specific factory risk radii)
///
/// Each zone's `color` should be recomputed periodically by a scoring
/// service that weighs historical frequency/severity against live/forecast
/// signals — see intensityScore in HazardZone.
final List<HazardZone> sampleHazardZones = [
  // --- Natural: GLOF risk, Kathmandu Valley / Himalaya region (illustrative) ---
  HazardZone(
    id: 'glof_imja_01',
    name: 'Imja Lake GLOF Watch Zone',
    category: HazardCategory.glof,
    color: ZoneColor.blue,
    polygon: const [
      LatLng(27.905, 86.910),
      LatLng(27.915, 86.930),
      LatLng(27.895, 86.945),
      LatLng(27.880, 86.920),
    ],
    factors: const [
      HazardFactor(
        name: 'Historical GLOF events (region, 50y)',
        contributionPercent: 20,
        description: 'Documented past glacial lake outburst floods in the wider basin.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Glacial lake expansion rate',
        contributionPercent: 25,
        description: 'Satellite-observed lake growth increasing outburst probability.',
        isHistorical: false,
      ),
      HazardFactor(
        name: 'Downstream population exposure',
        contributionPercent: 10,
        description: 'Settlements within the likely flood-path if an outburst occurs.',
        isHistorical: false,
      ),
    ],
    summary: 'Monitored glacial lake with rising outburst-flood probability.',
    lastUpdated: DateTime(2026, 8, 1),
    source: 'Manual/ICIMOD-style curated',
  ),

  // --- Natural: Earthquake fault zone ---
  HazardZone(
    id: 'quake_main_himalayan_thrust',
    name: 'Main Himalayan Thrust — Active Segment',
    category: HazardCategory.earthquake,
    color: ZoneColor.red,
    polygon: const [
      LatLng(27.60, 85.20),
      LatLng(27.75, 85.45),
      LatLng(27.55, 85.60),
      LatLng(27.40, 85.35),
    ],
    factors: const [
      HazardFactor(
        name: 'Historical major earthquakes (100y)',
        contributionPercent: 35,
        description: '2015 Gorkha earthquake and prior events on this segment.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Seismic gap / stress accumulation',
        contributionPercent: 30,
        description: 'Segment identified as overdue for major rupture by seismologists.',
        isHistorical: false,
      ),
      HazardFactor(
        name: 'Building density & vulnerability',
        contributionPercent: 10,
        description: 'High density of non-retrofitted structures in the zone.',
        isHistorical: false,
      ),
    ],
    summary: 'High-density fault segment with significant overdue-rupture risk.',
    lastUpdated: DateTime(2026, 9, 1),
    source: 'USGS + Manual curated',
  ),

  // --- Natural: Active volcano ---
  HazardZone(
    id: 'volcano_example_01',
    name: 'Example Active Volcano — 8km Danger Radius',
    category: HazardCategory.activeVolcano,
    color: ZoneColor.red,
    polygon: const [
      LatLng(-7.540, 110.446),
      LatLng(-7.480, 110.480),
      LatLng(-7.470, 110.400),
      LatLng(-7.530, 110.370),
    ],
    factors: const [
      HazardFactor(
        name: 'Historical eruptions (100y)',
        contributionPercent: 30,
        description: 'Multiple confirmed eruptive events with pyroclastic flows.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Current seismic/gas monitoring alert level',
        contributionPercent: 30,
        description: 'Elevated tremor activity per volcanological survey.',
        isHistorical: false,
      ),
      HazardFactor(
        name: 'Settlement within pyroclastic flow path',
        contributionPercent: 15,
        description: 'Villages located within the modeled flow danger radius.',
        isHistorical: false,
      ),
    ],
    summary: 'Historically active stratovolcano with current elevated monitoring status.',
    lastUpdated: DateTime(2026, 8, 20),
    source: 'Volcanological Survey (example) + Manual curated',
  ),

  // --- Natural: Hurricane-prone coastline ---
  HazardZone(
    id: 'hurricane_coastal_01',
    name: 'Coastal Storm Surge Corridor',
    category: HazardCategory.hurricane,
    color: ZoneColor.yellow,
    polygon: const [
      LatLng(25.77, -80.20),
      LatLng(25.85, -80.10),
      LatLng(25.70, -80.05),
      LatLng(25.65, -80.18),
    ],
    factors: const [
      HazardFactor(
        name: 'Historical hurricane landfalls (30y)',
        contributionPercent: 20,
        description: 'Repeated Category 2+ landfalls in this corridor.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Seasonal forecast outlook',
        contributionPercent: 15,
        description: 'Above-average storm activity forecast for the current season.',
        isHistorical: false,
      ),
    ],
    summary: 'Coastal corridor with recurring storm surge exposure.',
    lastUpdated: DateTime(2026, 6, 1),
    source: 'NOAA-style feed (example)',
  ),

  // --- Artificial: Gas factory ---
  HazardZone(
    id: 'gas_factory_01',
    name: 'Industrial Gas Plant — Dispersion Radius',
    category: HazardCategory.gasFactory,
    color: ZoneColor.red,
    polygon: const [
      LatLng(23.28, 77.40),
      LatLng(23.30, 77.43),
      LatLng(23.27, 77.45),
      LatLng(23.25, 77.42),
    ],
    factors: const [
      HazardFactor(
        name: 'Historical industrial gas leak incident',
        contributionPercent: 40,
        description: 'Site has a documented past toxic gas release event.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Modeled worst-case dispersion radius',
        contributionPercent: 20,
        description: 'Plume-modeling estimate for a catastrophic release scenario.',
        isHistorical: false,
      ),
    ],
    summary: 'Chemical facility with a documented past release and high-consequence dispersion radius.',
    lastUpdated: DateTime(2026, 5, 1),
    source: 'Manual/regulatory-filing curated',
  ),

  // --- Artificial: Conflict zone (illustrative placeholder only) ---
  HazardZone(
    id: 'conflict_zone_example_01',
    name: 'Example Conflict-Affected Area (placeholder)',
    category: HazardCategory.civilWarField,
    color: ZoneColor.red,
    polygon: const [
      LatLng(15.30, 44.10),
      LatLng(15.40, 44.25),
      LatLng(15.25, 44.35),
      LatLng(15.15, 44.15),
    ],
    factors: const [
      HazardFactor(
        name: 'Recent armed engagements (90 days)',
        contributionPercent: 35,
        description: 'Illustrative placeholder — wire this to a vetted feed such as ACLED or OCHA before shipping.',
        isHistorical: true,
      ),
      HazardFactor(
        name: 'Active displacement reports',
        contributionPercent: 15,
        description: 'Illustrative placeholder for ongoing-risk signal.',
        isHistorical: false,
      ),
    ],
    summary: 'PLACEHOLDER DATA — replace with a vetted conflict-monitoring feed (ACLED/OCHA) before any real deployment.',
    lastUpdated: DateTime(2026, 9, 1),
    source: 'Placeholder — not a live feed',
  ),

  // --- Artificial: Explosives storage ---
  HazardZone(
    id: 'explosives_depot_01',
    name: 'Explosives Storage — Blast Radius',
    category: HazardCategory.explosives,
    color: ZoneColor.yellow,
    polygon: const [
      LatLng(27.70, 85.35),
      LatLng(27.71, 85.365),
      LatLng(27.695, 85.375),
      LatLng(27.685, 85.36),
    ],
    factors: const [
      HazardFactor(
        name: 'Storage volume & class',
        contributionPercent: 25,
        description: 'Facility licensed for a moderate explosives storage class.',
        isHistorical: false,
      ),
      HazardFactor(
        name: 'Historical incident record',
        contributionPercent: 5,
        description: 'No confirmed incidents on record at this specific site.',
        isHistorical: true,
      ),
    ],
    summary: 'Licensed explosives depot with a calculated safety-distance blast radius.',
    lastUpdated: DateTime(2026, 4, 10),
    source: 'Manual/regulatory curated',
  ),
];

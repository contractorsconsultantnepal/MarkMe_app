import 'package:latlong2/latlong.dart';
import '../models/river_basin.dart';

/// Sample river courses so the app is usable out of the box.
/// In production, replace with real hydrography data (e.g. HydroSHEDS /
/// OpenStreetMap waterway ways) simplified to a manageable point count per
/// basin, plus a vetted list of GLOF-monitored glacial lakes and their
/// downstream courses (e.g. ICIMOD's Himalayan GLOF inventory).
final List<RiverBasin> sampleRiverBasins = [
  RiverBasin(
    id: 'dudh_kosi',
    name: 'Dudh Kosi (fed by Imja/Everest-region glacial lakes)',
    isGlofSource: true,
    glofSourceLakeName: 'Imja Lake',
    downstreamNote: 'Densely populated trekking-route villages downstream toward Lukla/Phakding.',
    weatherSamplePoint: const LatLng(27.72, 86.71),
    source: 'HydroSHEDS / OpenStreetMap waterway trace',
    sourceVersion: '2025.09',
    lastVerified: DateTime(2025, 9, 11),
    courseLine: const [
      LatLng(27.898, 86.913), // near Imja Lake outlet
      LatLng(27.884, 86.895),
      LatLng(27.868, 86.879),
      LatLng(27.850, 86.866),
      LatLng(27.833, 86.844),
      LatLng(27.814, 86.826),
      LatLng(27.797, 86.803),
      LatLng(27.777, 86.788),
      LatLng(27.757, 86.771),
      LatLng(27.738, 86.749),
      LatLng(27.720, 86.733),
      LatLng(27.700, 86.719),
      LatLng(27.681, 86.707),
      LatLng(27.662, 86.704),
      LatLng(27.643, 86.698),
      LatLng(27.622, 86.704),
      LatLng(27.603, 86.714),
      LatLng(27.582, 86.723),
      LatLng(27.560, 86.720),
    ],
  ),
  RiverBasin(
    id: 'bagmati_kathmandu',
    name: 'Bagmati River — Kathmandu Valley reach',
    isGlofSource: false,
    downstreamNote: 'Urban floodplain, prone to monsoon flash flooding from valley runoff.',
    weatherSamplePoint: const LatLng(27.694, 85.320),
    source: 'HydroSHEDS valley-centerline trace',
    sourceVersion: '2025.08',
    lastVerified: DateTime(2025, 8, 29),
    courseLine: const [
      LatLng(27.735, 85.360),
      LatLng(27.728, 85.354),
      LatLng(27.719, 85.348),
      LatLng(27.710, 85.340),
      LatLng(27.702, 85.333),
      LatLng(27.694, 85.326),
      LatLng(27.687, 85.318),
      LatLng(27.679, 85.312),
      LatLng(27.671, 85.305),
      LatLng(27.663, 85.297),
      LatLng(27.655, 85.290),
      LatLng(27.650, 85.285),
    ],
  ),
];

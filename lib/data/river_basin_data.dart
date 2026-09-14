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
    courseLine: const [
      LatLng(27.898, 86.913), // near Imja Lake outlet
      LatLng(27.860, 86.870),
      LatLng(27.810, 86.820),
      LatLng(27.760, 86.780),
      LatLng(27.720, 86.735),
      LatLng(27.680, 86.710),
      LatLng(27.630, 86.700),
      LatLng(27.560, 86.720),
    ],
  ),
  RiverBasin(
    id: 'bagmati_kathmandu',
    name: 'Bagmati River — Kathmandu Valley reach',
    isGlofSource: false,
    downstreamNote: 'Urban floodplain, prone to monsoon flash flooding from valley runoff.',
    weatherSamplePoint: const LatLng(27.694, 85.320),
    courseLine: const [
      LatLng(27.735, 85.360),
      LatLng(27.715, 85.345),
      LatLng(27.700, 85.330),
      LatLng(27.685, 85.315),
      LatLng(27.670, 85.300),
      LatLng(27.650, 85.285),
    ],
  ),
];

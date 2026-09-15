import 'dart:convert';
import 'package:http/http.dart' as http;

/// Rain + river-discharge data for one sample point, used to classify flood
/// and flash-flood risk. Source: Open-Meteo (free, no API key).
///  - Weather/precipitation: https://api.open-meteo.com/v1/forecast
///  - River discharge (GloFAS model): https://flood-api.open-meteo.com/v1/flood
class BasinWeatherReading {
  final double precipLast3hMm;
  final double precipNext24hMm;
  final double? riverDischargeToday; // m3/s, null if no modeled river nearby
  final double? riverDischarge7dAvg; // m3/s

  const BasinWeatherReading({
    required this.precipLast3hMm,
    required this.precipNext24hMm,
    this.riverDischargeToday,
    this.riverDischarge7dAvg,
  });

  /// Ratio of today's discharge to the recent 7-day average. >1 means the
  /// river is running higher than its recent baseline.
  double? get dischargeRatio {
    if (riverDischargeToday == null || riverDischarge7dAvg == null || riverDischarge7dAvg == 0) {
      return null;
    }
    return riverDischargeToday! / riverDischarge7dAvg!;
  }
}

enum RiskTier { green, yellow, blue, red }

class FloodRiskAssessment {
  final RiskTier flashFloodRisk; // driven by short-burst rainfall intensity
  final RiskTier floodRisk; // driven by river discharge trend
  final BasinWeatherReading reading;
  const FloodRiskAssessment({
    required this.flashFloodRisk,
    required this.floodRisk,
    required this.reading,
  });
}

class WeatherFloodService {
  Future<BasinWeatherReading?> fetchReading(double lat, double lon) async {
    try {
      final precip = await _fetchPrecipitation(lat, lon).catchError((_) => (0.0, 0.0));
      final discharge = await _fetchRiverDischarge(lat, lon).catchError((_) => (null, null));
      return BasinWeatherReading(
        precipLast3hMm: precip.$1,
        precipNext24hMm: precip.$2,
        riverDischargeToday: discharge.$1,
        riverDischarge7dAvg: discharge.$2,
      );
    } catch (_) {
      return const BasinWeatherReading(
        precipLast3hMm: 0,
        precipNext24hMm: 0,
      );
    }
  }

  Future<(double, double)> _fetchPrecipitation(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=precipitation&past_days=1&forecast_days=2&timezone=auto',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return (0.0, 0.0);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final values = (hourly['precipitation'] as List).map((v) => (v as num).toDouble()).toList();

    final now = DateTime.now();
    double last3h = 0, next24h = 0;
    for (int i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i]);
      final diffH = t.difference(now).inMinutes / 60.0;
      if (diffH >= -3 && diffH <= 0) last3h += values[i];
      if (diffH > 0 && diffH <= 24) next24h += values[i];
    }
    return (last3h, next24h);
  }

  Future<(double?, double?)> _fetchRiverDischarge(double lat, double lon) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lat&longitude=$lon&daily=river_discharge&past_days=7&forecast_days=1',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return (null, null);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) return (null, null);
    final values = (daily['river_discharge'] as List?)
        ?.map((v) => v == null ? null : (v as num).toDouble())
        .whereType<double>()
        .toList();
    if (values == null || values.isEmpty) return (null, null);

    final today = values.last;
    final pastWeek = values.length > 1 ? values.sublist(0, values.length - 1) : <double>[];
    final avg = pastWeek.isEmpty ? null : pastWeek.reduce((a, b) => a + b) / pastWeek.length;
    return (today, avg);
  }

  /// Classifies flash-flood risk from short-burst rainfall intensity, and
  /// flood risk from river discharge trend vs its recent baseline.
  ///
  /// These thresholds are simplified rules of thumb, not a calibrated
  /// hydrological model — tune per-region (e.g. against local met agency
  /// flash-flood guidance) before relying on this for real safety decisions.
  FloodRiskAssessment classify(BasinWeatherReading r) {
    RiskTier flash;
    if (r.precipLast3hMm >= 50) {
      flash = RiskTier.red;
    } else if (r.precipLast3hMm >= 30) {
      flash = RiskTier.blue;
    } else if (r.precipLast3hMm >= 15) {
      flash = RiskTier.yellow;
    } else {
      flash = RiskTier.green;
    }

    RiskTier flood;
    final ratio = r.dischargeRatio;
    if (ratio == null) {
      // No modeled river at this point — fall back to 24h rain outlook only.
      flood = r.precipNext24hMm >= 80
          ? RiskTier.red
          : r.precipNext24hMm >= 40
              ? RiskTier.yellow
              : RiskTier.green;
    } else if (ratio >= 2.0) {
      flood = RiskTier.red;
    } else if (ratio >= 1.5) {
      flood = RiskTier.blue;
    } else if (ratio >= 1.2) {
      flood = RiskTier.yellow;
    } else {
      flood = RiskTier.green;
    }

    return FloodRiskAssessment(flashFloodRisk: flash, floodRisk: flood, reading: r);
  }
}

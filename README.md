# MarkMe

Live natural & artificial hazard-zone map (OpenStreetMap) with tap-to-inspect
intensity breakdowns and a red-zone entry push alert.

## What's included

```
lib/
  models/hazard_zone.dart       # HazardZone, HazardCategory, ZoneColor, HazardFactor
  data/hazard_data.dart         # Sample seed zones (8 examples across all hazard types)
  utils/point_in_polygon.dart   # Ray-casting geometry test
  services/geofence_service.dart      # Watches location, fires alert on red-zone entry
  services/notification_service.dart  # flutter_local_notifications wrapper
  widgets/hazard_detail_sheet.dart    # Bottom sheet: hazard name + weighted factor breakdown
  screens/map_screen.dart       # FlutterMap + polygon layer + tap handling + filters
  main.dart
```

## River basin, rainfall & GLOF corridor mapping (new)

`lib/services/river_basin_service.dart` + `lib/services/weather_flood_service.dart`
add three more live layers, derived from a river's course line:

- **Flood corridor** (±400m) — colored from live **river discharge** via the
  Open-Meteo Flood API (GloFAS model): today's discharge vs. its trailing
  7-day average. Ratio ≥2.0 → red, ≥1.5 → blue, ≥1.2 → yellow.
- **Flash-flood corridor** (±200m) — colored from **short-burst rainfall**
  (last 3 hours) via Open-Meteo's weather forecast API: ≥50mm/3h → red,
  ≥30mm → blue, ≥15mm → yellow. Flash floods build in minutes, so this uses
  a much shorter window than the discharge-based flood corridor.
- **GLOF river corridor — exactly 50m either side of the river course**, for
  any basin flagged as fed by a monitored glacial lake. This is the zone
  the app is required to alert on: `GeofenceService` now checks it
  independently of color — entering it fires a distinct notification
  ("🌊 Entering a GLOF River Corridor") the moment you're within 50m of the
  river, since proximity to a GLOF-prone course is itself the hazard, not
  just a "red" classification.

`lib/utils/polyline_buffer.dart` builds these corridors by offsetting the
river's course line perpendicular to its direction at each vertex (a local
flat-earth projection, accurate for corridors up to a few hundred meters
wide over river reaches of tens of km — swap for a geodesic buffering
library like Turf/GEOS on a backend if you need this at country scale).

River courses themselves are drawn as blue lines on the map for context
(thicker where GLOF-sourced), separately from the risk-colored corridor
polygons.

**Sample data**: `lib/data/river_basin_data.dart` ships two example basins
(Dudh Kosi below Imja Lake — GLOF source; Bagmati through Kathmandu — flood/
flash-flood only). Replace with real hydrography (HydroSHEDS or OpenStreetMap
waterway data, simplified per basin) and a vetted GLOF lake inventory (e.g.
ICIMOD's Himalayan GLOF database) before relying on this for real safety use.

**Known simplifications:**
- Discharge/rainfall thresholds are rule-of-thumb, not a calibrated
  hydrological model — tune against local met-agency flash-flood guidance
  per region.
- One weather/discharge sample point per basin, not sampled along the full
  course — for long rivers, sample at several points and interpolate.
- Open-Meteo's Flood API only has modeled data for larger rivers; very
  small streams fall back to a rainfall-only estimate (noted in the zone's
  factor breakdown when this happens).

## Live global hazard feeds (new)

`lib/services/live_hazard_service.dart` now pulls real-time data on app
start and every 5 minutes, no API key required:

- **Earthquakes** — USGS Earthquake Hazards Program (`significant_week` +
  `4.5_day` GeoJSON feeds, merged & deduped). Each quake becomes a circular
  zone sized off magnitude, colored green→red by magnitude/tsunami flag,
  with a factor breakdown (magnitude, depth, tsunami warning).
- **Wildfires, severe storms/cyclones, volcanoes, floods** — NASA EONET
  (Earth Observatory Natural Event Tracker), filtered to `status=open`.

Both sources are public-domain government/agency data and free to poll
client-side. Live zones are tagged `isLive: true` and show a green "LIVE"
chip in the detail sheet; they're merged with the static curated zones
(gas factories, conflict placeholder, explosives) so everything — live and
manual — goes through the same tap-to-inspect and red-zone-alert pipeline.
The app bar shows a refresh button and a status strip with the last update
time; if a feed is unreachable it fails soft and keeps showing
cached/static data with a small warning banner instead of crashing.

**Known simplifications to fix before production:**
- Earthquake affected-radius is a rough `magnitude² × 3 km` heuristic, not
  a real ShakeMap intensity model — swap in USGS ShakeMap contours for
  accurate shaking-intensity polygons.
- EONET events don't carry a severity score, so hurricanes/floods/wildfires
  get a default color per category rather than a computed one — pair with
  NOAA NHC advisories (wind speed/category) for real storm severity.
- No GDACS integration yet (multi-hazard alerts with severity levels) —
  worth adding as a third source; it's an XML/RSS feed so needs a small
  parser.
- Both feeds are polled directly from the device. At scale, put a thin
  server-side cache in front of them instead of every device hitting USGS/
  NASA directly.

Covers every hazard type you listed:
- **Natural**: active volcano, flood, flash flood, GLOF, earthquake, tsunami,
  hurricane/cyclone, lightning
- **Artificial**: poisonous gas facilities, military action zones, civil
  conflict zones, explosives/blast radius

Each zone stores a list of weighted `HazardFactor`s (some historical, some
forecast/upcoming-risk), and `HazardZone.intensityScore` sums them —
tapping any polygon shows exactly which factors drove its color.

## Build an APK in the cloud — no local Flutter install needed

`.github/workflows/build-apk.yml` builds a release APK on GitHub's servers
and hands you a download link. To use it:

1. Create a new **GitHub repo** (public or private, your choice).
2. Push this project to it:
   ```bash
   cd markme_app
   git init
   git add .
   git commit -m "MarkMe initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
3. Go to the repo on GitHub → **Actions** tab. The "Build MarkMe APK"
   workflow starts automatically on push (or click **Run workflow** to
   trigger it manually anytime).
4. Wait for the green check (~5–8 minutes on the first run — it's
   downloading the Flutter SDK and Android toolchain fresh each time).
5. Click into the finished run → scroll to **Artifacts** →
   download `markme-app-release-apk` → unzip it to get `app-release.apk`.
6. Transfer that APK to your Android phone (email, Drive, USB — anything)
   and tap it to install. You'll need to allow **"install from unknown
   sources"** for whichever app you used to open it, since it's not from
   the Play Store.

Notes:
- This produces a **debug-signed** APK — installs and runs fine for
  personal use/testing, but can't be uploaded to the Play Store as-is;
  that needs a proper release keystore, a deliberate step to add later
  (happy to set that up when you're ready to publish).
- The workflow regenerates the `android/` folder fresh each run (this
  repo ships `lib/` + `pubspec.yaml` only) and patches in the location/
  notification permissions automatically — nothing extra needed on your
  end for this path.
- iOS builds need a Mac + Apple Developer account for signing, so they're
  intentionally out of scope here — for iPhone, use a local Mac + Xcode
  build instead.

## Run it

This scaffold has the Dart/Flutter source only (no `flutter` CLI was
available in the environment that generated it, so `flutter create .`
hasn't been run here). To get a runnable project:

```bash
flutter create .          # generates android/, ios/, and platform boilerplate
                           # (say "keep existing files" if it asks — don't overwrite lib/)
flutter pub get
flutter run
```

## Required permission config (add after `flutter create .`)

**android/app/src/main/AndroidManifest.xml** — inside `<manifest>`, above `<application>`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**ios/Runner/Info.plist** — add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>MarkMe checks your location against hazard zones to alert you if you enter a severe-risk area.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>MarkMe needs background location to alert you even when the app isn't open.</string>
```

## Design notes / assumptions made

- **Zone color scale**: green < yellow < blue < red, where blue = "watch /
  elevated risk under monitoring" (e.g. a glacial lake being tracked but not
  yet critical). If you intended a different ordering for blue, it's a
  one-line change in `ZoneColorMeta`.
- **Alerting**: only `red` zones trigger a push notification, fired once on
  entry (not repeated every location update) and re-armed on exit. Easy to
  extend to alert on `blue`+ as well.
- **Conflict-zone data is a placeholder.** Real military/war-zone/civil
  conflict data is politically sensitive and time-critical — the sample
  entry is explicitly marked as illustrative. Before shipping, wire this
  category to a vetted source (e.g. ACLED, UN OCHA) rather than manual
  entry, and review your jurisdiction's rules on displaying such data.
- **Tap detection** uses simple point-in-polygon geometry, fine at
  city/regional scale.

## Suggested next steps

1. Replace `sampleHazardZones` with a repository that pulls from real feeds
   (USGS earthquakes, GDACS, weather-service storm/lightning warnings, NASA
   FIRMS for volcanic/fire thermal anomalies) and merges them with your
   manually curated artificial-hazard layer.
2. Move intensity scoring server-side so zone colors update centrally
   instead of being hardcoded per zone.
3. Add background/killed-app geofencing (the current implementation alerts
   while the app is running in foreground/background; true killed-app
   geofencing typically needs a native geofencing API — `geofence_service`
   or platform-specific WorkManager/BGTaskScheduler wiring).
4. Add a search/"my area" onboarding flow and a legend explaining the four
   colors.

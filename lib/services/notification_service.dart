import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showRedZoneAlert({
    required String zoneName,
    required String hazardLabel,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'markme_red_zone_channel',
      'Red Zone Alerts',
      channelDescription: 'Alerts when you enter a severe hazard (red) zone',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      zoneName.hashCode,
      '⚠️ Entered a Red Hazard Zone',
      '$zoneName — $hazardLabel. Stay alert and follow local safety guidance.',
      details,
    );
  }

  /// Fired the moment the user enters ANY GLOF river corridor (the 50m
  /// either-side buffer), regardless of its currently computed color —
  /// proximity to a GLOF-prone river course is itself the risk signal.
  Future<void> showGlofCorridorAlert({
    required String zoneName,
    required String summary,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'markme_glof_channel',
      'GLOF River Corridor Alerts',
      channelDescription: 'Alerts when you enter a river corridor fed by a GLOF-prone glacial lake',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      'glof_$zoneName'.hashCode,
      '🌊 Entering a GLOF River Corridor',
      '$zoneName — $summary',
      details,
    );
  }
}

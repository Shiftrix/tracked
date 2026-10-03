import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    // Android 13+ needs this permission at runtime
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Show or update the persistent "running" notification.
  static Future<void> showRunning(String activityName) async {
    const details = AndroidNotificationDetails(
      'tracker_running',
      'Active Session',
      channelDescription: 'Shown while an activity timer is running',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      1,
      activityName,
      'Running',
      const NotificationDetails(android: details),
    );
  }

  static Future<void> clear() async {
    await _plugin.cancel(1);
  }
}

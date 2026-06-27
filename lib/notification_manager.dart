import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final currentTimeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Error setting local timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);

  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    } else if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS permissions are handled via DarwinInitializationSettings
      // during init(), no additional action needed.
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) return;

    // 1. Request notification permission (shows system dialog on Android 13+)
    try {
      final bool? notificationGranted =
          await androidImplementation.requestNotificationsPermission();
      debugPrint('Notification permission granted: $notificationGranted');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // 2. Request exact alarm permission (Android 12+)
    try {
      final bool? alarmGranted =
          await androidImplementation.requestExactAlarmsPermission();
      debugPrint('Exact alarm permission granted: $alarmGranted');
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
    }

    // 3. Request battery optimizations (critical for alarms on Huawei/Xiaomi)
    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('Error requesting extra permissions: $e');
    }
  }

  Future<void> scheduleExpirationNotifications(List<PhoneNumberItem> numbers, SettingsManager settingsManager) async {
    await _notificationsPlugin.cancelAll();

    int id = 0;
    final now = DateTime.now();

    for (final item in numbers) {
      final expDate = item.expireDate;
      
      for (final remindDays in item.remindBeforeDays) {
        final rawDate = expDate.subtract(Duration(days: remindDays));
        final notifyDate = DateTime(
          rawDate.year, rawDate.month, rawDate.day,
          item.remindTimeHour, item.remindTimeMinute,
        );
        
        if (notifyDate.isAfter(now)) {
          await _scheduleNotification(
            id++,
            'SIMVault: 保号提醒',
            '您的 ${item.country.name} 号码 ${item.number} 还有 $remindDays 天过期！',
            notifyDate,
          );
        }
      }

      // 额外调度一个过期当天的紧急提醒
      final urgentDate = DateTime(
        expDate.year, expDate.month, expDate.day,
        item.remindTimeHour, item.remindTimeMinute,
      );
      if (urgentDate.isAfter(now)) {
        await _scheduleNotification(
          id++,
          'SIMVault: 🚨 紧急保号提醒',
          '您的 ${item.country.name} 号码 ${item.number} 今天过期！',
          urgentDate,
        );
      }
    }
  }

  Future<void> _scheduleNotification(int id, String title, String body, DateTime scheduledDate) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          scheduledDate.hour,
          scheduledDate.minute,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sim_vault_alerts_v2',
            'Expiration Alerts',
            channelDescription: 'Notifications for SIM card expirations',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      debugPrint('Could not schedule notification: $e');
    }
  }

  Future<void> showWelcomeNotification() async {
    try {
      await _notificationsPlugin.show(
        id: 888,
        title: 'SIMVault 欢迎您',
        body: '为了保证能按时提醒您，我们需要通知权限。',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sim_vault_alerts_v2',
            'Expiration Alerts',
            channelDescription: 'Notifications for SIM card expirations',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      // We can cancel it after a few seconds so it doesn't clutter the tray, or just leave it.
      // Let's cancel it after 3 seconds so it triggers the prompt but disappears cleanly.
      Future.delayed(const Duration(seconds: 3), () {
        _notificationsPlugin.cancel(id: 888);
      });
    } catch (e) {
      debugPrint('Could not show welcome notification: $e');
    }
  }
}

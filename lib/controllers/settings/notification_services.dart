import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import 'package:retailpos/core/settings/local_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _dispatchedKeysPrefsKey = 'dispatched_notification_keys';

  static Future<bool> isDispatched(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final dispatched = prefs.getStringList(_dispatchedKeysPrefsKey) ?? [];
    return dispatched.contains(key);
  }

  static Future<void> markDispatched(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final dispatched = prefs.getStringList(_dispatchedKeysPrefsKey) ?? [];
    if (!dispatched.contains(key)) {
      dispatched.add(key);
      if (dispatched.length > 500) {
        dispatched.removeRange(0, dispatched.length - 500);
      }
      await prefs.setStringList(_dispatchedKeysPrefsKey, dispatched);
    }
  }

  static Future<void> init() async {
    final branding = await LocalPreferences.getAppBranding();
    final appName = branding.productName.isNotEmpty ? branding.productName : branding.companyName;

    final WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
      appName: appName,
      appUserModelId: 'com.famalth.retailpos.v2',
      guid: '87654321-4321-4321-4321-210987654321',
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings settings =
        InitializationSettings(
      windows: windowsSettings,
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final id = response.payload;

        if (id != null && id.isNotEmpty) {
          try {
            await ApiClient.put('/api/notifications/$id/read', {});
          } catch (e) {
            // Ignore error
          }
        }
      },
    );

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  static Future<void> show(
    int id,
    String title,
    String body, {
    String? uniqueKey,
    bool force = false,
  }) async {
    final showNotif = await LocalPreferences.getShowNotifications();
    if (!showNotif) return;

    final key = uniqueKey ?? 'notif_$id';
    if (!force && await isDispatched(key)) {
      // Notification already dispatched and presented once.
      // Do NOT trigger again when user dismisses or timer polls.
      return;
    }

    await markDispatched(key);

    final branding = await LocalPreferences.getAppBranding();
    final appName = branding.productName.isNotEmpty ? branding.productName : branding.companyName;

    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel_id',
      'Default Channel',
      channelDescription: 'Standard notification channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(
      windows: windowsDetails,
      android: androidDetails,
    );

    final notificationTitle = title.contains(appName) ? title : '[$appName] $title';

    int notifId = key.hashCode.abs() % 2147483647;

    await _notifications.show(
      id: notifId,
      title: notificationTitle,
      body: body,
      notificationDetails: details,
      payload: id.toString(),
    );
  }
}

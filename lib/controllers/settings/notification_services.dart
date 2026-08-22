import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:retailpos/core/api/api_client.dart';
import 'package:retailpos/core/settings/local_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

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
          await ApiClient.put('/api/notifications/$id/read', {});
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

  static Future<void> show(int id, String title, String body) async {
    final showNotif = await LocalPreferences.getShowNotifications();
    if (!showNotif) return;

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

    await _notifications.show(
      id: id,
      title: notificationTitle,
      body: body,
      notificationDetails: details,
      payload: id.toString(),
    );
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:retailpos/core/api/api_client.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
      appName: 'Inventory INV',
      appUserModelId: 'com.Studentsdev.inventory',
      guid: '12345678-1234-1234-1234-123456789012',
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
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

    // Request notification permission on Android 13+ (API 33+).
    // This shows the OS permission dialog on first launch for all apps
    // that use this service (retail, customer, rider).
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  static Future<void> show(int id, String title, String body) async {
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

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: id.toString(),
    );
  }
}


import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inventory/core/api/api_client.dart';

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

    const InitializationSettings settings =
        InitializationSettings(windows: windowsSettings);

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final id = response.payload;

        if (id != null && id.isNotEmpty) {
          await ApiClient.put('/api/notifications/$id/read', {});
        }
      },
    );
  }

  static Future<void> show(int id, String title, String body) async {
    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails details =
        NotificationDetails(windows: windowsDetails);

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: id.toString(),
    );
  }
}

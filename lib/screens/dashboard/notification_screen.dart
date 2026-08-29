import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/settings/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final res = await ApiClient.get('/api/notifications');
      if (res != null && res['data'] is List) {
        final data = res['data'] as List;
        notifications = data.map((e) => AppNotification.fromJson(e)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('[LOAD NOTIFICATIONS ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> markRead(int id) async {
    try {
      await ApiClient.put('/api/notifications/$id/read', {});
    } catch (e) {
      debugPrint('[MARK READ ERROR]: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiClient.put('/api/notifications/mark-all-read', {});
      setState(() {
        notifications = notifications.map((n) {
          return AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MARK ALL READ ERROR]: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await ApiClient.delete('/api/notifications/$id');
    } catch (e) {
      debugPrint('[DELETE NOTIFICATION ERROR]: $e');
    }
  }

  Color typeColor(String type) {
    switch (type.toUpperCase()) {
      case "WARNING":
        return Colors.orange;
      case "ERROR":
        return Colors.red;
      case "SUCCESS":
        return Colors.green;
      default:
        return const Color(0xFF0284C7); // Vibrant Blue Dot
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          unreadCount > 0 ? "Notifications ($unreadCount)" : "Notifications",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: markAllRead,
              icon: const Icon(Icons.done_all, size: 18, color: Color(0xFF0284C7)),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadNotifications,
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "No notifications yet",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Reminders and system updates will appear here",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final isUnread = !n.isRead;

                        return Dismissible(
                          key: Key('notif_${n.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          ),
                          onDismissed: (_) async {
                            final deleted = notifications.removeAt(index);
                            setState(() {});
                            await deleteNotification(deleted.id);
                          },
                          child: InkWell(
                            onTap: () async {
                              if (!n.isRead) {
                                await markRead(n.id);
                                setState(() {
                                  notifications[index] = AppNotification(
                                    id: n.id,
                                    title: n.title,
                                    message: n.message,
                                    type: n.type,
                                    isRead: true,
                                    createdAt: n.createdAt,
                                  );
                                });
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isUnread ? const Color(0xFFE0F2FE) : Colors.white, // Light blue for Unseen, White for Seen
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isUnread ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, right: 10),
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: isUnread ? typeColor(n.type) : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: isUnread ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              timeAgo(n.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                                color: isUnread ? const Color(0xFF0284C7) : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (n.message.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            n.message,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";

    return "${diff.inDays}d";
  }
}

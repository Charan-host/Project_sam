import 'package:flutter/material.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.service, super.key});
  final NotificationService service;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> notificationsFuture = widget.service.list();
  void reload() => setState(() => notificationsFuture = widget.service.list());
  Future<void> markAll() async { await widget.service.markAllRead(); reload(); }
  String when(DateTime date) { final difference = DateTime.now().difference(date); if (difference.inMinutes < 1) return 'Just now'; if (difference.inHours < 1) return '${difference.inMinutes}m ago'; if (difference.inDays < 1) return '${difference.inHours}h ago'; return '${difference.inDays}d ago'; }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications'), actions: [TextButton(onPressed: markAll, child: const Text('Mark all read'))]),
    body: FutureBuilder<List<AppNotification>>(
      future: notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Unable to load notifications.'), const SizedBox(height: 12), FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Retry'))]));
        final notifications = snapshot.data ?? const [];
        if (notifications.isEmpty) return const Center(child: Text('You are all caught up.'));
        return ListView.separated(padding: const EdgeInsets.all(12), itemCount: notifications.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, index) {
          final notification = notifications[index];
          return Card(color: notification.isRead ? null : const Color(0xffe8eef8), child: ListTile(leading: Icon(notification.isRead ? Icons.notifications_none : Icons.notifications_active, color: notification.isRead ? Colors.grey : Colors.blue), title: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)), subtitle: Text('${notification.message}\n${when(notification.createdAt)}'), isThreeLine: true, onTap: notification.isRead ? null : () async { await widget.service.markRead(notification.id); reload(); }));
        });
      },
    ),
  );
}

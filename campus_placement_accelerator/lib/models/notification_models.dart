class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, required this.message, required this.isRead, required this.createdAt});
  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? 'general',
    title: json['title'] as String? ?? '',
    message: json['message'] as String? ?? '',
    isRead: (json['is_read'] ?? json['isRead']) as bool? ?? false,
    createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt']) as String? ?? '') ?? DateTime.now(),
  );
  final String id, type, title, message;
  final bool isRead;
  final DateTime createdAt;
}

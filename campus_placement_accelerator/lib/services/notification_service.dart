import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_models.dart';

class NotificationService {
  NotificationService({required this.baseUrl, required this.token});
  final String baseUrl;
  final String token;
  Map<String, String> get _headers => {'content-type': 'application/json', 'authorization': 'Bearer $token'};

  Future<Map<String, dynamic>> _request(String method, String path) async {
    final response = method == 'GET'
        ? await http.get(Uri.parse('$baseUrl$path'), headers: _headers)
        : await http.post(Uri.parse('$baseUrl$path'), headers: _headers);
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(body['error'] ?? 'Notification request failed');
    return body;
  }

  Future<List<AppNotification>> list() async => ((await _request('GET', '/notifications'))['notifications'] as List).map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
  Future<int> unreadCount() async => ((await _request('GET', '/notifications/unread-count'))['count'] as num?)?.toInt() ?? 0;
  Future<void> markRead(String id) async { await _request('POST', '/notifications/$id/read'); }
  Future<void> markAllRead() async { await _request('POST', '/notifications/read-all'); }
}

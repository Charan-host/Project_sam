import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mock_models.dart';

class MockService {
  MockService({required this.baseUrl, required this.token});
  final String baseUrl;
  final String token;
  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? payload]) async {
    final headers = {'content-type': 'application/json', 'authorization': 'Bearer $token'};
    final response = method == 'GET' ? await http.get(Uri.parse('$baseUrl$path'), headers: headers) : await http.post(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(payload ?? {}));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(body['error'] ?? 'Mock request failed');
    return body;
  }
  Future<List<MockTest>> tests() async => ((await _request('GET', '/mock-tests'))['tests'] as List).map((item) => MockTest.fromJson(item as Map<String, dynamic>)).toList();
  Future<MockTest> test(String id) async => MockTest.fromJson((await _request('GET', '/mock-tests/$id'))['test'] as Map<String, dynamic>);
  Future<Map<String, dynamic>> submit(MockTest test, Map<String, String> answers) => _request('POST', '/mock-tests/${test.id}/submit', {'answers': test.questions.map((question) => {'questionId': question.id, 'selectedAnswer': answers[question.id]}).toList()});
  Future<List<Map<String, dynamic>>> history() async => ((await _request('GET', '/mock-tests/history'))['attempts'] as List).cast<Map<String, dynamic>>();
}

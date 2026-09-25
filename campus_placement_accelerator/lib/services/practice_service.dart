import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/practice_models.dart';

class PracticeService {
  PracticeService({required this.baseUrl, required this.token});
  final String baseUrl;
  final String token;

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: {'authorization': 'Bearer $token'});
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(body['error'] ?? 'Practice request failed');
    return body;
  }

  Future<List<PracticeQuestion>> questions({required String category, required String difficulty, int limit = 10}) async {
    final result = await _get('/practice/questions?category=${Uri.encodeComponent(category)}&difficulty=${Uri.encodeComponent(difficulty)}&limit=$limit');
    return (result['questions'] as List).map((item) => PracticeQuestion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PracticeResult> submit({required String category, required String difficulty, required List<PracticeQuestion> questions, required Map<String, String> answers}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/practice/sessions'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
      body: jsonEncode({'category': category, 'difficulty': difficulty, 'answers': questions.map((question) => {'questionId': question.id, 'selectedAnswer': answers[question.id]}).toList()}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(body['error'] ?? 'Practice submission failed');
    return PracticeResult.fromJson(body['result'] as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> history() async => ((await _get('/practice/history'))['attempts'] as List).cast<Map<String, dynamic>>();
}

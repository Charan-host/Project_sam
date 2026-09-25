import 'practice_models.dart';

class MockTest {
  const MockTest({required this.id, required this.title, required this.description, required this.durationMinutes, required this.questionCount, required this.difficulty, required this.category, this.questions = const []});
  factory MockTest.fromJson(Map<String, dynamic> json) => MockTest(
    id: json['id'] as String? ?? '', title: json['title'] as String? ?? '', description: json['description'] as String? ?? '', durationMinutes: ((json['duration_minutes'] ?? json['durationMinutes']) as num?)?.toInt() ?? 30, questionCount: ((json['question_count'] ?? json['questionCount']) as num?)?.toInt() ?? 0, difficulty: json['difficulty'] as String? ?? 'Medium', category: json['category'] as String? ?? 'General', questions: (json['questions'] as List? ?? const []).map((item) => PracticeQuestion.fromJson(item as Map<String, dynamic>)).toList(),
  );
  final String id, title, description, difficulty, category;
  final int durationMinutes, questionCount;
  final List<PracticeQuestion> questions;
}

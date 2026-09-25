class PracticeQuestion {
  const PracticeQuestion({required this.id, required this.question, required this.options, required this.category, required this.topic, required this.difficulty, required this.explanation});
  factory PracticeQuestion.fromJson(Map<String, dynamic> json) => PracticeQuestion(
    id: json['id'] as String? ?? '',
    question: json['question'] as String? ?? '',
    options: (json['options'] as List? ?? const []).cast<String>(),
    category: json['category'] as String? ?? '',
    topic: json['topic'] as String? ?? '',
    difficulty: json['difficulty'] as String? ?? 'Medium',
    explanation: json['explanation'] as String? ?? '',
  );
  final String id, question, category, topic, difficulty, explanation;
  final List<String> options;
}

class PracticeResult {
  const PracticeResult({required this.score, required this.total, this.accuracy = 0});
  factory PracticeResult.fromJson(Map<String, dynamic> json) => PracticeResult(
    score: (json['score'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    accuracy: ((json['score'] as num?)?.toDouble() ?? 0) / ((json['total'] as num?)?.toDouble() ?? 1) * 100,
  );
  final int score, total;
  final double accuracy;
}

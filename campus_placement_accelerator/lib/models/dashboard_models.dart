class CategoryPerformance {
  const CategoryPerformance({required this.category, required this.attempted, required this.questions, required this.correct, required this.accuracy});
  factory CategoryPerformance.fromJson(Map<String, dynamic> json) => CategoryPerformance(category: json['category'] as String? ?? '', attempted: json['attempted'] as bool? ?? false, questions: (json['questions'] as num?)?.toInt() ?? 0, correct: (json['correct'] as num?)?.toInt() ?? 0, accuracy: (json['accuracy'] as num?)?.toInt() ?? 0);
  final String category; final bool attempted; final int questions, correct, accuracy;
}
class Recommendation {
  const Recommendation({required this.title, required this.description, required this.priority, required this.action});
  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(title: json['title'] as String? ?? '', description: json['description'] as String? ?? '', priority: json['priority'] as String? ?? 'Medium', action: json['action'] as String? ?? 'Open');
  final String title, description, priority, action;
}
class ProgressData {
  const ProgressData({required this.overallProgress, required this.tasksCompleted, required this.tasksPending, required this.tasksOverdue, required this.practiceAttempts, required this.practiceQuestionsAttempted, required this.practiceCorrect, required this.practiceAccuracy, required this.mockTestsCompleted, required this.averageMockScore, required this.currentStreak});
  factory ProgressData.fromJson(Map<String, dynamic> json) => ProgressData(overallProgress: (json['overallProgress'] as num?)?.toInt() ?? 0, tasksCompleted: (json['tasksCompleted'] as num?)?.toInt() ?? 0, tasksPending: (json['tasksPending'] as num?)?.toInt() ?? 0, tasksOverdue: (json['tasksOverdue'] as num?)?.toInt() ?? 0, practiceAttempts: (json['practiceAttempts'] as num?)?.toInt() ?? 0, practiceQuestionsAttempted: (json['practiceQuestionsAttempted'] as num?)?.toInt() ?? 0, practiceCorrect: (json['practiceCorrect'] as num?)?.toInt() ?? 0, practiceAccuracy: (json['practiceAccuracy'] as num?)?.toInt() ?? 0, mockTestsCompleted: (json['mockTestsCompleted'] as num?)?.toInt() ?? 0, averageMockScore: (json['averageMockScore'] as num?)?.toInt() ?? 0, currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0);
  final int overallProgress, tasksCompleted, tasksPending, tasksOverdue, practiceAttempts, practiceQuestionsAttempted, practiceCorrect, practiceAccuracy, mockTestsCompleted, averageMockScore, currentStreak;
  bool get hasActivity => tasksCompleted > 0 || practiceAttempts > 0 || mockTestsCompleted > 0;
}
class DashboardData {
  const DashboardData({required this.userName, required this.targetRole, required this.progress, required this.categories, required this.strengths, required this.weakAreas, required this.recommendations});
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final dashboard = json['dashboard'] as Map<String, dynamic>? ?? json;
    return DashboardData(userName: (dashboard['user'] as Map<String, dynamic>?)?['name'] as String? ?? 'Student', targetRole: (dashboard['user'] as Map<String, dynamic>?)?['targetRole'] as String? ?? '', progress: ProgressData.fromJson(dashboard), categories: ((dashboard['categories'] as List?) ?? const []).map((item) => CategoryPerformance.fromJson(item as Map<String, dynamic>)).toList(), strengths: ((dashboard['strengths'] as List?) ?? const []).cast<String>(), weakAreas: ((dashboard['weakAreas'] as List?) ?? const []).cast<String>(), recommendations: ((dashboard['recommendations'] as List?) ?? const []).map((item) => Recommendation.fromJson(item as Map<String, dynamic>)).toList());
  }
  final String userName, targetRole; final ProgressData progress; final List<CategoryPerformance> categories; final List<String> strengths, weakAreas; final List<Recommendation> recommendations;
}

import 'package:flutter/material.dart';
import '../models/practice_models.dart';
import '../services/practice_service.dart';

class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({required this.service, required this.category, required this.difficulty, super.key});
  final PracticeService service;
  final String category;
  final String difficulty;
  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  late Future<List<PracticeQuestion>> questionsFuture;
  List<PracticeQuestion> questions = const [];
  final answers = <String, String>{};
  int current = 0;
  bool submitting = false;
  PracticeResult? result;

  @override
  void initState() { super.initState(); questionsFuture = widget.service.questions(category: widget.category, difficulty: widget.difficulty); }

  Future<void> finish() async {
    setState(() => submitting = true);
    try {
      final saved = await widget.service.submit(category: widget.category, difficulty: widget.difficulty, questions: questions, answers: answers);
      if (mounted) setState(() { result = saved; submitting = false; });
    } catch (error) { if (mounted) { setState(() => submitting = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.category} Practice')),
    body: FutureBuilder<List<PracticeQuestion>>(
      future: questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Unable to load questions.\n${snapshot.error}', textAlign: TextAlign.center));
        questions = snapshot.data ?? const [];
        if (questions.isEmpty) return const Center(child: Text('No questions are available for this selection.'));
        if (result != null) return _resultView(result!);
        final question = questions[current];
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Question ${current + 1} / ${questions.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(question.question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          ...List.generate(question.options.length, (index) { final letter = String.fromCharCode(65 + index); return Card(child: RadioListTile<String>(value: letter, groupValue: answers[question.id], title: Text('$letter. ${question.options[index]}'), onChanged: (value) => setState(() => answers[question.id] = value!))); }),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: answers[question.id] == null ? null : () { if (current == questions.length - 1) { finish(); } else { setState(() => current += 1); } }, icon: Icon(current == questions.length - 1 ? Icons.check : Icons.arrow_forward), label: Text(current == questions.length - 1 ? 'Finish Practice' : 'Next Question')),
          if (submitting) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        ]);
      },
    ),
  );

  Widget _resultView(PracticeResult saved) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.emoji_events, color: Colors.green, size: 64), const SizedBox(height: 16), const Text('Practice Complete', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Text('${saved.score} / ${saved.total}', style: const TextStyle(fontSize: 40, color: Colors.green, fontWeight: FontWeight.w800)), Text('${saved.accuracy.round()}% accuracy'), const SizedBox(height: 24), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Practice'))])));
}

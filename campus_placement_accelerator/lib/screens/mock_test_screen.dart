import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_models.dart';
import '../services/mock_service.dart';

class StatusTimer extends StatelessWidget {
  const StatusTimer({required this.minutes, required this.seconds, super.key});
  final int minutes, seconds;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
      const SizedBox(width: 6),
      Text('Time remaining: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({required this.service, required this.testId, super.key});
  final MockService service;
  final String testId;
  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  late Future<MockTest> testFuture;
  MockTest? test;
  final answers = <String, String>{};
  int current = 0;
  bool submitting = false;
  Map<String, dynamic>? result;
  Timer? timer;
  int secondsRemaining = 0;
  bool timerStarted = false;
  @override
  void initState() { super.initState(); testFuture = widget.service.test(widget.testId); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  void startTimer(MockTest loadedTest) {
    if (timerStarted) return;
    timerStarted = true;
    secondsRemaining = loadedTest.durationMinutes * 60;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || result != null || submitting) return;
      if (secondsRemaining <= 1) {
        timer?.cancel();
        submit();
      } else {
        setState(() => secondsRemaining -= 1);
      }
    });
  }
  Future<void> submit() async {
    if (submitting || result != null || test == null) return;
    timer?.cancel();
    setState(() => submitting = true);
    try { final saved = await widget.service.submit(test!, answers); if (mounted) setState(() { result = saved['result'] as Map<String, dynamic>; submitting = false; }); } catch (error) { if (mounted) { setState(() => submitting = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mock Test')),
    body: FutureBuilder<MockTest>(
      future: testFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load mock test.\n${snapshot.error}', textAlign: TextAlign.center));
        }
        test = snapshot.data;
        if (test == null || test!.questions.isEmpty) {
          return const Center(child: Text('No mock questions are available.'));
        }
        startTimer(test!);
        if (result != null) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.emoji_events, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Test Completed', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text('${result!['score']} / ${result!['total']}', style: const TextStyle(fontSize: 40, color: Colors.green, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Mock Tests')),
          ]));
        }
        final question = test!.questions[current];
        final minutes = secondsRemaining ~/ 60;
        final seconds = secondsRemaining % 60;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Question ${current + 1} / ${test!.questions.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StatusTimer(minutes: minutes, seconds: seconds),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(question.question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          ...List.generate(question.options.length, (index) {
            final letter = String.fromCharCode(65 + index);
            return Card(child: RadioListTile<String>(value: letter, groupValue: answers[question.id], title: Text('$letter. ${question.options[index]}'), onChanged: (value) => setState(() => answers[question.id] = value!)));
          }),
          const SizedBox(height: 18),
          FilledButton(onPressed: answers[question.id] == null ? null : () { if (current == test!.questions.length - 1) { submit(); } else { setState(() => current += 1); } }, child: Text(current == test!.questions.length - 1 ? 'Submit Test' : 'Next Question')),
          if (submitting) const LinearProgressIndicator(),
        ]);
      },
    ),
  );
}

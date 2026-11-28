// SPDX-License-Identifier: Apache-2.0
part 'lessons.g.dart';

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.goal,
    required this.prompt,
    required this.workedExample,
    required this.plan,
    required this.rubric,
    required this.exitTicket,
    required this.answerKey,
  });

  final String id;
  final String title;
  final String goal;
  final String prompt;
  final String workedExample;
  final List<String> plan;
  final List<String> rubric;
  final String exitTicket;
  final String answerKey;

  static List<Lesson> inLanguage(String language) =>
      _lessons[language] ?? _lessons['es']!;
}

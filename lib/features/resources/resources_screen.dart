import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/section_title.dart';
import 'lesson.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return AulePage(
      title: context.l10n.resourcesTitle,
      help: context.l10n.resourcesIntro,
      children: [
        for (final lesson in Lesson.inLanguage(language))
          OptionButton(
            label: lesson.title,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => LessonScreen(id: lesson.id)),
            ),
          ),
      ],
    );
  }
}

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final lesson = Lesson.inLanguage(language)
        .firstWhere((lesson) => lesson.id == id);
    final words = context.l10n;
    final config = context.read<AppConfig>();
    final practice = config.resourceLink(id, language, practice: true);
    final printGuide = config.resourceLink(id, language, practice: false);
    return AulePage(
      title: lesson.title,
      help: lesson.goal,
      children: [
        SectionTitle(words.resourcesExercise),
        SelectableText(lesson.prompt),
        if (practice != null)
          LinkButton(
            label: words.resourcesPractise,
            onPressed: () => openResourceLink(context, practice),
          ),
        SectionTitle(words.resourcesPlan),
        for (final (i, step) in lesson.plan.indexed) Text('${i + 1}. $step'),
        ExpansionTile(
          title: Text(words.resourcesExample),
          children: [SelectableText(lesson.workedExample)],
        ),
        SectionTitle(words.resourcesRubric),
        for (final criterion in lesson.rubric) Text('• $criterion'),
        SectionTitle(words.resourcesExit),
        SelectableText(lesson.exitTicket),
        ExpansionTile(
          title: Text(words.resourcesKey),
          children: [SelectableText(lesson.answerKey)],
        ),
        if (printGuide != null)
          LinkButton(
            label: words.resourcesPrint,
            onPressed: () => openResourceLink(context, printGuide),
          ),
        Text(
          words.resourcesLicense,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

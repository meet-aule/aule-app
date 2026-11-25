import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/models/models.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/theme/aule_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/picker_field.dart';

/// What the add and edit forms change, kept by the screen. It starts from a
/// draft, so an edit keeps the fields the form does not show (the birth
/// year and the team's notes).
class ChildFormValues extends ChangeNotifier {
  ChildFormValues(ChildDraft base)
    : _base = base,
      nickname = TextEditingController(text: base.nickname),
      note = TextEditingController(text: base.tutorPersonaNote),
      newInterest = TextEditingController(),
      _grade = base.grade,
      _relationship =
          base.relationship == null || base.relationship!.trim().isEmpty
          ? null
          : base.relationship,
      _language = base.language,
      _interests = List<String>.of(base.interests),
      _subjects = List<String>.of(base.subjects),
      _persona = base.tutorPersona {
    nickname.addListener(notifyListeners);
  }

  final ChildDraft _base;
  final TextEditingController nickname;
  final TextEditingController note;
  final TextEditingController newInterest;
  String? _grade;
  String? _relationship;
  String _language;
  final List<String> _interests;
  final List<String> _subjects;
  String _persona;

  /// Shown under the name field.
  String? nameError;

  /// Shown under the interests.
  String? interestsError;

  String? get grade => _grade;
  set grade(String? value) {
    _grade = value;
    notifyListeners();
  }

  String? get relationship => _relationship;
  set relationship(String? value) {
    _relationship = value;
    notifyListeners();
  }

  String get language => _language;
  set language(String value) {
    _language = value;
    notifyListeners();
  }

  String get persona => _persona;
  set persona(String value) {
    _persona = value;
    notifyListeners();
  }

  List<String> get interests => List<String>.unmodifiable(_interests);
  List<String> get subjects => List<String>.unmodifiable(_subjects);

  bool hasInterest(String interest) => _indexOf(_interests, interest) >= 0;

  /// Adds or removes an interest. Answers false when adding would pass ten.
  bool toggleInterest(String interest) {
    final text = interest.trim();
    if (text.isEmpty) return true;
    final index = _indexOf(_interests, text);
    if (index >= 0) {
      _interests.removeAt(index);
      interestsError = null;
      notifyListeners();
      return true;
    }
    if (_interests.length >= ChildCodes.maxInterests) return false;
    _interests.add(text);
    notifyListeners();
    return true;
  }

  void toggleSubject(String code) {
    if (!_subjects.remove(code)) _subjects.add(code);
    notifyListeners();
  }

  /// Shows an error without changing a value.
  void touch() => notifyListeners();

  /// Clears the field errors before a new attempt.
  void clearErrors() {
    nameError = null;
    interestsError = null;
    notifyListeners();
  }

  /// Puts [problem] under the field it belongs to. Answers false for a
  /// problem no field can show; the screen then shows its own message.
  bool showProblem(ChildProblem problem, AppLocalizations l10n) {
    switch (problem) {
      case ChildProblem.nicknameMissing:
        nameError = l10n.childNameMissing;
      case ChildProblem.tooManyInterests:
        interestsError = l10n.childInterestsTooMany;
      case ChildProblem.nicknameTooLong:
      case ChildProblem.interestTooLong:
      case ChildProblem.personaNoteTooLong:
      case ChildProblem.unknownCode:
        return false;
    }
    notifyListeners();
    return true;
  }

  /// The draft to save: the base record with the form's changes. Interests
  /// are trimmed and de-duplicated here, as ChildDraft.toJson expects.
  ChildDraft toDraft() {
    final cleaned = <String>[];
    for (final interest in _interests) {
      final text = interest.trim();
      if (text.isNotEmpty && _indexOf(cleaned, text) < 0) cleaned.add(text);
    }
    return _base.copyWith(
      nickname: nickname.text.trim(),
      grade: _grade,
      clearGrade: _grade == null,
      language: _language,
      interests: cleaned,
      subjects: List<String>.of(_subjects),
      tutorPersona: _persona,
      tutorPersonaNote: note.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
      relationship: _relationship,
      clearRelationship: _relationship == null,
    );
  }

  static int _indexOf(List<String> list, String value) {
    final key = value.trim().toLowerCase();
    return list.indexWhere((item) => item.trim().toLowerCase() == key);
  }

  @override
  void dispose() {
    nickname.removeListener(notifyListeners);
    nickname.dispose();
    note.dispose();
    newInterest.dispose();
    super.dispose();
  }
}

/// The child's fields. [full] adds what only the edit screen shows:
/// subjects, how Aule talks to them, and a note.
class ChildForm extends StatelessWidget {
  const ChildForm({
    super.key,
    required this.values,
    this.full = false,
    this.subjectCodes = const <String>[],
    this.enabled = true,
  });

  final ChildFormValues values;
  final bool full;

  /// The subjects a family may ask to reinforce (`me.subjects`).
  final List<String> subjectCodes;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: values,
      builder: (context, _) => _fields(context),
    );
  }

  Widget _fields(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final optional = l10n.commonOptional;
    final name = values.nickname.text.trim();
    const gap = SizedBox(height: AuleSpace.xl);
    final suggestions = l10n.childInterestSuggestions
        .split(', ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final custom = values.interests
        .where(
          (interest) => !suggestions.any(
            (item) => item.toLowerCase() == interest.trim().toLowerCase(),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LineField(
          controller: values.nickname,
          label: l10n.childNameLabel,
          hint: l10n.childNameHint,
          error: values.nameError,
          maxLength: ChildCodes.maxNicknameChars,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[],
          enabled: enabled,
          private: true,
        ),
        gap,
        PickerField<String?>(
          label: '${l10n.childGradeLabel} ($optional)',
          value: values.grade,
          onChanged: enabled ? (value) => values.grade = value : null,
          options: <PickerOption<String?>>[
            PickerOption<String?>(value: null, label: l10n.commonRatherNotSay),
            for (final code in ChildCodes.grades)
              PickerOption<String?>(value: code, label: l10n.grade(code)),
          ],
        ),
        gap,
        PickerField<String?>(
          label:
              '${name.isEmpty ? l10n.childRelationshipLabelGeneric : l10n.childRelationshipLabel(name)} ($optional)',
          value: values.relationship,
          onChanged: enabled ? (value) => values.relationship = value : null,
          options: <PickerOption<String?>>[
            PickerOption<String?>(value: null, label: l10n.commonRatherNotSay),
            for (final code in ChildCodes.relationships)
              PickerOption<String?>(
                value: code,
                label: l10n.relationship(code),
              ),
          ],
        ),
        gap,
        Text(l10n.childInterestsLabel, style: theme.textTheme.labelSmall),
        const SizedBox(height: AuleSpace.s),
        Wrap(
          spacing: AuleSpace.s,
          runSpacing: AuleSpace.s,
          children: <Widget>[
            for (final item in <String>[...suggestions, ...custom])
              ChoiceChipButton(
                label: item,
                selected: values.hasInterest(item),
                onPressed: enabled
                    ? () => _toggleInterest(context, item)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AuleSpace.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: LineField(
                controller: values.newInterest,
                hint: l10n.childInterestsAddHint,
                maxLength: ChildCodes.maxInterestChars,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addInterest(context),
                enabled: enabled,
                private: true,
              ),
            ),
            const SizedBox(width: AuleSpace.m),
            SmallButton(
              label: l10n.childInterestsAdd,
              onPressed: enabled ? () => _addInterest(context) : null,
            ),
          ],
        ),
        const SizedBox(height: AuleSpace.s),
        if (values.interestsError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              values.interestsError!,
              style: theme.textTheme.bodySmall!.copyWith(
                color: AuleColors.danger,
              ),
            ),
          )
        else
          Text(l10n.childInterestsHelp, style: theme.textTheme.bodySmall),
        gap,
        Text(l10n.childLanguageLabel, style: theme.textTheme.labelSmall),
        const SizedBox(height: AuleSpace.s),
        Row(
          children: <Widget>[
            Expanded(
              child: OptionButton(
                label: l10n.languageEs,
                selected: values.language == 'es',
                onPressed: enabled ? () => values.language = 'es' : null,
              ),
            ),
            const SizedBox(width: AuleSpace.m),
            Expanded(
              child: OptionButton(
                label: l10n.languageEn,
                selected: values.language == 'en',
                onPressed: enabled ? () => values.language = 'en' : null,
              ),
            ),
          ],
        ),
        if (full) ...<Widget>[
          if (subjectCodes.isNotEmpty) ...<Widget>[
            gap,
            Text(l10n.childSubjectsLabel, style: theme.textTheme.labelSmall),
            const SizedBox(height: AuleSpace.s),
            Wrap(
              spacing: AuleSpace.s,
              runSpacing: AuleSpace.s,
              children: <Widget>[
                for (final code in subjectCodes)
                  ChoiceChipButton(
                    label: l10n.subject(code),
                    selected: values.subjects.contains(code),
                    onPressed: enabled
                        ? () => values.toggleSubject(code)
                        : null,
                  ),
              ],
            ),
          ],
          gap,
          Text(l10n.childPersonaLabel, style: theme.textTheme.labelSmall),
          const SizedBox(height: AuleSpace.s),
          for (final code in ChildCodes.personas) ...<Widget>[
            OptionButton(
              label: l10n.personaTitle(code),
              subtitle: l10n.personaHint(code),
              selected: values.persona == code,
              onPressed: enabled ? () => values.persona = code : null,
            ),
            const SizedBox(height: AuleSpace.s),
          ],
          gap,
          LineField(
            controller: values.note,
            label: '${l10n.childNoteLabel} ($optional)',
            hint: l10n.childNoteHint,
            maxLength: ChildCodes.maxPersonaNoteChars,
            textInputAction: TextInputAction.done,
            inputFormatters: const <TextInputFormatter>[OneLineFormatter()],
            enabled: enabled,
            private: true,
          ),
        ],
      ],
    );
  }

  void _toggleInterest(BuildContext context, String interest) {
    if (!values.toggleInterest(interest)) {
      values.interestsError = context.l10n.childInterestsTooMany;
      values.touch();
    }
  }

  void _addInterest(BuildContext context) {
    final text = values.newInterest.text.trim();
    if (text.isEmpty) return;
    if (values.hasInterest(text)) {
      values.newInterest.clear();
      return;
    }
    if (values.toggleInterest(text)) {
      values.newInterest.clear();
    } else {
      values.interestsError = context.l10n.childInterestsTooMany;
      values.touch();
    }
  }
}

/// A pill that can be picked: a 1.5 px ink border, picked fill and a check
/// when selected, 44 px tall.
class ChoiceChipButton extends StatelessWidget {
  const ChoiceChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(22);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: selected ? AuleColors.picked : AuleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: enabled ? AuleColors.ink : AuleColors.line,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    const Icon(Icons.check, size: 18, color: AuleColors.ink),
                    const SizedBox(width: AuleSpace.xs),
                  ],
                  Text(
                    label,
                    style: AuleText.sans(
                      15,
                      20,
                      selected ? 600 : 500,
                      color: enabled ? AuleColors.ink : AuleColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

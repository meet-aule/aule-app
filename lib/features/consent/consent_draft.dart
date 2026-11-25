/// The parent's answers on the consent screen. It exists only once the
/// voice box was ticked, so voice is always granted. Never persisted.
class ConsentDraft {
  const ConsentDraft({
    required this.memory,
    required this.transcripts,
    required this.locale,
  });

  final bool memory;
  final bool transcripts;

  /// 'es-PE' or 'en': the language the consent text was shown in.
  final String locale;

  @override
  String toString() => 'ConsentDraft(<in memory only>)';
}

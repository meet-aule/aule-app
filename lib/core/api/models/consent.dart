import '../json.dart';

enum ConsentPurpose { voice, transcripts, memory }

class ConsentState {
  const ConsentState({
    required this.voice,
    required this.transcripts,
    required this.memory,
  });

  factory ConsentState.fromJson(Json json) => ConsentState(
    voice: jBool(json, 'voice'),
    transcripts: jBool(json, 'transcripts'),
    memory: jBool(json, 'memory'),
  );

  /// A purpose never answered counts as not granted.
  static const none = ConsentState(
    voice: false,
    transcripts: false,
    memory: false,
  );

  final bool voice;
  final bool transcripts;
  final bool memory;

  bool of(ConsentPurpose purpose) => switch (purpose) {
    ConsentPurpose.voice => voice,
    ConsentPurpose.transcripts => transcripts,
    ConsentPurpose.memory => memory,
  };
}

class ConsentAnswer {
  const ConsentAnswer({
    required this.purpose,
    required this.granted,
    required this.policyVersion,
    required this.locale,
  });

  final ConsentPurpose purpose;
  final bool granted;
  final String policyVersion; // kConsentPolicyVersion
  final String locale; // 'es-PE' or 'en'

  Json toJson() => <String, dynamic>{
    'purpose': purpose.name,
    'granted': granted,
    'policy_version': policyVersion,
    'locale': locale,
  };
}

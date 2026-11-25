/// The version recorded with every consent answer, with the locale the
/// screen was shown in ('es-PE' or 'en'). It names the exact wording of
/// [kConsentTextKeys] in app_es.arb and app_en.arb: change it, and add the
/// new fingerprint to test/core/l10n/arb_test.dart, whenever any of them
/// changes.
///
/// - app-2026-11-v1: the first wording; never shipped.
/// - app-2026-11-v2: adds what is always kept (consentAlwaysKept), and
///   covers the words on the Privacy screen where answers are also given.
const kConsentPolicyVersion = 'app-2026-11-v2';

/// Every text the parent reads when giving or withdrawing an answer: the
/// consent screen, the voice sheet, the Privacy switches and the withdrawal
/// sheets.
const kConsentTextKeys = <String>[
  'consentVoice',
  'consentKeepToggle',
  'consentAlwaysKept',
  'consentMemory',
  'consentTranscripts',
  'consentNever',
  'grantVoiceTitle',
  'consentVoiceLabel',
  'consentVoiceDesc',
  'consentMemoryLabel',
  'consentMemoryDesc',
  'consentTranscriptsLabel',
  'consentTranscriptsDesc',
  'withdrawVoiceTitle',
  'withdrawVoiceBody',
  'sessionCloseNote',
  'sessionMayContinueNote',
  'withdrawVoiceConfirm',
  'withdrawMemoryTitle',
  'withdrawMemoryBody',
  'withdrawMemoryConfirm',
  'withdrawTranscriptsTitle',
  'withdrawTranscriptsBody',
  'withdrawTranscriptsConfirm',
];

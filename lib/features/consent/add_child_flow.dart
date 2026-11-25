import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/log/app_log.dart';
import 'consent_draft.dart';
import 'consent_texts.dart';

class AddChildResult {
  const AddChildResult({required this.childId, required this.allChoicesSaved});

  final String childId;
  final bool allChoicesSaved;
}

/// Voice consent could not be recorded. The child just created was deleted
/// again (profileConsentFailed), unless that failed too: then [childKept]
/// is true, the profile exists with no consent, and the flow keeps it as
/// [AddChildFlowSurface.pendingChild], so a retry records the consent for
/// it instead of creating a second child (profileConsentKept).
class ConsentNotRecorded implements Exception {
  const ConsentNotRecorded({this.childKept = false});

  final bool childKept;

  @override
  String toString() => 'ConsentNotRecorded(childKept: $childKept)';
}

abstract class AddChildFlowSurface extends ChangeNotifier {
  ConsentDraft? get consent;
  bool get hasConsent;
  void accept(ConsentDraft draft);
  void cancel();

  /// A child created for this draft whose voice consent is not recorded:
  /// the rollback failed. The profile screen says so and offers to delete
  /// it; [create] records the consent for it instead of creating another.
  ChildRef? get pendingChild;

  /// Creates the child, then records voice, memory and transcripts.
  Future<AddChildResult> create(ChildDraft draft);

  /// Deletes [pendingChild]. Throws when the platform could not be reached.
  Future<void> discardPending();
}

/// Adding a child: the parent's consent first, held in memory only, then
/// the profile (§6.9). Until the platform takes both in one call (gap 6a),
/// a child whose voice consent cannot be recorded is deleted again, and the
/// flow never creates a second child for one draft:
/// - a create whose answer was lost (a timeout, say) is followed by a look
///   at `me`, and the next attempt looks again before it creates;
/// - a child the rollback could not delete is kept as [pendingChild].
class AddChildFlow extends AddChildFlowSurface {
  /// [retryDelays] are the waits between attempts to record a consent; tests
  /// pass zero waits.
  AddChildFlow({
    required AuleApi api,
    required AuthController auth,
    List<Duration> retryDelays = const <Duration>[
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ],
  }) : _api = api,
       _auth = auth,
       _retryDelays = retryDelays {
    _auth.addListener(_onAuthChanged);
  }

  final AuleApi _api;
  final AuthController _auth;
  final List<Duration> _retryDelays;
  ConsentDraft? _consent;
  ChildRef? _pending;

  /// The children `me` listed before a create whose answer never came: the
  /// child may exist, so the next attempt looks before it creates.
  Set<String>? _unsure;
  bool _disposed = false;

  @override
  ConsentDraft? get consent => _consent;

  @override
  bool get hasConsent => _consent != null;

  @override
  ChildRef? get pendingChild => _pending;

  @override
  void accept(ConsentDraft draft) {
    _consent = draft;
    _notify();
  }

  @override
  void cancel() {
    if (_consent == null && _pending == null && _unsure == null) return;
    // A child left without consent stays visible in Family and Privacy,
    // where it can be deleted.
    _consent = null;
    _pending = null;
    _unsure = null;
    _notify();
  }

  @override
  Future<AddChildResult> create(ChildDraft draft) async {
    final consent = _consent;
    if (consent == null) {
      throw StateError('the consent comes before the child');
    }
    final me = _auth.me;
    if (me == null) throw StateError('create needs a signed-in guardian');

    // 1. The child, or the one an earlier attempt left without consent.
    final child = _pending ?? await _createChild(me.familyId, draft);
    _pending = child;

    // 2 and 3. Voice, or no child at all.
    final voice = await _record(
      child.id,
      ConsentPurpose.voice,
      granted: true,
      locale: consent.locale,
    );
    if (!voice) {
      final deleted = await _rollback(child.id);
      if (deleted) _pending = null;
      // Either way `me` shows the truth: the child gone, or still there.
      await _auth.refreshMe();
      _notify();
      throw ConsentNotRecorded(childKept: !deleted);
    }
    _pending = null;

    // 4. What we keep, yes or no: a "no" is recorded too, as evidence. A
    // missing answer counts as "no" on the server, the safe default.
    final memory = await _record(
      child.id,
      ConsentPurpose.memory,
      granted: consent.memory,
      locale: consent.locale,
    );
    final transcripts = await _record(
      child.id,
      ConsentPurpose.transcripts,
      granted: consent.transcripts,
      locale: consent.locale,
    );

    // 5. `me` first, while the draft still lets the router keep the profile
    // screen; then the draft goes. Clearing it first would send the router
    // back to the consent screen before the done screen opens.
    await _auth.refreshMe();
    _consent = null;
    _notify();
    return AddChildResult(
      childId: child.id,
      allChoicesSaved: memory && transcripts,
    );
  }

  @override
  Future<void> discardPending() async {
    final pending = _pending;
    if (pending == null) return;
    try {
      await _api.deleteChild(pending.id);
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound) rethrow;
    }
    _pending = null;
    await _auth.refreshMe();
    _notify();
  }

  /// Creates the child. When an earlier answer was lost it first looks at
  /// `me` for a child that appeared since, and uses that one.
  Future<ChildRef> _createChild(String familyId, ChildDraft draft) async {
    final unsure = _unsure;
    if (unsure != null) {
      // Throws when `me` cannot be read: still unsure, nothing is created.
      final found = await _appearedSince(unsure);
      _unsure = null;
      if (found != null) return _adopt(found, draft);
    }
    final known = <String>{for (final child in _auth.children) child.id};
    try {
      final child = await _api.createChild(familyId: familyId, draft: draft);
      return ChildRef(id: child.id, nickname: child.nickname);
    } on ApiException catch (error) {
      if (!_outcomeUnknown(error.kind)) rethrow;
      // The platform may have created the child before the answer was lost.
      AppLog.warn('add_child.create_unknown', <String, Object>{
        'kind': error.kind,
      });
      _unsure = known;
      try {
        final found = await _appearedSince(known);
        _unsure = null;
        if (found != null) return _adopt(found, draft);
      } on Exception {
        // Still unsure: the next attempt looks first.
      }
      rethrow;
    }
  }

  /// Whether a failed create may still have happened on the platform.
  static bool _outcomeUnknown(ApiErrorKind kind) =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.unavailable ||
      kind == ApiErrorKind.internal ||
      kind == ApiErrorKind.invalidResponse;

  /// The child `me` lists now that [known] did not, read fresh. Throws when
  /// `me` cannot be read.
  Future<ChildRef?> _appearedSince(Set<String> known) async {
    final me = await _api.me();
    final added = me.children.where((child) => !known.contains(child.id));
    // `me` lists children oldest first: the newest is the one just made.
    return added.isEmpty ? null : added.last;
  }

  /// Uses a child an earlier attempt created, with the profile as it is on
  /// the screen now. A failed update keeps the first profile; the parent
  /// can edit it later.
  Future<ChildRef> _adopt(ChildRef found, ChildDraft draft) async {
    try {
      final child = await _api.updateChild(found.id, draft);
      return ChildRef(id: child.id, nickname: child.nickname);
    } on Exception {
      AppLog.warn('add_child.adopt_update_failed');
      return found;
    }
  }

  /// Deletes a child whose voice consent could not be recorded, trying up
  /// to three times. True when it is gone.
  Future<bool> _rollback(String childId) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _api.deleteChild(childId);
        return true;
      } on ApiException catch (error) {
        if (error.kind == ApiErrorKind.notFound) return true;
        final retryable =
            error.kind == ApiErrorKind.network ||
            error.kind == ApiErrorKind.unavailable ||
            error.kind == ApiErrorKind.internal;
        if (!retryable || attempt >= _retryDelays.length) {
          AppLog.warn('add_child.rollback_failed', <String, Object>{
            'kind': error.kind,
          });
          return false;
        }
      } on Exception {
        AppLog.warn('add_child.rollback_failed');
        return false;
      }
      await Future<void>.delayed(_retryDelays[attempt]);
    }
  }

  /// Records one answer, trying up to three times on network, unavailable
  /// and internal errors.
  Future<bool> _record(
    String childId,
    ConsentPurpose purpose, {
    required bool granted,
    required String locale,
  }) async {
    final answer = ConsentAnswer(
      purpose: purpose,
      granted: granted,
      policyVersion: kConsentPolicyVersion,
      locale: locale,
    );
    for (var attempt = 0; ; attempt++) {
      try {
        await _api.recordConsent(childId, answer);
        return true;
      } on ApiException catch (error) {
        final retryable =
            error.kind == ApiErrorKind.network ||
            error.kind == ApiErrorKind.unavailable ||
            error.kind == ApiErrorKind.internal;
        if (!retryable || attempt >= _retryDelays.length) {
          AppLog.warn('add_child.consent_failed', <String, Object>{
            'purpose': purpose,
            'kind': error.kind,
          });
          return false;
        }
        await Future<void>.delayed(_retryDelays[attempt]);
      } on Exception {
        return false;
      }
    }
  }

  void _onAuthChanged() {
    // A draft never outlives the session it was given in.
    if (_auth.state != AuthState.signedIn &&
        (_consent != null || _pending != null || _unsure != null)) {
      _consent = null;
      _pending = null;
      _unsure = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

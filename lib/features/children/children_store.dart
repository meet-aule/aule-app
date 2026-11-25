import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';

/// Each child's full record and current consent, in memory only. It clears
/// itself when the guardian signs out, and drops children no longer in `me`.
class ChildrenStore extends ChangeNotifier {
  ChildrenStore({required AuleApi api, required AuthController auth})
    : _api = api,
      _auth = auth {
    _auth.addListener(_onAuthChanged);
    if (auth.state == AuthState.signedIn) {
      _knownChildren = <String>{for (final child in auth.children) child.id};
    }
  }

  final AuleApi _api;
  final AuthController _auth;
  final Map<String, ChildDetail> _details = <String, ChildDetail>{};
  final Map<String, Object> _errors = <String, Object>{};
  final Map<String, Future<ChildDetail>> _loading =
      <String, Future<ChildDetail>>{};

  /// Bumped on sign-out, so an answer that arrives later is dropped.
  int _generation = 0;
  bool _disposed = false;

  /// The children `me` listed at the last change, and whether a screen
  /// asked for all of them: a child added later is then loaded at once.
  Set<String>? _knownChildren;
  bool _loadsAll = false;

  ChildDetail? detail(String childId) => _details[childId];

  /// Why the last load of this child failed, if it did.
  Object? error(String childId) => _errors[childId];

  bool isLoading(String childId) => _loading.containsKey(childId);

  /// Loads every child in `me` that is not loaded yet, or all of them.
  /// Failures are kept per child, never thrown.
  Future<void> loadAll({bool force = false}) async {
    _loadsAll = true;
    await Future.wait(<Future<void>>[
      for (final child in _auth.children)
        if (force || !_details.containsKey(child.id))
          load(
            child.id,
            force: force,
          ).then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  /// One child's record. It does not notify until the answer arrives, so
  /// it is safe to call from initState.
  Future<ChildDetail> load(String childId, {bool force = false}) {
    final cached = _details[childId];
    if (!force && cached != null) return Future<ChildDetail>.value(cached);
    final pending = _loading[childId];
    if (pending != null) return pending;
    final future = _fetch(childId, _generation);
    _loading[childId] = future;
    return future;
  }

  /// Clears a failure and loads again; for a retry button.
  Future<void> retry(String childId) async {
    _errors.remove(childId);
    _notify();
    try {
      await load(childId, force: true);
    } on Exception {
      // Kept in error().
    }
  }

  Future<ChildDetail> _fetch(String childId, int generation) async {
    try {
      final detail = await _api.child(childId);
      if (generation == _generation) {
        _details[childId] = detail;
        _errors.remove(childId);
      }
      return detail;
    } on Exception catch (error) {
      if (generation == _generation) _errors[childId] = error;
      if (error is ApiException && error.kind == ApiErrorKind.notFound) {
        // Gone, perhaps deleted elsewhere: `me` drops it.
        unawaited(_auth.refreshMe());
      }
      rethrow;
    } finally {
      if (generation == _generation) _loading.remove(childId);
      _notify();
    }
  }

  /// Saves the whole record (PUT) and keeps the answer.
  Future<Child> update(String childId, ChildDraft draft) async {
    final child = await _api.updateChild(childId, draft);
    final previous = _details[childId];
    final relationship = draft.relationship;
    _details[childId] = ChildDetail(
      child: child,
      consent: previous?.consent ?? ConsentState.none,
      relationship: relationship == null || relationship.isEmpty
          ? null
          : relationship,
    );
    _notify();
    // The nickname may have changed, and `me` lists it.
    await _auth.refreshMe();
    return child;
  }

  /// Deletes the child and everything about them on the server.
  Future<void> delete(String childId) async {
    await _api.deleteChild(childId);
    _details.remove(childId);
    _errors.remove(childId);
    _notify();
    await _auth.refreshMe();
  }

  /// Keeps the consent the server answered after a change.
  void setConsent(String childId, ConsentState consent) {
    final previous = _details[childId];
    if (previous == null) return;
    _details[childId] = ChildDetail(
      child: previous.child,
      consent: consent,
      relationship: previous.relationship,
    );
    _notify();
  }

  void _onAuthChanged() {
    if (_auth.state != AuthState.signedIn) {
      // Always: an answer still on its way must not land after sign-out.
      _generation++;
      _knownChildren = null;
      _loadsAll = false;
      if (_details.isEmpty && _errors.isEmpty && _loading.isEmpty) return;
      _details.clear();
      _errors.clear();
      _loading.clear();
      _notify();
      return;
    }
    final ids = <String>{for (final child in _auth.children) child.id};
    final known = _knownChildren;
    _knownChildren = ids;
    if (known != null && _loadsAll) {
      // Privacy keeps its state, so a child added since is loaded here.
      for (final id in ids.difference(known)) {
        if (!_details.containsKey(id)) {
          load(id).then<void>((_) {}, onError: (Object _) {});
        }
      }
    }
    final stale = _details.keys.where((id) => !ids.contains(id)).toList();
    if (stale.isEmpty) return;
    for (final id in stale) {
      _details.remove(id);
      _errors.remove(id);
    }
    _notify();
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

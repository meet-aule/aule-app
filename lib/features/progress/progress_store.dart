import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/log/app_log.dart';

/// What the app knows about one child's progress, as the server said it.
@immutable
class ChildProgress {
  const ChildProgress({
    this.reviews,
    this.reviewsError,
    this.skills,
    this.skillsError,
    this.sessions,
    this.sessionsError,
  });

  /// Newest first; null until loaded.
  final List<Review>? reviews;
  final Object? reviewsError;
  final SkillReport? skills;
  final Object? skillsError;

  /// Newest first; null until loaded, and always null without sessionList.
  final List<SessionFact>? sessions;
  final Object? sessionsError;

  bool get loaded => reviews != null || reviewsError != null;

  Review? get latestReview {
    final list = reviews;
    return list == null || list.isEmpty ? null : list.first;
  }

  List<SessionFact> get liveSessions => <SessionFact>[
    for (final session in sessions ?? const <SessionFact>[])
      if (session.isLive) session,
  ];

  /// When the child last had a session, from the facts or the reviews.
  DateTime? get lastSessionAt {
    DateTime? latest = latestReview?.createdAt;
    for (final session in sessions ?? const <SessionFact>[]) {
      final at = session.startedAt ?? session.createdAt;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }
}

/// Notices, and per child the reviews, skills and session facts, plus the
/// skill catalog (§6.2). In memory only; it clears itself on sign-out.
class ProgressStore extends ChangeNotifier {
  ProgressStore({
    required AuleApi api,
    required AuthController auth,
    required FeatureFlags flags,
  }) : _api = api,
       _auth = auth,
       _flags = flags {
    _auth.addListener(_onAuthChanged);
    if (auth.state == AuthState.signedIn) {
      _knownChildren = <String>{for (final child in auth.children) child.id};
    }
  }

  final AuleApi _api;
  final AuthController _auth;
  final FeatureFlags _flags;

  List<Notice> _notices = const <Notice>[];
  bool _noticesLoaded = false;
  Object? _noticesError;
  final Map<String, ChildProgress> _children = <String, ChildProgress>{};
  Map<String, SkillInfo>? _catalog;
  Future<void>? _refreshing;
  final Set<String> _marking = <String>{};

  /// The children `me` listed at the last change, to spot one added later.
  Set<String>? _knownChildren;

  /// Bumped on sign-out, so an answer that arrives later is dropped.
  int _generation = 0;
  bool _disposed = false;

  /// Newest first, at most the server's 50.
  List<Notice> get notices => _notices;
  bool get noticesLoaded => _noticesLoaded;
  Object? get noticesError => _noticesError;

  ChildProgress progressOf(String childId) =>
      _children[childId] ?? const ChildProgress();

  /// False when the catalog could not be loaded: screens show counts only.
  bool get catalogAvailable => _catalog != null;

  String? skillName(String skillId) => _catalog?[skillId]?.name;

  Notice? notice(String noticeId) {
    for (final notice in _notices) {
      if (notice.id == noticeId) return notice;
    }
    return null;
  }

  List<Notice> noticesFor(String childId) => <Notice>[
    for (final notice in _notices)
      if (notice.childId == childId) notice,
  ];

  /// The child's live sessions, known only with the sessionList flag.
  List<SessionFact> liveSessions(String childId) => _flags.sessionList
      ? progressOf(childId).liveSessions
      : const <SessionFact>[];

  /// Ends every session of the child that is live now, read fresh from the
  /// platform rather than from what Progress last showed (gap 6b: the
  /// platform does not end them itself). True when none is left running;
  /// false when the list could not be read or one could not be ended.
  /// Without sessionList the app cannot see sessions, and it answers false.
  Future<bool> endLiveSessions(String childId) async {
    if (!_flags.sessionList) return false;
    var ended = true;
    try {
      final sessions = await _api.sessions(childId);
      for (final session in sessions) {
        if (!session.isLive) continue;
        try {
          await _api.endSession(session.id);
        } on ApiException catch (error) {
          // Gone already counts as ended.
          if (error.kind != ApiErrorKind.notFound) ended = false;
        }
      }
    } on Exception {
      ended = false;
    }
    if (!ended) AppLog.warn('progress.end_live_failed');
    unawaited(refreshChild(childId));
    return ended;
  }

  /// Loads everything again: notices, the catalog once, and every child.
  /// B2 calls it after ending a session. Concurrent calls share one run.
  Future<void> refresh() {
    if (_auth.state != AuthState.signedIn) return Future<void>.value();
    return _refreshing ??= _refreshAll().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      refreshNotices(),
      if (_catalog == null) _loadCatalog(),
      for (final child in _auth.children) refreshChild(child.id),
    ]);
  }

  Future<void> refreshNotices() async {
    if (_auth.state != AuthState.signedIn) return;
    final generation = _generation;
    try {
      final list = await _api.notices();
      if (generation != _generation) return;
      _notices = list.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _noticesLoaded = true;
      _noticesError = null;
    } on Exception catch (error) {
      if (generation != _generation) return;
      _noticesError = error;
    }
    _notify();
  }

  /// One child's reviews and skills, and their sessions with sessionList.
  Future<void> refreshChild(String childId) async {
    if (_auth.state != AuthState.signedIn) return;
    final generation = _generation;
    final results = await Future.wait(<Future<Object?>>[
      _attempt(() => _api.reviews(childId)),
      _attempt(() => _api.skills(childId)),
      if (_flags.sessionList) _attempt(() => _api.sessions(childId)),
    ]);
    if (generation != _generation) return;
    final previous = progressOf(childId);
    final reviews = results[0];
    final skills = results[1];
    final sessions = _flags.sessionList ? results[2] : null;
    _children[childId] = ChildProgress(
      reviews: reviews is List<Review>
          ? _newestReviews(reviews)
          : previous.reviews,
      reviewsError: reviews is List<Review> ? null : reviews,
      skills: skills is SkillReport ? skills : previous.skills,
      skillsError: skills is SkillReport ? null : skills,
      sessions: sessions is List<SessionFact>
          ? _newestSessions(sessions)
          : previous.sessions,
      sessionsError: sessions is List<SessionFact> ? null : sessions,
    );
    _goneIfMissing(<Object?>[reviews, skills, sessions]);
    _notify();
  }

  /// The 60 s refresh of the session lists, which show live sessions.
  Future<void> refreshLive() async {
    if (!_flags.sessionList || _auth.state != AuthState.signedIn) return;
    final generation = _generation;
    for (final child in _auth.children) {
      try {
        final sessions = await _api.sessions(child.id);
        if (generation != _generation) return;
        final previous = progressOf(child.id);
        _children[child.id] = ChildProgress(
          reviews: previous.reviews,
          reviewsError: previous.reviewsError,
          skills: previous.skills,
          skillsError: previous.skillsError,
          sessions: _newestSessions(sessions),
        );
      } on Exception {
        // The next refresh tries again.
      }
    }
    _notify();
  }

  /// Marks a notice read once, then refreshes `me` so the tab badge falls.
  Future<void> markRead(String noticeId) async {
    final current = notice(noticeId);
    if (current == null || !current.unread || _marking.contains(noticeId)) {
      return;
    }
    _marking.add(noticeId);
    try {
      await _api.markNoticeRead(noticeId);
      _notices = <Notice>[
        for (final item in _notices)
          item.id == noticeId ? item.markedRead(DateTime.now().toUtc()) : item,
      ];
      _notify();
      await _auth.refreshMe();
    } on Exception {
      // It stays unread; opening it again tries again.
    } finally {
      _marking.remove(noticeId);
    }
  }

  Future<void> _loadCatalog() async {
    final generation = _generation;
    try {
      final skills = await _api.skillCatalog();
      if (generation != _generation) return;
      _catalog = <String, SkillInfo>{
        for (final skill in skills) skill.id: skill,
      };
      _notify();
    } on Exception {
      // Without the catalog, only the counts show.
    }
  }

  static Future<Object?> _attempt(Future<Object?> Function() call) async {
    try {
      return await call();
    } on Exception catch (error) {
      return error;
    }
  }

  static List<Review> _newestReviews(List<Review> reviews) =>
      reviews.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static List<SessionFact> _newestSessions(List<SessionFact> sessions) =>
      sessions.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// A child of another family, or one deleted elsewhere, answers 404:
  /// refresh `me`, which drops it.
  void _goneIfMissing(List<Object?> results) {
    final gone = results.any(
      (result) =>
          result is ApiException && result.kind == ApiErrorKind.notFound,
    );
    if (gone) unawaited(_auth.refreshMe());
  }

  void _onAuthChanged() {
    if (_auth.state != AuthState.signedIn) {
      // Always: an answer still on its way must not land after sign-out.
      _generation++;
      _refreshing = null;
      _knownChildren = null;
      if (_notices.isEmpty && _children.isEmpty && !_noticesLoaded) return;
      _notices = const <Notice>[];
      _noticesLoaded = false;
      _noticesError = null;
      _children.clear();
      _catalog = null;
      _notify();
      return;
    }
    final ids = <String>{for (final child in _auth.children) child.id};
    final known = _knownChildren;
    _knownChildren = ids;
    if (known != null && (_noticesLoaded || _children.isNotEmpty)) {
      // A child added since (from Family, say) is loaded at once: the tab
      // keeps its state, so its own first load does not run again.
      for (final id in ids.difference(known)) {
        if (!_children.containsKey(id)) unawaited(refreshChild(id));
      }
    }
    final stale = _children.keys.where((id) => !ids.contains(id)).toList();
    final orphanNotices = _notices.any(
      (notice) => notice.childId != null && !ids.contains(notice.childId),
    );
    if (stale.isEmpty && !orphanNotices) return;
    for (final id in stale) {
      _children.remove(id);
    }
    _notices = <Notice>[
      for (final notice in _notices)
        if (notice.childId == null || ids.contains(notice.childId)) notice,
    ];
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

import 'dart:convert';

import 'package:aule/core/api/json.dart';

enum LiveMode { listen, speak }

/// What POST /sessions/{id}/join answers (gap 4).
class LiveJoin {
  const LiveJoin({
    required this.serverUrl,
    required this.room,
    required this.token,
    required this.expiresInSeconds,
    required this.identity,
  });

  factory LiveJoin.fromJson(Json json) => LiveJoin(
    serverUrl: jString(json, 'serverUrl'),
    room: jString(json, 'room'),
    token: jString(json, 'token'),
    expiresInSeconds: jInt(json, 'expiresInSeconds'),
    identity: jString(json, 'identity'),
  );

  final String serverUrl;
  final String room;

  /// A LiveKit JWT. Kept in memory only; never stored or logged.
  final String token;
  final int expiresInSeconds;
  final String identity;

  /// The token's video grant, read without checking the signature. It is
  /// used only to refuse a token that would hide the adult (§9.2).
  ///
  /// Absent fields take LiveKit's defaults: `canPublish` is true, and
  /// `canPublishData` follows `canPublish`.
  LiveGrants get grants {
    final parts = token.split('.');
    if (parts.length != 3) return LiveGrants.unreadable;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final video = payload is Map<String, dynamic> ? payload['video'] : null;
      if (video is! Map<String, dynamic>) return LiveGrants.unreadable;
      final canPublish = jBool(video, 'canPublish', fallback: true);
      return LiveGrants(
        hidden: jBool(video, 'hidden'),
        canPublish: canPublish,
        canPublishData: jBool(video, 'canPublishData', fallback: canPublish),
        sources: jStrings(video, 'canPublishSources'),
      );
    } on FormatException {
      return LiveGrants.unreadable;
    }
  }

  @override
  String toString() => 'LiveJoin(<redacted>)';
}

class LiveGrants {
  const LiveGrants({
    required this.hidden,
    required this.canPublish,
    required this.canPublishData,
    required this.sources,
  });

  static const unreadable = LiveGrants(
    hidden: true,
    canPublish: false,
    canPublishData: false,
    sources: [],
  );

  final bool hidden;
  final bool canPublish;
  final bool canPublishData;
  final List<String> sources;

  /// The app connects only with a visible, camera-free, data-free token.
  /// A token that may publish but names no sources may publish every
  /// source in LiveKit, the camera included.
  bool get acceptable =>
      !hidden &&
      !canPublishData &&
      !(canPublish && (sources.isEmpty || sources.contains('camera')));

  /// What a join token must be (§9.2): acceptable, and listening only. The
  /// microphone comes later, as a permission update, once the tutor has
  /// told the child that an adult will talk.
  bool get joinable => acceptable && !canPublish;
}

import 'package:flutter/foundation.dart';

import '../data/live_models.dart';

enum LiveLink { idle, connecting, connected, reconnecting, disconnected }

enum LiveSpeaker { child, tutor, me, otherAdult }

enum LiveEndReason { left, sessionEnded, removed, replaced, failed }

/// One adult's presence in one session's room: audio only.
abstract class LiveConnection extends ChangeNotifier {
  LiveLink get link;
  Set<LiveSpeaker> get speaking;

  /// The platform granted the microphone (mode speak).
  bool get canTalk;
  bool get microphoneOn;
  bool get otherAdultPresent;
  LiveEndReason? get endReason;

  /// Throws StateError when join.grants is not acceptable.
  Future<void> connect(LiveJoin join);
  Future<void> setMicrophone(bool on);
  Future<void> leave();
}

abstract interface class LiveConnector {
  LiveConnection create();
}

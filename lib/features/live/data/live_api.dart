import 'live_models.dart';

abstract interface class LiveApi {
  /// POST /sessions/{id}/join {mode}. The app always joins listening.
  Future<LiveJoin> join(String sessionId, {LiveMode mode = LiveMode.listen});

  /// PUT /sessions/{id}/join {mode}: asks the platform to grant or take back
  /// the microphone. The grant arrives as a LiveKit permissions update.
  Future<void> setMode(String sessionId, LiveMode mode);
}

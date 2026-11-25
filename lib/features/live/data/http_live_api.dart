import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/api_transport.dart';

import 'live_api.dart';
import 'live_models.dart';

/// [LiveApi] against the platform's join routes (gap 4, §9.4).
class HttpLiveApi implements LiveApi {
  HttpLiveApi(this._transport);

  final ApiTransport _transport;

  static String _path(String sessionId) =>
      '/sessions/${Uri.encodeComponent(sessionId)}/join';

  @override
  Future<LiveJoin> join(
    String sessionId, {
    LiveMode mode = LiveMode.listen,
  }) async {
    final json = await _transport.post(_path(sessionId), <String, dynamic>{
      'mode': mode.name,
    });
    if (json == null) {
      throw const ApiException(ApiErrorKind.invalidResponse, status: 200);
    }
    try {
      return LiveJoin.fromJson(json);
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
  }

  @override
  Future<void> setMode(String sessionId, LiveMode mode) async {
    await _transport.put(_path(sessionId), <String, dynamic>{
      'mode': mode.name,
    });
  }
}

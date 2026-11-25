import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/api_transport.dart';
import 'package:aule/core/api/json.dart';

import 'device_api.dart';
import 'device_models.dart';

/// [DeviceApi] against the platform (§8.3). Paths are relative to the base
/// that ends in /v1.
class HttpDeviceApi implements DeviceApi {
  HttpDeviceApi(this._transport);

  final ApiTransport _transport;

  @override
  Future<List<Device>> devices() async {
    final json = await _transport.get('/devices');
    return _parse(() => jList(json, 'devices', Device.fromJson));
  }

  @override
  Future<ClaimResult> claim({required String code, String? childId}) async {
    final json = await _transport.post('/devices/claim', <String, dynamic>{
      'code': code,
      if (childId != null) 'child_id': childId,
    });
    if (json == null) {
      throw const ApiException(ApiErrorKind.invalidResponse, status: 200);
    }
    return _parse(() => ClaimResult.fromJson(json));
  }

  @override
  Future<void> assign(String deviceId, {required String? childId}) async {
    await _transport.put(
      '/devices/${Uri.encodeComponent(deviceId)}',
      <String, dynamic>{'child_id': childId},
    );
  }

  @override
  Future<void> unlink(String deviceId) async {
    await _transport.delete('/devices/${Uri.encodeComponent(deviceId)}');
  }

  /// An answer that is not the JSON promised is `invalidResponse`.
  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
  }
}

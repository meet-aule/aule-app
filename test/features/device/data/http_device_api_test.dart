import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/api_transport.dart';
import 'package:aule/core/api/json.dart';
import 'package:aule/features/device/data/device_models.dart';
import 'package:aule/features/device/data/http_device_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  const _Call(this.method, this.path, this.body);

  final String method;
  final String path;
  final Json? body;
}

/// Records each request and answers with [answer].
class _RecordingTransport implements ApiTransport {
  final calls = <_Call>[];
  Json? answer;

  @override
  Future<Json> get(String path, {Map<String, String>? query}) async {
    calls.add(_Call('GET', path, null));
    return answer ?? <String, dynamic>{};
  }

  @override
  Future<Json?> post(String path, [Json? body]) async {
    calls.add(_Call('POST', path, body));
    return answer;
  }

  @override
  Future<Json?> put(String path, [Json? body]) async {
    calls.add(_Call('PUT', path, body));
    return answer;
  }

  @override
  Future<Json?> delete(String path, [Json? body]) async {
    calls.add(_Call('DELETE', path, body));
    return answer;
  }
}

void main() {
  late _RecordingTransport transport;
  late HttpDeviceApi api;

  setUp(() {
    transport = _RecordingTransport();
    api = HttpDeviceApi(transport);
  });

  test('devices() is GET /devices', () async {
    transport.answer = <String, dynamic>{
      'devices': <Json>[
        <String, dynamic>{
          'id': 'd1',
          'serial': 'AUL02-000123',
          'model': 'aule-v0.2',
          'family_id': 'f1',
          'child_id': 'c1',
          'claimed_at': '2026-11-13T15:04:05Z',
          'firmware_version': null,
          'last_seen_at': '2026-11-25T14:50:00Z',
        },
      ],
    };
    final devices = await api.devices();
    expect(transport.calls.single.method, 'GET');
    expect(transport.calls.single.path, '/devices');
    expect(devices.single.childId, 'c1');
    expect(devices.single.firmwareVersion, isNull);
  });

  test('claim posts the code, and the child only when there is one', () async {
    transport.answer = <String, dynamic>{
      'device_id': 'd9',
      'status': 'waiting_for_device',
    };
    final result = await api.claim(code: 'K7QM2X', childId: 'c1');
    expect(result.deviceId, 'd9');
    expect(result.status, ClaimStatus.waitingForDevice);
    expect(transport.calls.last.method, 'POST');
    expect(transport.calls.last.path, '/devices/claim');
    expect(transport.calls.last.body, <String, dynamic>{
      'code': 'K7QM2X',
      'child_id': 'c1',
    });

    await api.claim(code: 'K7QM2X');
    expect(transport.calls.last.body, <String, dynamic>{'code': 'K7QM2X'});
  });

  test(
    'a claim answer that is not the promised JSON is invalidResponse',
    () async {
      transport.answer = <String, dynamic>{'status': 'claimed'};
      await expectLater(
        api.claim(code: 'K7QM2X'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test('assign puts the child, or null for nobody', () async {
    await api.assign('d1', childId: 'c2');
    expect(transport.calls.last.method, 'PUT');
    expect(transport.calls.last.path, '/devices/d1');
    expect(transport.calls.last.body, <String, dynamic>{'child_id': 'c2'});

    await api.assign('d1', childId: null);
    expect(transport.calls.last.body, <String, dynamic>{'child_id': null});
  });

  test('unlink is DELETE /devices/{id}, with the id encoded', () async {
    await api.unlink('a/b');
    expect(transport.calls.last.method, 'DELETE');
    expect(transport.calls.last.path, '/devices/a%2Fb');
  });
}

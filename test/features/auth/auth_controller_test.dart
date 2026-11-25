import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/fake/fake_aule_api.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/storage/app_prefs.dart';
import 'package:aule/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/harness.dart';

/// The platform is unreachable for `me`.
class OfflineApi extends FakeAuleApi {
  OfflineApi() : super(latency: Duration.zero);

  @override
  Future<Me> me() async => throw const ApiException(ApiErrorKind.network);
}

void main() {
  group('restore', () {
    test('no token: signed out', () async {
      final auth = testAuth(api: instantApi());
      expect(auth.state, AuthState.unknown);
      await auth.restore();
      expect(auth.state, AuthState.signedOut);
      expect(auth.me, isNull);
    });

    test('a token and me: signed in', () async {
      final auth = await signedInAuth(instantApi());
      expect(auth.me!.familyId, DemoData.familyId);
      expect(auth.children, hasLength(2));
    });

    test('a 401 clears the token and signs out, with no message', () async {
      final tokens = TokenStore.memory(demo: true);
      await tokens.write(FakeAuleApi.token);
      final auth = testAuth(api: instantApi(signedIn: false), tokens: tokens);
      await auth.restore();
      expect(auth.state, AuthState.signedOut);
      expect(await tokens.read(), isNull);
      expect(auth.takeFlash(), isNull);
    });

    test('offline: still unknown, with an error to retry', () async {
      final tokens = TokenStore.memory(demo: true);
      await tokens.write(FakeAuleApi.token);
      final auth = testAuth(api: OfflineApi(), tokens: tokens);
      await auth.restore();
      expect(auth.state, AuthState.unknown);
      expect(auth.restoreError!.kind, ApiErrorKind.network);
      // The token is kept for the retry.
      expect(await tokens.read(), FakeAuleApi.token);
    });
  });

  group('sign-in with an emailed code', () {
    test('the existing account', () async {
      final tokens = TokenStore.memory(demo: true);
      final auth = testAuth(api: instantApi(signedIn: false), tokens: tokens);
      await auth.restore();
      await auth.startEmailSignIn('  ANA@example.com ');
      expect(auth.pendingEmail, 'ana@example.com');
      final outcome = await auth.verifyCode(DemoData.signInCode);
      expect(outcome, SignInOutcome.signedIn);
      expect(auth.state, AuthState.signedIn);
      expect(auth.pendingEmail, isNull);
      expect(await tokens.read(), FakeAuleApi.token);
    });

    test('a wrong code is forbidden and keeps the parent signed out', () async {
      final auth = testAuth(api: instantApi(signedIn: false));
      await auth.restore();
      await auth.startEmailSignIn('ana@example.com');
      await expectLater(
        auth.verifyCode('111111'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );
      expect(auth.state, AuthState.signedOut);
      expect(auth.pendingEmail, 'ana@example.com');
    });

    test('a new address asks for a name, then creates the account', () async {
      final auth = testAuth(api: instantApi(signedIn: false));
      await auth.restore();
      await auth.startEmailSignIn('rosa@example.com');
      expect(
        await auth.verifyCode(DemoData.signInCode),
        SignInOutcome.needsName,
      );
      expect(auth.state, AuthState.signedOut);
      await auth.completeWithName('  Rosa ');
      expect(auth.state, AuthState.signedIn);
      expect(auth.me!.guardian.name, 'Rosa');
      expect(auth.children, isEmpty);
    });

    test('sign-in sends the UI language', () async {
      final auth = testAuth(
        api: instantApi(signedIn: false),
        deviceLocale: const Locale('en', 'US'),
      );
      await auth.restore();
      await auth.startEmailSignIn('lee@example.com');
      await auth.verifyCode(DemoData.signInCode);
      await auth.completeWithName('Lee');
      expect(auth.me!.guardian.language, 'en');
      expect(auth.language, 'en');
    });
  });

  group('language', () {
    test('before sign-in: prefs, then the device locale', () {
      expect(
        testAuth(
          api: instantApi(),
          prefs: AppPrefs.memory(uiLanguage: 'en'),
        ).language,
        'en',
      );
      expect(
        testAuth(api: instantApi(), deviceLocale: const Locale('en')).language,
        'en',
      );
      expect(
        testAuth(
          api: instantApi(),
          deviceLocale: const Locale('pt', 'BR'),
        ).language,
        'es',
      );
    });

    test('once signed in, the guardian language wins and is saved', () async {
      final prefs = AppPrefs.memory(uiLanguage: 'en');
      final tokens = TokenStore.memory(demo: true);
      await tokens.write(FakeAuleApi.token);
      final auth = testAuth(api: instantApi(), tokens: tokens, prefs: prefs);
      await auth.restore();
      expect(auth.language, 'es');
      expect(prefs.uiLanguage, 'es');
    });

    test('setLanguage updates the server, me, prefs and locale', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      var notified = 0;
      auth.addListener(() => notified++);
      await auth.setLanguage('en');
      expect(auth.locale, const Locale('en'));
      expect(auth.me!.guardian.language, 'en');
      expect((await api.me()).guardian.language, 'en');
      expect(notified, greaterThan(0));
    });
  });

  group('leaving', () {
    test('sign-out forgets the session', () async {
      final auth = await signedInAuth(instantApi());
      auth.dismissStart();
      await auth.signOut();
      expect(auth.state, AuthState.signedOut);
      expect(auth.me, isNull);
      expect(auth.children, isEmpty);
      expect(auth.startDismissed, isFalse);
      expect(auth.takeFlash(), isNull);
    });

    test('a 401 while signed in leaves the expired message once', () async {
      final auth = await signedInAuth(instantApi());
      auth.handleUnauthorized();
      expect(auth.state, AuthState.signedOut);
      expect(auth.takeFlash(), AuthController.flashExpired);
      expect(auth.takeFlash(), isNull);
    });

    test('a 401 while signed out changes nothing', () async {
      final auth = testAuth(api: instantApi());
      await auth.restore();
      auth.handleUnauthorized();
      expect(auth.takeFlash(), isNull);
    });

    test('deleting the account leaves its own message', () async {
      final auth = await signedInAuth(instantApi());
      await auth.deleteAccount(DemoData.guardianEmail);
      expect(auth.state, AuthState.signedOut);
      expect(auth.takeFlash(), AuthController.flashAccountDeleted);
    });

    test(
      'deleting with another email is refused and keeps the session',
      () async {
        final auth = await signedInAuth(instantApi());
        await expectLater(
          auth.deleteAccount('otra@example.com'),
          throwsA(isA<ApiException>()),
        );
        expect(auth.state, AuthState.signedIn);
      },
    );
  });

  test('email notices', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    await auth.setNoticesByEmail(false);
    expect(auth.me!.guardian.noticesByEmail, isFalse);
    expect((await api.me()).guardian.noticesByEmail, isFalse);
  });
}

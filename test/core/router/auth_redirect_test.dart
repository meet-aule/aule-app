import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/router/app_router.dart';
import 'package:aule/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

String? redirect(
  AuthState state,
  String location, {
  bool hasChildren = true,
  bool startDismissed = false,
  bool hasConsentDraft = false,
}) => authRedirect(
  state: state,
  hasChildren: hasChildren,
  startDismissed: startDismissed,
  hasConsentDraft: hasConsentDraft,
  location: location,
);

void main() {
  group('while the session is being restored', () {
    test('everything waits on /loading', () {
      expect(redirect(AuthState.unknown, Routes.loading), isNull);
      expect(redirect(AuthState.unknown, Routes.progress), Routes.loading);
      expect(redirect(AuthState.unknown, Routes.signIn), Routes.loading);
      expect(redirect(AuthState.unknown, '/live/s1'), Routes.loading);
    });
  });

  group('signed out', () {
    test('only the sign-in screens are open', () {
      for (final location in <String>[
        Routes.signIn,
        Routes.signInEmail,
        Routes.signInCode,
        Routes.signInName,
        Routes.signInHelp,
      ]) {
        expect(
          redirect(AuthState.signedOut, location),
          isNull,
          reason: location,
        );
      }
      for (final location in <String>[
        Routes.loading,
        Routes.progress,
        Routes.start,
        Routes.addChild,
        Routes.addChildProfile,
        Routes.privacy,
        '/devices/setup',
        '/live/s1',
      ]) {
        expect(
          redirect(AuthState.signedOut, location),
          Routes.signIn,
          reason: location,
        );
      }
    });

    test('a path that only starts like sign-in is not sign-in', () {
      expect(redirect(AuthState.signedOut, '/sign-inside'), Routes.signIn);
    });
  });

  group('signed in', () {
    test('leaving /loading or sign-in goes home, or to /start', () {
      expect(redirect(AuthState.signedIn, Routes.loading), Routes.progress);
      expect(redirect(AuthState.signedIn, Routes.signInCode), Routes.progress);
      expect(
        redirect(AuthState.signedIn, Routes.signIn, hasChildren: false),
        Routes.start,
      );
      expect(
        redirect(
          AuthState.signedIn,
          Routes.loading,
          hasChildren: false,
          startDismissed: true,
        ),
        Routes.progress,
      );
    });

    test('nothing about a child is asked before the consent', () {
      expect(
        redirect(AuthState.signedIn, Routes.addChildProfile),
        Routes.addChild,
      );
      expect(
        redirect(
          AuthState.signedIn,
          Routes.addChildProfile,
          hasConsentDraft: true,
        ),
        isNull,
      );
      expect(redirect(AuthState.signedIn, Routes.addChild), isNull);
    });

    test('every other screen stays', () {
      for (final location in <String>[
        Routes.progress,
        Routes.notices,
        Routes.family,
        Routes.privacy,
        Routes.start,
        '/add-child/done',
        '/devices/setup',
        '/live/s1',
      ]) {
        expect(
          redirect(AuthState.signedIn, location),
          isNull,
          reason: location,
        );
      }
    });
  });

  test('route helpers', () {
    expect(Routes.addChildDone('c1'), '/add-child/done?child=c1');
    expect(Routes.sessionDetail('c1', 's1'), '/progress/child/c1/session/s1');
    expect(Routes.memories('c1'), '/privacy/child/c1/memories');
    expect(Routes.deviceSetup(), '/devices/setup');
    expect(Routes.deviceSetup(childId: 'c1'), '/devices/setup?child=c1');
    expect(Routes.live('s1', childId: 'c1'), '/live/s1?child=c1');
  });
}

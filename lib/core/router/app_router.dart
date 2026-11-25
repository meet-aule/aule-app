import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/code_screen.dart';
import '../../features/auth/email_help_screen.dart';
import '../../features/auth/email_screen.dart';
import '../../features/auth/loading_screen.dart';
import '../../features/auth/name_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/children/add_child_done_screen.dart';
import '../../features/children/add_child_profile_screen.dart';
import '../../features/children/edit_child_screen.dart';
import '../../features/children/family_screen.dart';
import '../../features/consent/add_child_flow.dart';
import '../../features/consent/consent_screen.dart';
import '../../features/consent/start_screen.dart';
import '../../features/device/device_module.dart';
import '../../features/live/live_module.dart';
import '../../features/privacy/child_privacy_screen.dart';
import '../../features/privacy/delete_account_screen.dart';
import '../../features/privacy/memories_screen.dart';
import '../../features/privacy/privacy_screen.dart';
import '../../features/progress/child_progress_screen.dart';
import '../../features/progress/notice_screen.dart';
import '../../features/progress/notices_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/progress/session_detail_screen.dart';
import '../auth/auth_controller.dart';
import '../l10n/l10n.dart';
import '../widgets/aule_page.dart';
import '../widgets/buttons.dart';
import 'home_shell.dart';
import 'routes.dart';

/// Where the app must go before it shows [location] (§3.2), or null to stay.
String? authRedirect({
  required AuthState state,
  required bool hasChildren,
  required bool startDismissed,
  required bool hasConsentDraft,
  required String location, // GoRouterState.matchedLocation, no query
}) {
  final inSignIn =
      location == Routes.signIn || location.startsWith('${Routes.signIn}/');
  switch (state) {
    case AuthState.unknown:
      return location == Routes.loading ? null : Routes.loading;
    case AuthState.signedOut:
      return inSignIn ? null : Routes.signIn;
    case AuthState.signedIn:
      if (location == Routes.loading || inSignIn) {
        return hasChildren || startDismissed ? Routes.progress : Routes.start;
      }
      // Nothing about a child is asked before the parent's consent.
      if (location == Routes.addChildProfile && !hasConsentDraft) {
        return Routes.addChild;
      }
      return null;
  }
}

/// The app's one router (§6.5). It listens to the session and to the
/// consent draft, so the redirect rules run whenever either changes.
GoRouter buildAppRouter({
  required AuthController auth,
  required AddChildFlow addChildFlow,
}) {
  return GoRouter(
    initialLocation: Routes.loading,
    refreshListenable: Listenable.merge(<Listenable>[auth, addChildFlow]),
    redirect: (context, state) => authRedirect(
      state: auth.state,
      hasChildren: auth.children.isNotEmpty,
      startDismissed: auth.startDismissed,
      hasConsentDraft: addChildFlow.hasConsent,
      location: state.matchedLocation,
    ),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'email',
            builder: (context, state) => const EmailScreen(),
          ),
          GoRoute(
            path: 'code',
            builder: (context, state) => const CodeScreen(),
          ),
          GoRoute(
            path: 'name',
            builder: (context, state) => const NameScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const EmailHelpScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.start,
        builder: (context, state) => const StartScreen(),
      ),
      // Listed before '/add-child' and kept out of its stack, so the done
      // screen never sits on top of the consent screen.
      GoRoute(
        path: '/add-child/done',
        builder: (context, state) => AddChildDoneScreen(
          childId: state.uri.queryParameters['child'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.addChild,
        builder: (context, state) => const ConsentScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'profile',
            builder: (context, state) => const AddChildProfileScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.progress,
                builder: (context, state) => const ProgressScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'notices',
                    builder: (context, state) => const NoticesScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':noticeId',
                        builder: (context, state) => NoticeScreen(
                          noticeId: state.pathParameters['noticeId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'child/:childId',
                    builder: (context, state) => ChildProgressScreen(
                      childId: state.pathParameters['childId']!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'session/:sessionId',
                        builder: (context, state) => SessionDetailScreen(
                          childId: state.pathParameters['childId']!,
                          sessionId: state.pathParameters['sessionId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.family,
                builder: (context, state) => const FamilyScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'child/:childId',
                    builder: (context, state) => EditChildScreen(
                      childId: state.pathParameters['childId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.privacy,
                builder: (context, state) => const PrivacyScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'child/:childId',
                    builder: (context, state) => ChildPrivacyScreen(
                      childId: state.pathParameters['childId']!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'memories',
                        builder: (context, state) => MemoriesScreen(
                          childId: state.pathParameters['childId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'account/delete',
                    builder: (context, state) => const DeleteAccountScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ...deviceRoutes(),
      ...liveRoutes(),
    ],
  );
}

/// What an unknown link shows: errorNotFound and a way back to Progress.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AulePage(
      title: l10n.errorNotFound,
      showBack: false,
      footer: <Widget>[
        PrimaryButton(
          label: l10n.commonBack,
          onPressed: () => context.go(Routes.progress),
        ),
      ],
    );
  }
}

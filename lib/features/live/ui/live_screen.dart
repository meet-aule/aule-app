import 'dart:async';

import 'package:aule/core/api/aule_api.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/core/theme/aule_colors.dart';
import 'package:aule/core/widgets/aule_page.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/cards.dart';
import 'package:aule/core/widgets/error_text.dart';
import 'package:aule/core/widgets/snack.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:aule/features/progress/progress_store.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../connection/live_connection.dart';
import '../data/live_api.dart';
import 'live_session_controller.dart';
import 'step_in_sheet.dart';

/// /live/:sessionId: listening in, or stepping in as a human tutor (§4.9).
/// It addresses the adult only. However the route is reached, it shows the
/// disclosure first and joins only once the adult confirmed it (§9.2).
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.sessionId, required this.childId});

  final String sessionId;
  final String childId;

  @override
  Widget build(BuildContext context) {
    final child = _childOf(childId, context.read<AuthController>().children);
    // A child who is not in this family has no session to join.
    if (child == null) return const _GonePage();
    final config = context.read<AppConfig>();
    return ChangeNotifierProvider<LiveSessionController>(
      create: (context) {
        final progress = context.read<ProgressStore>();
        return LiveSessionController(
          sessionId: sessionId,
          live: context.read<LiveApi>(),
          connector: context.read<LiveConnector>(),
          api: context.read<AuleApi>(),
          enabled: config.flags.liveJoin,
          platform: context.read<LivePlatform>(),
          onEnded: progress.refresh,
        );
      },
      child: _LiveView(nickname: child.nickname),
    );
  }

  static ChildRef? _childOf(String id, List<ChildRef> children) {
    for (final child in children) {
      if (child.id == id) return child;
    }
    return null;
  }
}

/// Leaves the live route, to where it was opened from.
void _close(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.progress);
  }
}

class _GonePage extends StatelessWidget {
  const _GonePage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AulePage(
      title: l10n.errorNotFound,
      onBack: () => _close(context),
      footer: [
        PrimaryButton(label: l10n.commonBack, onPressed: () => _close(context)),
      ],
    );
  }
}

class _LiveView extends StatefulWidget {
  const _LiveView({required this.nickname});

  final String nickname;

  @override
  State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  late final AppLifecycleListener _lifecycle;
  bool _leaving = false;

  /// The adult read the disclosure and chose to join.
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    // v0 has no background audio: leaving the app leaves the room, so the
    // child hears that the adult left (§9.2).
    _lifecycle = AppLifecycleListener(
      onHide: _onBackground,
      onPause: _onBackground,
    );
  }

  /// "Entrar a escuchar", after the disclosure.
  void _join() {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    // start() notifies only after its first await.
    unawaited(context.read<LiveSessionController>().start());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onBackground() {
    if (!mounted || !_confirmed) return;
    if (context.read<LiveSessionController>().isLive) _leave();
  }

  /// "Salir", "← Atrás", Android back, or the app going to the background.
  void _leave() {
    if (_leaving || !mounted) return;
    final live = context.read<LiveSessionController>();
    _leaving = true;
    if (_confirmed && live.isLive) {
      showNotice(context, context.l10n.liveLeft);
      unawaited(live.leave());
    }
    _close(context);
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();
    // While live, back means leaving the room first; after that, and before
    // joining, it is an ordinary back.
    return PopScope<Object?>(
      canPop: !_confirmed || !live.isLive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _page(context, live),
    );
  }

  Widget _page(BuildContext context, LiveSessionController live) {
    final l10n = context.l10n;
    final nickname = widget.nickname;
    if (!_confirmed && live.phase == LivePhase.connecting) {
      // The disclosure (§9.2): the child is told, out loud and on their
      // screen, and the microphone stays off.
      return AulePage(
        title: l10n.liveJoinTitle(nickname),
        help: l10n.liveJoinBody(nickname),
        onBack: () => _close(context),
        footer: [
          PrimaryButton(label: l10n.liveJoinConfirm, onPressed: _join),
          Center(
            child: LinkButton(
              label: l10n.commonCancel,
              onPressed: () => _close(context),
            ),
          ),
        ],
      );
    }
    switch (live.phase) {
      case LivePhase.soon:
        return _closing(
          title: l10n.liveSoonTitle,
          help: l10n.liveSoonHelp(nickname),
        );
      case LivePhase.connecting:
        return AulePage(
          title: l10n.liveConnecting,
          onBack: _leave,
          children: const [LoadingView()],
        );
      case LivePhase.listening:
        return AulePage(
          step: l10n.liveListening,
          title: nickname,
          help: l10n.liveKnows(nickname),
          onBack: _leave,
          footer: [
            PrimaryButton(
              label: l10n.liveStepIn,
              busy: live.stepping,
              onPressed: live.canStepIn ? () => _stepIn(live) : null,
            ),
            SmallButton(label: l10n.liveLeave, onPressed: _leave),
            Text(
              l10n.liveLeaveNote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            LinkButton(
              label: l10n.liveEnd,
              danger: true,
              onPressed: live.ending ? null : () => _end(live),
            ),
          ],
          children: _lines(context, live),
        );
      case LivePhase.talking:
        return AulePage(
          step: l10n.liveTalking(nickname),
          title: nickname,
          onBack: _leave,
          footer: [
            SmallButton(
              label: live.microphoneOn ? l10n.liveMute : l10n.liveUnmute,
              onPressed: () => _toggleMute(live),
            ),
            PrimaryButton(
              label: l10n.liveHandBack,
              onPressed: () => _handBack(live),
            ),
            SmallButton(label: l10n.liveLeave, onPressed: _leave),
            LinkButton(
              label: l10n.liveEnd,
              danger: true,
              onPressed: live.ending ? null : () => _end(live),
            ),
          ],
          children: _lines(context, live),
        );
      case LivePhase.ended:
        return _closing(title: l10n.liveEndedTitle, help: l10n.liveEndedHelp);
      case LivePhase.failed:
        return _closing(title: _failureText(context, live));
      case LivePhase.removed:
        return _closing(
          title: live.replaced ? l10n.liveReplaced : l10n.liveRemoved,
        );
      case LivePhase.left:
        return _closing(title: l10n.liveLeft);
    }
  }

  /// The speaker, the time left and who else is there.
  List<Widget> _lines(BuildContext context, LiveSessionController live) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final minutes = live.minutesLeft;
    final speaker = switch (live.speaker) {
      LiveSpeaker.child => l10n.liveSpeakerChild(widget.nickname),
      LiveSpeaker.tutor => l10n.liveSpeakerTutor,
      LiveSpeaker.me => l10n.liveSpeakerMe,
      LiveSpeaker.otherAdult || null => l10n.liveSpeakerQuiet,
    };
    return [
      if (live.handBackPending)
        AuleCard(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(l10n.liveHandBackFailed, style: text.bodyLarge),
              ),
              const SizedBox(height: AuleSpace.s),
              SmallButton(
                label: l10n.commonRetry,
                onPressed: () => unawaited(live.retryHandBack()),
              ),
            ],
          ),
        ),
      if (live.reconnecting)
        AuleCard(
          accent: true,
          child: Text(l10n.liveReconnecting, style: text.bodyLarge),
        ),
      Text(speaker, style: text.titleMedium),
      if (minutes != null)
        Text(l10n.liveTimeLeft(minutes), style: text.bodyMedium),
      if (live.otherAdult) Text(l10n.liveOtherAdult, style: text.bodyMedium),
    ];
  }

  /// A state the screen only leaves, with "Atrás".
  Widget _closing({required String title, String? help}) {
    final l10n = context.l10n;
    return AulePage(
      title: title,
      help: help,
      onBack: () => _close(context),
      footer: [
        PrimaryButton(label: l10n.commonBack, onPressed: () => _close(context)),
      ],
    );
  }

  String _failureText(BuildContext context, LiveSessionController live) {
    final l10n = context.l10n;
    return switch (live.failure) {
      LiveFailure.notActive => l10n.liveNotActive,
      LiveFailure.busy => l10n.liveBusy,
      LiveFailure.noVoice => l10n.liveNoVoice(widget.nickname),
      LiveFailure.notFound => l10n.errorNotFound,
      LiveFailure.error || null => errorText(context, live.error ?? Object()),
    };
  }

  Future<void> _stepIn(LiveSessionController live) async {
    final nickname = widget.nickname;
    final confirmed = await showStepInSheet(context, nickname: nickname);
    if (!confirmed || !mounted) return;
    final result = await live.stepIn();
    if (!mounted) return;
    switch (result) {
      case StepInResult.micDenied:
        final settings = await showMicDeniedSheet(context, nickname: nickname);
        if (settings) await openAppSettings();
      case StepInResult.failed:
        showNotice(context, context.l10n.liveStepInFailed);
      case StepInResult.talking || StepInResult.ignored:
        break;
    }
  }

  Future<void> _toggleMute(LiveSessionController live) async {
    try {
      await live.setMuted(live.microphoneOn);
    } on Object catch (error) {
      if (mounted) showNotice(context, errorText(context, error));
    }
  }

  Future<void> _handBack(LiveSessionController live) async {
    try {
      await live.handBack();
    } on Object catch (error) {
      if (mounted) showNotice(context, errorText(context, error));
    }
  }

  Future<void> _end(LiveSessionController live) async {
    final confirmed = await showEndSheet(context, nickname: widget.nickname);
    if (!confirmed || !mounted) return;
    try {
      await live.end();
    } on Object catch (error) {
      if (mounted) showNotice(context, errorText(context, error));
    }
  }
}

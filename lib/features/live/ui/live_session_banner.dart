import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/core/theme/aule_colors.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/cards.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// A child's session going on now (§4.9). B1 shows one per live session.
class LiveSessionBanner extends StatelessWidget {
  const LiveSessionBanner({
    super.key,
    required this.sessionId,
    required this.childId,
    required this.nickname,
    required this.onDevice,
  });

  final String sessionId;
  final String childId;
  final String nickname;
  final bool onDevice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final canJoin = context.read<AppConfig>().flags.liveJoin;
    return AuleCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.liveBannerTitle(nickname), style: text.titleMedium),
          const SizedBox(height: AuleSpace.s),
          if (onDevice)
            // Device sessions have no room yet (§9.1).
            Text(l10n.liveBannerDevice, style: text.bodySmall)
          else if (!canJoin)
            Text(l10n.liveBannerSoon, style: text.bodySmall)
          else
            SmallButton(
              label: l10n.liveBannerListen,
              onPressed: () => _listen(context),
            ),
        ],
      ),
    );
  }

  /// The live screen shows the disclosure before it joins (§9.2).
  Future<void> _listen(BuildContext context) async {
    await context.push<void>(Routes.live(sessionId, childId: childId));
  }
}

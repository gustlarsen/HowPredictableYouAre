import 'package:flutter/material.dart';
import '../../services/ad_service.dart';
import '../../theme/app_theme.dart';

/// An adaptive pill-styled Rewarded Ad button for the top AppBar and navigation bars.
///
/// Uses [LayoutBuilder] to observe available horizontal width:
/// - When horizontal space is ample (>= [compactBreakpoint]): renders the full
///   readable pill label ("Watch Ad +50 Orbs" or custom [label]) at normal font size.
/// - When horizontal space is tight (< [compactBreakpoint]): automatically switches
///   to a compact pill featuring a clear video icon ([Icons.ondemand_video_rounded])
///   paired with "+50", preserving the dark/amber or light parchment/bronze pill
///   styling and full AdMob disclosure tooltip.
class AdaptiveRewardedAdButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final String label;
  final double compactBreakpoint;
  final double? maxWidth;

  const AdaptiveRewardedAdButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Watch a video ad for +50 of each Elemental Orb',
    this.label = AdService.rewardedAdButtonLabel,
    this.compactBreakpoint = 135.0,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = maxWidth ?? constraints.maxWidth;
        final isCompact = effectiveWidth < compactBreakpoint;

        return Tooltip(
          message: tooltip,
          child: InkWell(
            key: const ValueKey('watch_rewarded_ad_button'),
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: palette.isDark
                    ? const Color(0xFF151821).withValues(alpha: 0.90)
                    : palette.dialogSurface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.amberBorder.withValues(
                    alpha: palette.isDark ? 0.55 : 0.85,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.amberBorder.withValues(
                      alpha: palette.isDark ? 0.15 : 0.22,
                    ),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: isCompact
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ondemand_video_rounded,
                          size: 16,
                          color: palette.amberText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+50',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: palette.amberText,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        color: palette.amberText,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

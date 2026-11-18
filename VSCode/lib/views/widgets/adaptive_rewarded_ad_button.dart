import 'package:flutter/material.dart';
import '../../services/ad_service.dart';

/// An adaptive pill-styled Rewarded Ad button for the top AppBar and navigation bars.
///
/// Uses [LayoutBuilder] to observe available horizontal width:
/// - When horizontal space is ample (>= [compactBreakpoint]): renders the full
///   readable pill label ("Watch Ad +50 Orbs" or custom [label]) at normal font size.
/// - When horizontal space is tight (< [compactBreakpoint]): automatically switches
///   to a compact pill featuring a clear video icon ([Icons.ondemand_video_rounded])
///   paired with "+50", preserving the dark/amber pill styling and full AdMob disclosure tooltip.
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
                color: const Color(0xFF151821).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: isCompact
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ondemand_video_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '+50',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        color: Colors.amber,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../models/move.dart';

/// Unified theme-aware color palette for Light Mode (warm parchment &
/// amber-bronze) and Dark Mode (deep obsidian & bright amber).
class AppPalette {
  final bool isDark;

  const AppPalette({required this.isDark});

  factory AppPalette.of(BuildContext context) {
    return AppPalette(isDark: Theme.of(context).brightness == Brightness.dark);
  }

  // Dialog & Card Surfaces
  Color get dialogSurface =>
      isDark ? const Color(0xFF14161D) : const Color(0xFFFAF6EE);

  Color get dialogCardSurface =>
      isDark ? const Color(0xFF1C202B) : const Color(0xFFF5EFE2);

  Color get summaryBarSurface =>
      isDark ? const Color(0xFF151821) : const Color(0xFFE8DEC8);

  Color get sandCardSurface =>
      isDark ? const Color(0xFF1C202B) : const Color(0xFFEAE2D3);

  Color get sandCardBorder =>
      isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFD5C9B4);

  Color get shopTileSurface =>
      isDark ? const Color(0xFF1F222B) : const Color(0xFFF0E9DA);

  Color get rewardedAdCardSurface =>
      isDark ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFFE6DEC8);

  Color get rewardedAdCardBorder =>
      isDark ? Colors.amber.withValues(alpha: 0.35) : const Color(0xFFC8961E);

  Color get arenaSurface => isDark
      ? const Color(0xFF16181D).withValues(alpha: 0.85)
      : const Color(0xFFFAF6EE).withValues(alpha: 0.94);

  Color get deckSurface => isDark
      ? const Color(0xFF16181D).withValues(alpha: 0.94)
      : const Color(0xFFFAF6EE).withValues(alpha: 0.96);

  // Typography
  Color get primaryText =>
      isDark ? Colors.white : const Color(0xFF231F1A);

  Color get secondaryText =>
      isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF4A4238);

  Color get mutedText =>
      isDark ? Colors.grey.shade400 : const Color(0xFF5C4934);

  // Amber / Bronze Accent Tokens
  Color get amberText =>
      isDark ? Colors.amber : const Color(0xFF7A4E00);

  Color get amberSubtitle =>
      isDark
          ? Colors.amber.withValues(alpha: 0.85)
          : const Color(0xFF7A4E00);

  Color get amberIcon =>
      isDark ? Colors.amber : const Color(0xFF8A5A00);

  Color get amberBorder =>
      isDark ? Colors.amber : const Color(0xFFC8961E);

  Color get divider => isDark
      ? Colors.amber.withValues(alpha: 0.22)
      : const Color(0xFFC8961E).withValues(alpha: 0.28);

  // Semantic Accent Tokens
  Color get successText =>
      isDark ? Colors.greenAccent : const Color(0xFF1B6E36);

  Color get successIcon =>
      isDark ? Colors.green : const Color(0xFF1B6E36);

  Color get dangerText =>
      isDark ? Colors.redAccent : const Color(0xFFC62828);

  Color get blueAccent =>
      isDark ? Colors.blueAccent : const Color(0xFF1558B0);

  Color get orangeAccent =>
      isDark ? Colors.orangeAccent : const Color(0xFFB84A00);

  Color get purpleAccent =>
      isDark ? Colors.purpleAccent : const Color(0xFF6A1B9A);

  // Action Deck Recommendation Highlight Tokens (Suggestion & Crystal Ball+)
  Color get suggestionHighlightPrimary =>
      isDark ? const Color(0xFFFFD54F) : const Color(0xFFC88A00);

  Color get suggestionHighlightSecondary =>
      isDark ? const Color(0xFFF5C22B) : const Color(0xFF8A5A00);

  Color get crystalBallPlusHighlightPrimary =>
      isDark ? const Color(0xFF9C27B0) : const Color(0xFF8E24AA);

  Color get crystalBallPlusHighlightSecondary =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

  // Elemental Foreground & Card Tint Tokens (crisp contrast on light surfaces)
  Color elementalText(HandMove move) {
    if (isDark) {
      return move == HandMove.lizard
          ? const Color(0xFFD68C45)
          : move.elementalPrimaryColor;
    }
    switch (move) {
      case HandMove.rock:
        return const Color(0xFFC63B0E);
      case HandMove.paper:
        return const Color(0xFF01639E);
      case HandMove.scissors:
        return const Color(0xFF1B6E36);
      case HandMove.lizard:
        return const Color(0xFF6E3D14);
      case HandMove.spock:
        return const Color(0xFF435660);
    }
  }

  Color elementalCardBackground(HandMove move, {bool locked = false}) {
    if (isDark) {
      return const Color(0xFF1C202B).withValues(alpha: locked ? 0.65 : 0.92);
    }
    final Color base;
    switch (move) {
      case HandMove.rock:
        base = const Color(0xFFFAE8E2);
      case HandMove.paper:
        base = const Color(0xFFE4F2FA);
      case HandMove.scissors:
        base = const Color(0xFFE5F4EA);
      case HandMove.lizard:
        base = const Color(0xFFF2E3D4);
      case HandMove.spock:
        base = const Color(0xFFE9EEF2);
    }
    return locked
        ? Color.lerp(base, const Color(0xFFEDE6D6), 0.35)!
        : base;
  }

  Color elementalCardBorder(HandMove move, {bool locked = false}) {
    if (isDark) {
      return move.elementalPrimaryColor.withValues(alpha: locked ? 0.28 : 0.52);
    }
    return elementalText(move).withValues(alpha: locked ? 0.32 : 0.55);
  }
}

/// Shared fixed modal dimensions for hub dialogs so both
/// `RoyalCastleDialog` and `SacredTempleDialog` (`ShopDialog`) occupy the
/// exact same screen coordinates across every wing/tab and viewport size.
abstract final class HubModalSizing {
  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: 14.0,
    vertical: 14.0,
  );
  static const double maxWidth = 460.0;
  static const double minFixedHeight = 480.0;
  static const double maxFixedHeight = 760.0;
  static const double viewportHeightFraction = 0.84;

  /// Computes the strict fixed modal height clamped safely within the
  /// available viewport height minus [insetPadding] and any [viewInsets].
  static double fixedHeightFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final availableHeight =
        (size.height - insetPadding.vertical - viewInsets.vertical)
            .clamp(0.0, double.infinity);
    final targetHeight = (size.height * viewportHeightFraction).clamp(
      minFixedHeight,
      maxFixedHeight,
    );
    return targetHeight <= availableHeight ? targetHeight : availableHeight;
  }
}


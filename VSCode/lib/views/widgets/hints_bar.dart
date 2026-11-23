import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../theme/app_theme.dart';
import 'elemental_symbol_icon.dart';

enum HintMiniIconType {
  brain,
  robot,
  lightbulb,
  crystalBall,
}

class HintsBar extends StatelessWidget {
  final GameController controller;

  const HintsBar({super.key, required this.controller});

  static const Color darkCapsuleFill = Color(0xFF1A1E26);
  static const Color goldAmberBorder = Color(0xFF8A6D3B);
  static const Color warmCreamLabel = Color(0xFFD9C398);
  static const Color warmGoldValue = Color(0xFFF3E2B8);

  String _formatMoves(List<HandMove> moves, {required int poolSize}) {
    if (moves.isEmpty || (poolSize > 1 && moves.length >= poolSize)) {
      return '?';
    }
    return moves.map((m) => m.emoji).join(' ');
  }

  List<HandMove> _visibleMoves(List<HandMove> moves, {required int poolSize}) {
    if (moves.isEmpty || (poolSize > 1 && moves.length >= poolSize)) {
      return const [];
    }
    return moves;
  }

  Widget _buildRow(List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final elemental = controller.isElementalMode;
    final playerPoolSize = controller.engine.size;
    final enemyPoolSize = controller.engine.enemySize;

    final topChips = <Widget>[
      if (controller.showYourPrediction)
        _HintChip(
          iconType: HintMiniIconType.brain,
          label: loc.t('string12', fallback: 'Your Choice:'),
          value: _formatMoves(
            controller.predictedUserMoves,
            poolSize: playerPoolSize,
          ),
          moves: _visibleMoves(
            controller.predictedUserMoves,
            poolSize: playerPoolSize,
          ),
          elementalMode: elemental,
          color: palette.blueAccent,
        ),
      if (controller.showNextMove)
        _HintChip(
          iconType: HintMiniIconType.robot,
          label: loc.t('string13', fallback: 'PC\'s Choice:'),
          value: _formatMoves(
            controller.pcNextMoves,
            poolSize: enemyPoolSize,
          ),
          moves: _visibleMoves(
            controller.pcNextMoves,
            poolSize: enemyPoolSize,
          ),
          elementalMode: elemental,
          color: palette.orangeAccent,
        ),
    ];

    final bottomChips = <Widget>[
      if (controller.showSuggestion)
        _HintChip(
          iconType: HintMiniIconType.lightbulb,
          label: loc.t('string14', fallback: 'Suggestion:'),
          value: _formatMoves(
            controller.suggestedMoves,
            poolSize: playerPoolSize,
          ),
          moves: _visibleMoves(
            controller.suggestedMoves,
            poolSize: playerPoolSize,
          ),
          elementalMode: elemental,
          color: palette.successText,
        ),
      if (controller.showCrystalBall &&
          controller.showCrystalBallPlus &&
          controller.crystalBallPlusMoves.isNotEmpty)
        _HintChip(
          iconType: HintMiniIconType.crystalBall,
          label: loc.t('string83', fallback: 'Crystal Ball+:'),
          value: controller.crystalBallPlusMoves
              .map((m) => m.emoji)
              .join(' '),
          moves: controller.crystalBallPlusMoves,
          elementalMode: elemental,
          color: palette.purpleAccent,
        )
      else if (controller.showCrystalBall &&
          controller.crystalBallMoves.isNotEmpty)
        _HintChip(
          iconType: HintMiniIconType.crystalBall,
          label: loc.t('string81', fallback: 'Crystal Ball:'),
          value: controller.crystalBallMoves.map((m) => m.emoji).join(' '),
          moves: controller.crystalBallMoves,
          elementalMode: elemental,
          color: palette.purpleAccent,
        ),
    ];

    if (topChips.isEmpty && bottomChips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topChips.isNotEmpty) _buildRow(topChips),
          if (topChips.isNotEmpty && bottomChips.isNotEmpty)
            const SizedBox(height: 6),
          if (bottomChips.isNotEmpty) _buildRow(bottomChips),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  static const double pillHeight = 34.0;
  static const double iconSlotSize = 16.0;

  final HintMiniIconType iconType;
  final String label;
  final String value;
  final List<HandMove> moves;
  final bool elementalMode;
  final Color color;

  const _HintChip({
    required this.iconType,
    required this.label,
    required this.value,
    this.moves = const [],
    this.elementalMode = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final backgroundColor = palette.isDark
        ? HintsBar.darkCapsuleFill.withValues(alpha: 0.92)
        : const Color(0xFFFAF6EE).withValues(alpha: 0.95);
    final borderColor = palette.isDark
        ? HintsBar.goldAmberBorder
        : const Color(0xFFB5945B);
    final labelColor = palette.isDark
        ? HintsBar.warmCreamLabel
        : palette.secondaryText;
    final valueColor = palette.isDark ? HintsBar.warmGoldValue : color;

    return SizedBox(
      height: pillHeight,
      child: Container(
        height: pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: palette.isDark ? 0.35 : 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: iconSlotSize,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconSlotSize,
                    height: iconSlotSize,
                    child: Center(
                      child: HintMiniIcon(
                        type: iconType,
                        size: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (elementalMode && moves.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int i = 0; i < moves.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          SizedBox(
                            width: iconSlotSize,
                            height: iconSlotSize,
                            child: Center(
                              child: ElementalSymbolIcon(
                                move: moves[i],
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (value == '?')
                    SizedBox(
                      width: iconSlotSize,
                      height: iconSlotSize,
                      child: Center(
                        child: Text(
                          '?',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: iconSlotSize,
                      child: Center(
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HintMiniIcon extends StatelessWidget {
  final HintMiniIconType type;
  final double size;

  const HintMiniIcon({
    super.key,
    required this.type,
    this.size = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey('hint_mini_icon_${type.name}'),
      size: Size.square(size),
      painter: _HintMiniIconPainter(type: type),
    );
  }
}

class _HintMiniIconPainter extends CustomPainter {
  final HintMiniIconType type;

  const _HintMiniIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case HintMiniIconType.brain:
        _paintBrain(canvas, size);
        break;
      case HintMiniIconType.robot:
        _paintRobot(canvas, size);
        break;
      case HintMiniIconType.lightbulb:
        _paintLightbulb(canvas, size);
        break;
      case HintMiniIconType.crystalBall:
        _paintCrystalBall(canvas, size);
        break;
    }
  }

  void _paintBrain(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8BBD0), Color(0xFFF06292), Color(0xFFC2185B)],
      ).createShader(Offset.zero & size);
    final strokePaint = Paint()
      ..color = const Color(0xFF880E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    // Left and right cerebral hemispheres with overlapping lobes
    final leftPath = Path()
      ..moveTo(w * 0.48, h * 0.20)
      ..cubicTo(w * 0.22, h * 0.14, w * 0.08, h * 0.34, w * 0.14, h * 0.50)
      ..cubicTo(w * 0.06, h * 0.64, w * 0.18, h * 0.86, w * 0.48, h * 0.82)
      ..close();
    final rightPath = Path()
      ..moveTo(w * 0.52, h * 0.20)
      ..cubicTo(w * 0.78, h * 0.14, w * 0.92, h * 0.34, w * 0.86, h * 0.50)
      ..cubicTo(w * 0.94, h * 0.64, w * 0.82, h * 0.86, w * 0.52, h * 0.82)
      ..close();

    canvas.drawPath(leftPath, fillPaint);
    canvas.drawPath(rightPath, fillPaint);
    canvas.drawPath(leftPath, strokePaint);
    canvas.drawPath(rightPath, strokePaint);

    // Inner folds (sulci)
    final foldPaint = Paint()
      ..color = const Color(0xFFFCE4EC).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.20, h * 0.30, w * 0.22, h * 0.20),
      0.3,
      2.4,
      false,
      foldPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.58, h * 0.30, w * 0.22, h * 0.20),
      0.4,
      2.4,
      false,
      foldPaint,
    );
  }

  void _paintRobot(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final metalPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB0BEC5), Color(0xFF607D8B), Color(0xFF37474F)],
      ).createShader(Offset.zero & size);
    final outlinePaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // Antenna
    canvas.drawLine(
      Offset(w * 0.5, h * 0.08),
      Offset(w * 0.5, h * 0.24),
      outlinePaint..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.08),
      w * 0.08,
      Paint()..color = const Color(0xFF4FC3F7),
    );

    // Side ear bolts
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.42, w * 0.12, h * 0.24),
        const Radius.circular(1.5),
      ),
      metalPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.80, h * 0.42, w * 0.12, h * 0.24),
        const Radius.circular(1.5),
      ),
      metalPaint,
    );

    // Head chassis
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.24, w * 0.64, h * 0.62),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(headRect, metalPaint);
    canvas.drawRRect(headRect, outlinePaint);

    // Glowing cyan eyes
    final eyePaint = Paint()..color = const Color(0xFF40C4FF);
    canvas.drawCircle(Offset(w * 0.36, h * 0.48), w * 0.08, eyePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.48), w * 0.08, eyePaint);

    // Mouth grille
    canvas.drawLine(
      Offset(w * 0.34, h * 0.69),
      Offset(w * 0.66, h * 0.69),
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLightbulb(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer warm radial glow
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.46,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Glass bulb
    final bulbPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.25),
        radius: 0.75,
        colors: [Color(0xFFFFF9C4), Color(0xFFFFCA28), Color(0xFFFF8F00)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.40), radius: w * 0.32));

    canvas.drawCircle(Offset(w * 0.5, h * 0.40), w * 0.30, bulbPaint);

    // Base neck
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.66, w * 0.30, h * 0.22),
      const Radius.circular(1.8),
    );
    canvas.drawRRect(
      baseRect,
      Paint()..color = const Color(0xFFB0BEC5),
    );
    canvas.drawLine(
      Offset(w * 0.36, h * 0.75),
      Offset(w * 0.64, h * 0.75),
      Paint()
        ..color = const Color(0xFF546E7A)
        ..strokeWidth = 1.0,
    );
  }

  void _paintCrystalBall(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Golden pedestal base
    final basePath = Path()
      ..moveTo(w * 0.26, h * 0.88)
      ..lineTo(w * 0.74, h * 0.88)
      ..lineTo(w * 0.64, h * 0.70)
      ..lineTo(w * 0.36, h * 0.70)
      ..close();
    canvas.drawPath(
      basePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFB8860B)],
        ).createShader(Rect.fromLTWH(w * 0.25, h * 0.70, w * 0.50, h * 0.20)),
    );

    // Mystical purple crystal sphere
    final orbCenter = Offset(w * 0.5, h * 0.44);
    final orbRadius = w * 0.33;
    final orbPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: [
          Color(0xFFF3E5F5),
          Color(0xFFBA68C8),
          Color(0xFF6A1B9A),
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius));
    canvas.drawCircle(orbCenter, orbRadius, orbPaint);

    // Specular highlight
    canvas.drawCircle(
      Offset(w * 0.39, h * 0.33),
      w * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _HintMiniIconPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

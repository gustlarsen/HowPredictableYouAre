import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import 'elemental_energy_sphere.dart';
import 'elemental_symbol_icon.dart';

/// Interactive elemental matchup diagram displaying either the 3-element
/// cycle (Fire, Wood, Water) or the 5-element Wu Xing cycle (Fire, Wood,
/// Water, Metal, Earth) with directional victory arrows derived from
/// [HandMove.beats].
class ElementalMatchupDiagram extends StatefulWidget {
  final LocalizationService localization;
  final bool initialFiveElements;

  const ElementalMatchupDiagram({
    super.key,
    required this.localization,
    this.initialFiveElements = false,
  });

  @override
  State<ElementalMatchupDiagram> createState() =>
      _ElementalMatchupDiagramState();
}

class _ElementalMatchupDiagramState extends State<ElementalMatchupDiagram> {
  static const List<HandMove> _threeElements = [
    HandMove.fire,
    HandMove.wood,
    HandMove.water,
  ];

  static const List<HandMove> _fiveElements = [
    HandMove.fire,
    HandMove.wood,
    HandMove.water,
    HandMove.metal,
    HandMove.earth,
  ];

  static const double _orbSize = 36.0;
  static const double _labelWidth = 72.0;
  static const double _labelHeight = 16.0;
  static const double _labelGap = 3.0;

  late bool _isFiveElements;
  HandMove? _selectedElement;

  @override
  void initState() {
    super.initState();
    _isFiveElements = widget.initialFiveElements;
  }

  @override
  void didUpdateWidget(covariant ElementalMatchupDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFiveElements != widget.initialFiveElements) {
      _isFiveElements = widget.initialFiveElements;
      if (!_isFiveElements &&
          (_selectedElement == HandMove.earth ||
              _selectedElement == HandMove.metal)) {
        _selectedElement = null;
      }
    }
  }

  List<HandMove> get _activeMoves =>
      _isFiveElements ? _fiveElements : _threeElements;

  void _setMode(bool fiveElements) {
    if (_isFiveElements == fiveElements) return;
    setState(() {
      _isFiveElements = fiveElements;
      if (!_isFiveElements &&
          (_selectedElement == HandMove.earth ||
              _selectedElement == HandMove.metal)) {
        _selectedElement = null;
      }
    });
  }

  void _toggleElement(HandMove move) {
    setState(() {
      _selectedElement = _selectedElement == move ? null : move;
    });
  }

  String _elementName(HandMove move) {
    final raw = move
        .displayLabel(elemental: true, localization: widget.localization)
        .trim();
    if (raw.isEmpty) return move.elementalLabel;
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String _buildMatchupSummary(HandMove selected, List<HandMove> activeMoves) {
    final loc = widget.localization;
    final conjunction = loc.t('help_matchup_conjunction', fallback: ' & ');
    final wins = activeMoves
        .where((other) => other != selected && selected.beats(other, elemental: true))
        .map(_elementName)
        .join(conjunction);
    final losses = activeMoves
        .where((other) => other != selected && other.beats(selected, elemental: true))
        .map(_elementName)
        .join(conjunction);

    final template = loc.t(
      'help_matchup_summary',
      fallback: '{element} defeats {wins} • Loses to {losses}',
    );
    return template
        .replaceAll('{element}', _elementName(selected))
        .replaceAll('{wins}', wins)
        .replaceAll('{losses}', losses);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final loc = widget.localization;
    final isDark = palette.isDark;
    final activeMoves = _activeMoves;

    final edges = <({HandMove from, HandMove to})>[
      for (final a in activeMoves)
        for (final b in activeMoves)
          if (a != b && a.beats(b, elemental: true)) (from: a, to: b),
    ];

    final winArrowColor =
        isDark ? const Color(0xFF00E676) : const Color(0xFF15803D);
    final winGlowColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFFD97706);
    final loseArrowColor =
        isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);
    final baseArrowColor = isDark
        ? Colors.amber.shade200
        : const Color(0xFF6B5335);

    return Container(
      key: const ValueKey('elemental_matchup_diagram'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E29) : palette.sandCardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.25)
              : palette.sandCardBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Mode Toggle Pill
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _ModeTogglePill(
                isFiveElements: _isFiveElements,
                label3: loc.t('help_mode_3_elements', fallback: '3 Elements'),
                label5: loc.t('help_mode_5_elements', fallback: '5 Elements'),
                palette: palette,
                onSelect: _setMode,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Responsive Polygon Diagram
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 260.0;
              final sinBound = _isFiveElements
                  ? math.sin(2 * math.pi / 5)
                  : math.sin(2 * math.pi / 3);
              final maxRadiusX = (width - (_labelWidth + 4.0)) / (2 * sinBound);
              final radius = maxRadiusX.clamp(
                54.0,
                _isFiveElements ? 82.0 : 74.0,
              );
              final centerX = width * 0.5;
              final centerY = radius + 24.0;
              final bottomFactor = _isFiveElements
                  ? math.cos(math.pi / 5)
                  : 0.5;
              final canvasHeight =
                  centerY +
                  radius * bottomFactor +
                  (_orbSize * 0.5) +
                  _labelGap +
                  _labelHeight +
                  4.0;

              final positions = <HandMove, Offset>{};
              for (int i = 0; i < activeMoves.length; i++) {
                final angle =
                    -math.pi / 2 + (2 * math.pi * i / activeMoves.length);
                positions[activeMoves[i]] = Offset(
                  centerX + radius * math.cos(angle),
                  centerY + radius * math.sin(angle),
                );
              }

              return SizedBox(
                width: width,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MatchupArrowsPainter(
                          positions: positions,
                          edges: edges,
                          selected: _selectedElement,
                          isFiveElements: _isFiveElements,
                          orbRadius: _orbSize * 0.5,
                          isDark: isDark,
                          baseColor: baseArrowColor,
                          winColor: winArrowColor,
                          winGlowColor: winGlowColor,
                          loseColor: loseArrowColor,
                        ),
                      ),
                    ),
                    for (final move in activeMoves)
                      _buildElementNode(
                        move: move,
                        center: positions[move]!,
                        palette: palette,
                        isSelected: _selectedElement == move,
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          // Readout / Tap Hint Footer
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedElement == null
                ? Row(
                    key: const ValueKey('matchup_hint_row'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 13.5,
                        color: palette.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          loc.t(
                            'help_tap_element_hint',
                            fallback: 'Tap an element to see matchups',
                          ),
                          key: const ValueKey('matchup_hint_text'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: ValueKey('matchup_readout_${_selectedElement!.orbKey}_$_isFiveElements'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.28)
                              : palette.dialogCardSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: palette.elementalCardBorder(
                              _selectedElement!,
                            ),
                          ),
                        ),
                        child: Text(
                          _buildMatchupSummary(_selectedElement!, activeMoves),
                          key: const ValueKey('matchup_summary_readout'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(
                            color: winArrowColor,
                            label: loc.t('help_legend_beats', fallback: 'Beats'),
                            textColor: palette.secondaryText,
                          ),
                          const SizedBox(width: 14),
                          _LegendDot(
                            color: loseArrowColor,
                            label: loc.t(
                              'help_legend_loses',
                              fallback: 'Loses to',
                            ),
                            textColor: palette.secondaryText,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementNode({
    required HandMove move,
    required Offset center,
    required AppPalette palette,
    required bool isSelected,
  }) {
    final primary = move.elementalPrimaryColor;
    final secondary = move.elementalSecondaryColor;
    final isDark = palette.isDark;
    final nodeWidth = _labelWidth;
    final nodeHeight = _orbSize + _labelGap + _labelHeight + 6;
    final left = center.dx - nodeWidth * 0.5;
    final top = center.dy - _orbSize * 0.5 - 3;

    return Positioned(
      left: left,
      top: top,
      width: nodeWidth,
      height: nodeHeight,
      child: GestureDetector(
        key: ValueKey('matchup_orb_${move.orbKey}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleElement(move),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _orbSize + 6,
              height: _orbSize + 6,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: isDark ? Colors.amberAccent : palette.amberBorder,
                        width: 2.2,
                      )
                    : Border.all(color: Colors.transparent, width: 2.2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: isDark ? 0.65 : 0.45),
                          blurRadius: 11,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: Colors.amber.withValues(
                            alpha: isDark ? 0.50 : 0.35,
                          ),
                          blurRadius: 7,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Container(
                width: _orbSize,
                height: _orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.28, -0.32),
                    radius: 0.90,
                    colors: [
                      Color.lerp(primary, Colors.white, 0.25)!,
                      secondary,
                    ],
                    stops: const [0.10, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.35 : 0.22),
                      blurRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ElementalEnergySphere(
                      size: _orbSize,
                      primaryColor: primary,
                      secondaryColor: secondary,
                      isDark: isDark,
                    ),
                    ElementalSymbolIcon(
                      move: move,
                      size: _orbSize * 0.56,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _labelGap - 3),
            SizedBox(
              width: _labelWidth,
              height: _labelHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _elementName(move),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected
                        ? (isDark ? Colors.amberAccent : palette.amberText)
                        : palette.elementalText(move),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTogglePill extends StatelessWidget {
  final bool isFiveElements;
  final String label3;
  final String label5;
  final AppPalette palette;
  final ValueChanged<bool> onSelect;

  const _ModeTogglePill({
    required this.isFiveElements,
    required this.label3,
    required this.label5,
    required this.palette,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = palette.isDark;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : palette.dialogCardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : palette.sandCardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            key: const ValueKey('matchup_mode_3_button'),
            label: label3,
            selected: !isFiveElements,
            palette: palette,
            onTap: () => onSelect(false),
          ),
          _SegmentButton(
            key: const ValueKey('matchup_mode_5_button'),
            label: label5,
            selected: isFiveElements,
            palette: palette,
            onTap: () => onSelect(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = palette.isDark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                    ? Colors.amber.withValues(alpha: 0.22)
                    : palette.rewardedAdCardSurface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(
                  color: palette.amberBorder.withValues(
                    alpha: isDark ? 0.65 : 0.85,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? palette.amberText : palette.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _MatchupArrowsPainter extends CustomPainter {
  final Map<HandMove, Offset> positions;
  final List<({HandMove from, HandMove to})> edges;
  final HandMove? selected;
  final bool isFiveElements;
  final double orbRadius;
  final bool isDark;
  final Color baseColor;
  final Color winColor;
  final Color winGlowColor;
  final Color loseColor;

  const _MatchupArrowsPainter({
    required this.positions,
    required this.edges,
    required this.selected,
    required this.isFiveElements,
    required this.orbRadius,
    required this.isDark,
    required this.baseColor,
    required this.winColor,
    required this.winGlowColor,
    required this.loseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final unrelated = <({HandMove from, HandMove to})>[];
    final losing = <({HandMove from, HandMove to})>[];
    final winning = <({HandMove from, HandMove to})>[];

    for (final edge in edges) {
      if (selected == null) {
        unrelated.add(edge);
      } else if (edge.from == selected) {
        winning.add(edge);
      } else if (edge.to == selected) {
        losing.add(edge);
      } else {
        unrelated.add(edge);
      }
    }

    final baseAlpha = selected == null
        ? (isFiveElements ? (isDark ? 0.24 : 0.28) : (isDark ? 0.65 : 0.72))
        : (isDark ? 0.10 : 0.12);
    final baseStroke = selected == null
        ? (isFiveElements ? 1.4 : 2.0)
        : 1.1;

    for (final edge in unrelated) {
      _drawArrow(
        canvas,
        edge.from,
        edge.to,
        color: baseColor.withValues(alpha: baseAlpha),
        strokeWidth: baseStroke,
        headLen: isFiveElements ? 6.5 : 7.8,
        headHalfW: isFiveElements ? 3.2 : 3.9,
      );
    }

    for (final edge in losing) {
      _drawArrow(
        canvas,
        edge.from,
        edge.to,
        color: loseColor.withValues(alpha: 0.92),
        glowColor: loseColor.withValues(alpha: isDark ? 0.26 : 0.18),
        strokeWidth: 2.3,
        headLen: 8.5,
        headHalfW: 4.3,
      );
    }

    for (final edge in winning) {
      _drawArrow(
        canvas,
        edge.from,
        edge.to,
        color: winColor,
        gradientStart: winGlowColor,
        glowColor: winGlowColor.withValues(alpha: isDark ? 0.28 : 0.20),
        strokeWidth: 2.7,
        headLen: 9.0,
        headHalfW: 4.5,
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    HandMove from,
    HandMove to, {
    required Color color,
    Color? gradientStart,
    Color? glowColor,
    required double strokeWidth,
    required double headLen,
    required double headHalfW,
  }) {
    final p1 = positions[from];
    final p2 = positions[to];
    if (p1 == null || p2 == null) return;

    final delta = p2 - p1;
    final dist = delta.distance;
    final trim = orbRadius + 5.5;
    if (dist <= trim * 2 + 4) return;

    final dir = delta / dist;
    final perp = Offset(-dir.dy, dir.dx);
    final start = p1 + dir * trim;
    final end = p2 - dir * trim;
    final shaftEnd = end - dir * (headLen * 0.72);
    final baseCenter = end - dir * headLen;

    if (glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor
        ..strokeWidth = strokeWidth + 3.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, shaftEnd, glowPaint);
    }

    final linePaint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (gradientStart != null) {
      linePaint.shader = LinearGradient(
        colors: [gradientStart, color],
      ).createShader(Rect.fromPoints(start, shaftEnd));
    } else {
      linePaint.color = color;
    }
    canvas.drawLine(start, shaftEnd, linePaint);

    final headPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(baseCenter.dx + perp.dx * headHalfW, baseCenter.dy + perp.dy * headHalfW)
      ..lineTo(baseCenter.dx - perp.dx * headHalfW, baseCenter.dy - perp.dy * headHalfW)
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MatchupArrowsPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.isFiveElements != isFiveElements ||
        oldDelegate.isDark != isDark ||
        oldDelegate.positions != positions;
  }
}

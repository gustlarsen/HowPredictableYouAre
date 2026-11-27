import 'dart:math' as math;

import 'package:flutter/material.dart';

/// High-level visual phase rendered inside the Metal Wizard's underground forge.
enum ForgeAssemblyPhase {
  /// Week 0: Metal Wizard enchanting the Titanium Robot Egg on an iron forge pedestal.
  week0EggEnchantment,

  /// Weeks 1–7: Progressive bare-metal chassis assembly on the rig + shrinking pile.
  bareMetalAssembly,

  /// Week 8: Cloaked Robot Archmage complete on the rig, optical eye & staff dimmed/unpowered.
  archmageDormant,

  /// Week 9: Cloaked Robot Archmage fully powered with crimson eye & purple-gold ignition surge.
  archmagePowered,

  /// Weeks 10–39: Robot Archmage deployed to Lair; Titanium Robot Egg overcharged & awakening on the forge pedestal.
  eggOvercharged,

  /// Week 40+ or Metal Wizard defeated: Forge embers cooling down.
  coolingDown,
}

/// Renders the animated Watch Tower Metal Wizard underground forge scene,
/// dynamically composing the Week 0 Titanium Robot Egg enchantment ritual,
/// progressive week-by-week Robot Archmage assembly (`Week 1` through `Week 9`),
/// Weeks 10–39 Overcharged / Awakening Titanium Robot Egg foreshadowing the
/// Baby Mage Robot final boss, and Week 40+ cooling forge embers.
class WatchtowerForgeView extends StatefulWidget {
  final bool animationsEnabled;
  final bool isFullScreen;
  final bool isCoolingDown;
  final int currentWeek;
  final bool playSnapInOnMount;
  final VoidCallback? onEggResonate;

  const WatchtowerForgeView({
    super.key,
    this.animationsEnabled = true,
    this.isFullScreen = false,
    this.isCoolingDown = false,
    this.currentWeek = 0,
    this.playSnapInOnMount = false,
    this.onEggResonate,
  });

  static const String forgeBackdropAsset = 'assets/images/forge_arena_bg.webp';
  static const String metalWizardAsset =
      'assets/images/enemies/metal_wizard_idle.png';
  static const String robotArchmageAsset =
      'assets/images/enemies/robot_archmage_idle.png';
  static const String babyRobotMageAsset =
      'assets/images/enemies/baby_robot_mage_idle.png';
  static const String babyRobotEggAsset =
      'assets/images/enemies/baby_robot_mage_egg.png';
  static const String nakedFrameAsset =
      'assets/images/watchtower/robot_archmage_naked_frame.png';

  static const List<String> stageAssets = [
    'assets/images/watchtower/archmage_stage_1_leg1.png',
    'assets/images/watchtower/archmage_stage_2_legs.png',
    'assets/images/watchtower/archmage_stage_3_waist.png',
    'assets/images/watchtower/archmage_stage_4_torso.png',
    'assets/images/watchtower/archmage_stage_5_arm1.png',
    'assets/images/watchtower/archmage_stage_6_arms.png',
    'assets/images/watchtower/archmage_stage_7_head.png',
  ];

  static const List<String> partAssets = [
    'assets/images/watchtower/archmage_part_1_leg1.png',
    'assets/images/watchtower/archmage_part_2_leg2.png',
    'assets/images/watchtower/archmage_part_3_waist.png',
    'assets/images/watchtower/archmage_part_4_torso.png',
    'assets/images/watchtower/archmage_part_5_arm1.png',
    'assets/images/watchtower/archmage_part_6_arm2.png',
    'assets/images/watchtower/archmage_part_7_head.png',
  ];

  /// Returns the aligned 512x512 bare-metal assembly stage asset for Weeks 1–7,
  /// or `null` outside that range.
  static String? stageAssetForWeek(int week) {
    if (week < 1 || week > 7) return null;
    return stageAssets[week - 1];
  }

  /// Returns the aligned 512x512 isolated newly-added part asset for Weeks 1–7,
  /// used during the first-visit overhead-chain snap-in animation.
  static String? partAssetForWeek(int week) {
    if (week < 1 || week > 7) return null;
    return partAssets[week - 1];
  }

  /// Returns the matching workbench parts pile asset for Weeks 0–6,
  /// or `null` once Week 7 clears the workbench.
  static String? pileAssetForWeek(int week) {
    if (week < 0 || week > 6) return null;
    return 'assets/images/watchtower/archmage_pile_week_$week.png';
  }

  /// Exact normalized `(u, v)` joint coordinates inside the 512x512 Archmage
  /// rig canvas for targeted welding sparks across Weeks 1–8.
  static Offset? weldingJointNormalizedForWeek(int week) {
    switch (week) {
      case 1:
        return const Offset(0.453, 0.605); // Right leg knee/hip joint
      case 2:
        return const Offset(0.621, 0.625); // Left leg knee/hip joint
      case 3:
        return const Offset(0.516, 0.473); // Pelvic waist joint
      case 4:
        return const Offset(0.516, 0.297); // Bare armored chest core
      case 5:
        return const Offset(0.594, 0.250); // Left shoulder joint
      case 6:
        return const Offset(0.434, 0.250); // Right shoulder joint
      case 7:
        return const Offset(0.516, 0.188); // Neck collar socket
      case 8:
        return const Offset(0.508, 0.285); // Cloak & staff clasp
      default:
        return null;
    }
  }

  /// Exact normalized `(u, v)` centers on `robot_archmage_idle.png` (512x512).
  static const Offset archmageEyeNormalized = Offset(0.498, 0.121);
  static const Offset archmageStaffOrbNormalized = Offset(0.217, 0.162);

  /// Exact normalized `(u, v)` center of the red optical visor on
  /// `baby_robot_mage_egg.png` (512x512).
  static const Offset eggEyeNormalized = Offset(0.495, 0.412);

  /// Resolves the active [ForgeAssemblyPhase] for the current week & state.
  ForgeAssemblyPhase get assemblyPhase {
    if (isCoolingDown || currentWeek >= 40) {
      return ForgeAssemblyPhase.coolingDown;
    }
    if (currentWeek <= 0) return ForgeAssemblyPhase.week0EggEnchantment;
    if (currentWeek <= 7) return ForgeAssemblyPhase.bareMetalAssembly;
    if (currentWeek == 8) return ForgeAssemblyPhase.archmageDormant;
    if (currentWeek == 9) return ForgeAssemblyPhase.archmagePowered;
    return ForgeAssemblyPhase.eggOvercharged;
  }

  /// Whether the Titanium Robot Egg is currently cradled on the iron forge
  /// pedestal (Week 0 enchantment or Weeks 10–39 overcharged awakening).
  bool get isEggOnPedestal =>
      assemblyPhase == ForgeAssemblyPhase.week0EggEnchantment ||
      assemblyPhase == ForgeAssemblyPhase.eggOvercharged;

  /// Whether the Titanium Robot Egg is in its Weeks 10–39 Overcharged /
  /// Awakening state.
  bool get isEggOvercharged =>
      assemblyPhase == ForgeAssemblyPhase.eggOvercharged;

  /// Convenience getter for the active stage sprite mounted on the rig or pedestal.
  String? get activeRigSpriteAsset {
    switch (assemblyPhase) {
      case ForgeAssemblyPhase.week0EggEnchantment:
      case ForgeAssemblyPhase.eggOvercharged:
        return babyRobotEggAsset;
      case ForgeAssemblyPhase.coolingDown:
        return null;
      case ForgeAssemblyPhase.bareMetalAssembly:
        return stageAssetForWeek(currentWeek);
      case ForgeAssemblyPhase.archmageDormant:
      case ForgeAssemblyPhase.archmagePowered:
        return robotArchmageAsset;
    }
  }

  /// Convenience getter for the workbench parts pile sprite (Weeks 1–6 only).
  String? get activePileAsset {
    if (isCoolingDown || currentWeek <= 0 || currentWeek >= 40) return null;
    return pileAssetForWeek(currentWeek);
  }

  bool get showsBlueprintHologram =>
      !isCoolingDown && currentWeek >= 1 && currentWeek <= 7;

  bool get isArchmageEyePoweredOff =>
      assemblyPhase == ForgeAssemblyPhase.archmageDormant;

  bool get isArchmageEyePoweredOn =>
      assemblyPhase == ForgeAssemblyPhase.archmagePowered;

  @override
  State<WatchtowerForgeView> createState() => _WatchtowerForgeViewState();
}

class _WatchtowerForgeViewState extends State<WatchtowerForgeView>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _snapInController;
  late final AnimationController _resonanceController;

  @override
  void initState() {
    super.initState();
    // 13.2s exact multiple of 2.2s (6 beats) and 1.1s (12 beats) for seamless heartbeat wrap
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13200),
    );
    _snapInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
      value: 1.0,
    );
    _resonanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0,
    );
    _syncAnimations(triggerSnapIn: widget.playSnapInOnMount);
  }

  @override
  void didUpdateWidget(covariant WatchtowerForgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final weekAdvanced = oldWidget.currentWeek != widget.currentWeek &&
        widget.currentWeek >= 1 &&
        widget.currentWeek <= 9 &&
        widget.playSnapInOnMount;
    if (oldWidget.animationsEnabled != widget.animationsEnabled ||
        weekAdvanced ||
        oldWidget.isCoolingDown != widget.isCoolingDown) {
      _syncAnimations(triggerSnapIn: weekAdvanced);
    }
  }

  void _syncAnimations({required bool triggerSnapIn}) {
    if (widget.animationsEnabled) {
      if (!_ambientController.isAnimating) {
        _ambientController.repeat();
      }
      if (triggerSnapIn &&
          !widget.isCoolingDown &&
          widget.currentWeek >= 1 &&
          widget.currentWeek <= 9) {
        _snapInController.forward(from: 0.0);
      }
    } else {
      if (_ambientController.isAnimating) {
        _ambientController.stop();
      }
      _snapInController.stop();
      _snapInController.value = 1.0;
    }
  }

  void _handleEggTap() {
    if (!widget.isEggOnPedestal) return;
    _resonanceController.forward(from: 0.0);
    widget.onEggResonate?.call();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _snapInController.dispose();
    _resonanceController.dispose();
    super.dispose();
  }

  _ForgeSceneGeometry _computeGeometry(Size size) {
    final unit = math.min(size.width, size.height);
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final rigSize = unit * 0.62;
    final rigRect = Rect.fromCenter(
      center: Offset(cx + unit * 0.15, cy - unit * 0.03),
      width: rigSize,
      height: rigSize,
    );

    final wizardSize = unit * 0.54;
    final wizardRect = Rect.fromCenter(
      center: Offset(cx - unit * 0.22, cy + unit * 0.06),
      width: wizardSize,
      height: wizardSize,
    );

    // Horizontally flipped Metal Wizard's gear-staff center: (0.81, 0.25) inside wizardRect
    final staffOrigin = Offset(
      wizardRect.left + wizardRect.width * 0.81,
      wizardRect.top + wizardRect.height * 0.25,
    );

    final benchTopY = cy + unit * 0.27;
    final workbenchRect = Rect.fromLTWH(
      cx - unit * 0.05,
      benchTopY,
      unit * 0.50,
      unit * 0.14,
    );

    final pileSize = unit * 0.46;
    final pileRect = Rect.fromLTWH(
      cx + unit * 0.18 - pileSize * 0.5,
      benchTopY + unit * 0.045 - pileSize * 0.72,
      pileSize,
      pileSize,
    );

    // Scaled-down Titanium Robot Egg (~35% of prior size) matching the Metal Wizard's hooded head height
    final eggSize = unit * 0.15;
    final eggCenter = Offset(cx + unit * 0.195, cy + unit * 0.064);
    final eggRect = Rect.fromCenter(
      center: eggCenter,
      width: eggSize,
      height: eggSize,
    );

    // Comfortable interactive tap hitbox centered on the scaled-down egg (stays strictly right of lens center)
    final eggTapRect = Rect.fromCenter(
      center: eggCenter,
      width: math.max(eggSize * 1.25, unit * 0.21),
      height: math.max(eggSize * 1.35, unit * 0.22),
    );

    final eggEyeCenter = Offset(
      eggRect.left + eggRect.width * WatchtowerForgeView.eggEyeNormalized.dx,
      eggRect.top + eggRect.height * WatchtowerForgeView.eggEyeNormalized.dy,
    );

    // Wrought-iron pedestal top cradle collar directly clasping the scaled-down egg's base
    final pedestalTopCenter = Offset(cx + unit * 0.195, cy + unit * 0.138);

    // Elliptical rotating rune ring center positioned below the egg's lower rim so
    // back arc (π..2π) passes behind the egg/pedestal and front arc (0..π) wraps in front of pedestal base
    final pedestalCenter = Offset(cx + unit * 0.195, cy + unit * 0.162);

    return _ForgeSceneGeometry(
      size: size,
      unit: unit,
      rigRect: rigRect,
      wizardRect: wizardRect,
      staffOrigin: staffOrigin,
      workbenchRect: workbenchRect,
      pileRect: pileRect,
      eggRect: eggRect,
      eggTapRect: eggTapRect,
      eggEyeCenter: eggEyeCenter,
      pedestalTopCenter: pedestalTopCenter,
      pedestalCenter: pedestalCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.assemblyPhase;
    final cooling = phase == ForgeAssemblyPhase.coolingDown;
    final eggOnPedestal = widget.isEggOnPedestal;
    final eggOvercharged = widget.isEggOvercharged;
    final week = widget.currentWeek;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0,
            constraints.maxHeight.isFinite ? constraints.maxHeight : 320.0,
          );
          final geom = _computeGeometry(size);

          return AnimatedBuilder(
            animation: Listenable.merge([
              _ambientController,
              _snapInController,
              _resonanceController,
            ]),
            builder: (context, _) {
              final t = widget.animationsEnabled ? _ambientController.value : 0.0;
              final snapT =
                  widget.animationsEnabled ? _snapInController.value : 1.0;
              final resonanceT = (_resonanceController.isAnimating ||
                      _resonanceController.value < 1.0)
                  ? _resonanceController.value
                  : 0.0;

              // Subtle 2px micro-shake on the assembly rig when newly added part snaps into place
              Offset rigShakeOffset = Offset.zero;
              if (snapT < 0.99 && snapT >= 0.58) {
                final u = ((snapT - 0.58) / 0.32).clamp(0.0, 1.0);
                final decay = (1.0 - u) * (1.0 - u);
                final amp = 2.2 * decay;
                rigShakeOffset = Offset(
                  math.sin(u * 26.0) * amp,
                  math.cos(u * 31.0) * amp * 0.7,
                );
              }

              // Subtle incubation tremor on the Titanium Robot Egg ONLY (Weeks 10–39 Overcharged)
              // plus brief tactile vibration during Tap-to-Resonate. Metal Wizard stays 100% static.
              Offset eggTremorOffset = Offset.zero;
              if (eggOvercharged && widget.animationsEnabled) {
                final beatPhase = (t * 12.0) % 1.0;
                final burstEnv = math.exp(
                  -math.pow((beatPhase - 0.16) / 0.11, 2),
                );
                final tremorAmp = (geom.unit * 0.0042).clamp(0.9, 1.8) * burstEnv;
                eggTremorOffset = Offset(
                  math.sin(t * 168.0 * math.pi) * tremorAmp,
                  math.cos(t * 134.0 * math.pi) * tremorAmp * 0.45,
                );
              }
              if (resonanceT > 0.0 && resonanceT < 0.35) {
                final resEnv = 1.0 - (resonanceT / 0.35);
                final resAmp = (geom.unit * 0.0032).clamp(0.7, 1.5) * resEnv;
                eggTremorOffset += Offset(
                  math.sin(resonanceT * 42.0 * math.pi) * resAmp,
                  0.0,
                );
              }

              return Stack(
                key: const ValueKey('watchtower_forge_view_stack'),
                fit: StackFit.expand,
                children: [
                  // 1. Dark underground stone forge backdrop
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      cooling
                          ? const Color(0xFF0A101C).withValues(alpha: 0.62)
                          : const Color(0xFF140A08).withValues(alpha: 0.34),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(
                      WatchtowerForgeView.forgeBackdropAsset,
                      key: const ValueKey('watchtower_forge_image'),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.0, 0.15),
                    ),
                  ),

                  // 2a. Back Layer (Behind Pedestal & Egg): rear/upper half (π..2π) of the
                  //     concentric rotating rune ring, floor aura, and background embers
                  if (eggOnPedestal)
                    IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey(
                            'watchtower_forge_egg_enchantment_back_painter',
                          ),
                          painter: EggEnchantmentPainter(
                            staffOrigin: geom.staffOrigin,
                            eggRect: geom.eggRect.shift(eggTremorOffset),
                            eggEyeCenter:
                                geom.eggEyeCenter + eggTremorOffset,
                            pedestalCenter: geom.pedestalCenter,
                            unit: geom.unit,
                            ambientProgress: t,
                            resonanceProgress: resonanceT,
                            isOvercharged: eggOvercharged,
                            animationsEnabled: widget.animationsEnabled,
                            isFullScreen: widget.isFullScreen,
                            layer: EggEnchantmentLayer.back,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),

                  // 2b. Iron Assembly Rig gantry & Workbench (Weeks 1–9 / Cooling)
                  //     OR Dark Wrought-Iron Arcane Forge Pedestal / Anvil Cradle (Week 0 & Weeks 10–39)
                  IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('watchtower_forge_rig_backdrop'),
                      painter: _ForgeWorkshopBackdropPainter(
                        geom: geom,
                        phase: phase,
                        currentWeek: week,
                        ambientProgress: t,
                        snapInProgress: snapT,
                        isCoolingDown: cooling,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),

                  // 3. Faint cyan-amber blueprint hologram silhouette (Weeks 1–7)
                  if (widget.showsBlueprintHologram)
                    _buildBlueprintHologramLayer(geom, t),

                  // 4. Middle Layer: Scaled-down Titanium Robot Egg / Assembly Stage / Cloaked Archmage
                  ..._buildRigSubjectLayers(
                    geom: geom,
                    phase: phase,
                    week: week,
                    ambientT: t,
                    snapT: snapT,
                    rigShakeOffset: rigShakeOffset,
                    eggTremorOffset: eggTremorOffset,
                  ),

                  // 5. Workbench Parts Pile (Weeks 1–6; vanishes piece-by-piece until Week 7)
                  if (widget.activePileAsset != null)
                    Positioned.fromRect(
                      rect: geom.pileRect,
                      child: Image.asset(
                        widget.activePileAsset!,
                        key: const ValueKey(
                          'watchtower_forge_parts_pile_image',
                        ),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                  // 6. Stationary Metal Wizard anchored on the left side of the forge (absent when cooling down)
                  if (!cooling)
                    _buildMetalWizardLayer(geom)
                  else
                    const SizedBox.shrink(
                      key: ValueKey('watchtower_forge_cooling_state'),
                    ),

                  // 7. Front Layer (In Front of Egg & Pedestal): front/lower rune ring arc (0..π),
                  //    staff-to-egg lightning conduits, visor heartbeat glow & tap-to-resonate burst
                  if (eggOnPedestal)
                    IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey(
                            'watchtower_forge_egg_enchantment_painter',
                          ),
                          painter: EggEnchantmentPainter(
                            staffOrigin: geom.staffOrigin,
                            eggRect: geom.eggRect.shift(eggTremorOffset),
                            eggEyeCenter:
                                geom.eggEyeCenter + eggTremorOffset,
                            pedestalCenter: geom.pedestalCenter,
                            unit: geom.unit,
                            ambientProgress: t,
                            resonanceProgress: resonanceT,
                            isOvercharged: eggOvercharged,
                            animationsEnabled: widget.animationsEnabled,
                            isFullScreen: widget.isFullScreen,
                            layer: EggEnchantmentLayer.front,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),

                  // 8. 60 FPS Forge Embers, Targeted Welding Beam & Sparks, Arcane Ignition & Vignette
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('watchtower_forge_vfx_paint'),
                        painter: _ForgeSpyglassVfxPainter(
                          geom: geom,
                          phase: phase,
                          currentWeek: week,
                          ambientProgress: t,
                          snapInProgress: snapT,
                          animationsEnabled: widget.animationsEnabled,
                          isFullScreen: widget.isFullScreen,
                          isCoolingDown: cooling,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                  // 9. Interactive Tap-to-Resonate hitbox over the scaled-down Titanium Robot Egg
                  if (eggOnPedestal)
                    Positioned.fromRect(
                      rect: geom.eggTapRect,
                      child: GestureDetector(
                        key: const ValueKey('watchtower_forge_egg_tap_target'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleEggTap,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBlueprintHologramLayer(_ForgeSceneGeometry geom, double t) {
    final pulse = widget.animationsEnabled
        ? 0.17 + 0.05 * math.sin(t * 6.0 * math.pi)
        : 0.19;
    return Positioned.fromRect(
      rect: geom.rigRect,
      child: Stack(
        key: const ValueKey('watchtower_forge_blueprint_hologram'),
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: pulse,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF00E5FF),
                BlendMode.srcIn,
              ),
              child: Image.asset(
                WatchtowerForgeView.nakedFrameAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          CustomPaint(
            painter: _BlueprintSchematicOutlinePainter(
              currentWeek: widget.currentWeek,
              ambientProgress: t,
              animationsEnabled: widget.animationsEnabled,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRigSubjectLayers({
    required _ForgeSceneGeometry geom,
    required ForgeAssemblyPhase phase,
    required int week,
    required double ambientT,
    required double snapT,
    required Offset rigShakeOffset,
    required Offset eggTremorOffset,
  }) {
    final activeRigRect = geom.rigRect.shift(rigShakeOffset);

    switch (phase) {
      case ForgeAssemblyPhase.coolingDown:
        return const [];

      case ForgeAssemblyPhase.week0EggEnchantment:
      case ForgeAssemblyPhase.eggOvercharged:
        return [
          Positioned.fromRect(
            rect: geom.eggRect.shift(eggTremorOffset),
            child: Image.asset(
              WatchtowerForgeView.babyRobotEggAsset,
              key: const ValueKey('watchtower_forge_egg_image'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ];

      case ForgeAssemblyPhase.bareMetalAssembly:
        final stageAsset = WatchtowerForgeView.stageAssetForWeek(week)!;
        final isSnapping = snapT < 0.99 && widget.animationsEnabled;

        if (isSnapping) {
          final prevStage = WatchtowerForgeView.stageAssetForWeek(week - 1);
          final newPart = WatchtowerForgeView.partAssetForWeek(week);
          // Part lowers smoothly during 0.0 .. 0.62, then snaps solidly at 0.0 offset
          final dropProgress = Curves.easeInCubic.transform(
            (snapT / 0.62).clamp(0.0, 1.0),
          );
          final dropDy = (1.0 - dropProgress) * (-geom.rigRect.height * 0.16);

          return [
            if (prevStage != null)
              Positioned.fromRect(
                rect: activeRigRect,
                child: Image.asset(
                  prevStage,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            if (newPart != null)
              Positioned.fromRect(
                rect: activeRigRect.shift(Offset(0, dropDy)),
                child: Image.asset(
                  newPart,
                  key: const ValueKey('watchtower_forge_snap_in_part_image'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
          ];
        }

        return [
          Positioned.fromRect(
            rect: activeRigRect,
            child: Image.asset(
              stageAsset,
              key: ValueKey('watchtower_forge_stage_${week}_image'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ];

      case ForgeAssemblyPhase.archmageDormant:
        final isSnapping = snapT < 0.99 && widget.animationsEnabled;
        final dropProgress = Curves.easeInCubic.transform(
          (snapT / 0.62).clamp(0.0, 1.0),
        );
        final dropDy = isSnapping
            ? (1.0 - dropProgress) * (-geom.rigRect.height * 0.12)
            : 0.0;

        return [
          if (isSnapping)
            Positioned.fromRect(
              rect: activeRigRect,
              child: Image.asset(
                WatchtowerForgeView.stageAssetForWeek(7)!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          Positioned.fromRect(
            rect: activeRigRect.shift(Offset(0, dropDy)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Slightly muted metallic ambiance since the Archmage is dormant/unpowered
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF0A0D18).withValues(alpha: 0.24),
                    BlendMode.srcATop,
                  ),
                  child: Image.asset(
                    WatchtowerForgeView.robotArchmageAsset,
                    key: const ValueKey('watchtower_forge_archmage_dormant_image'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                // Localized power-off dim/dark mask over optical eye & runic staff crystal
                CustomPaint(
                  key: const ValueKey('watchtower_forge_archmage_dormant_mask'),
                  painter: const _ArchmagePowerOffMaskPainter(),
                ),
              ],
            ),
          ),
        ];

      case ForgeAssemblyPhase.archmagePowered:
        final auraPulse = widget.animationsEnabled
            ? 0.5 + 0.5 * math.sin(ambientT * 10.0 * math.pi)
            : 0.75;
        return [
          Positioned.fromRect(
            rect: activeRigRect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  WatchtowerForgeView.robotArchmageAsset,
                  key: const ValueKey('watchtower_forge_archmage_powered_image'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                // Glowing crimson eye & purple-gold runic staff crystal overdrive
                CustomPaint(
                  key: const ValueKey('watchtower_forge_archmage_powered_vfx'),
                  painter: _ArchmagePowerOnGlowPainter(
                    pulse: auraPulse,
                    ignitionFlash: snapT < 0.99
                        ? math.sin(((snapT - 0.30) / 0.65).clamp(0.0, 1.0) * math.pi)
                        : 0.0,
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _buildMetalWizardLayer(_ForgeSceneGeometry geom) {
    return Positioned.fromRect(
      rect: geom.wizardRect,
      child: Transform.flip(
        flipX: true,
        child: Image.asset(
          WatchtowerForgeView.metalWizardAsset,
          key: const ValueKey('watchtower_forge_metal_wizard_image'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _ForgeSceneGeometry {
  final Size size;
  final double unit;
  final Rect rigRect;
  final Rect wizardRect;
  final Offset staffOrigin;
  final Rect workbenchRect;
  final Rect pileRect;
  final Rect eggRect;
  final Rect eggTapRect;
  final Offset eggEyeCenter;
  final Offset pedestalTopCenter;
  final Offset pedestalCenter;

  const _ForgeSceneGeometry({
    required this.size,
    required this.unit,
    required this.rigRect,
    required this.wizardRect,
    required this.staffOrigin,
    required this.workbenchRect,
    required this.pileRect,
    required this.eggRect,
    required this.eggTapRect,
    required this.eggEyeCenter,
    required this.pedestalTopCenter,
    required this.pedestalCenter,
  });

  Offset rigPoint(Offset normalized) => Offset(
        rigRect.left + rigRect.width * normalized.dx,
        rigRect.top + rigRect.height * normalized.dy,
      );
}

/// Paints the iron assembly gantry, overhead forge chains, anchor pedestal, and
/// heavy forge workbench behind the live character sprites.
class _ForgeWorkshopBackdropPainter extends CustomPainter {
  final _ForgeSceneGeometry geom;
  final ForgeAssemblyPhase phase;
  final int currentWeek;
  final double ambientProgress;
  final double snapInProgress;
  final bool isCoolingDown;

  const _ForgeWorkshopBackdropPainter({
    required this.geom,
    required this.phase,
    required this.currentWeek,
    required this.ambientProgress,
    required this.snapInProgress,
    required this.isCoolingDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == ForgeAssemblyPhase.week0EggEnchantment ||
        phase == ForgeAssemblyPhase.eggOvercharged) {
      _paintArcaneEggPedestal(canvas);
      return;
    }

    final rig = geom.rigRect;
    final bench = geom.workbenchRect;
    final u = geom.unit;

    final ironDark =
        isCoolingDown ? const Color(0xFF1A202C) : const Color(0xFF23222A);
    final ironHighlight =
        isCoolingDown ? const Color(0xFF3E4B5E) : const Color(0xFF5D534D);
    final rimWarm = isCoolingDown
        ? const Color(0xFF607D8B).withValues(alpha: 0.25)
        : const Color(0xFFFF9100).withValues(alpha: 0.35);

    // 1. Assembly Rig Iron Gantry Frame (two vertical pillars + top crossbeam)
    final pillarW = (u * 0.024).clamp(4.0, 14.0);
    final leftPillarX = rig.left + rig.width * 0.14;
    final rightPillarX = rig.right - rig.width * 0.10;
    final beamY = rig.top - u * 0.025;
    final baseY = rig.bottom + u * 0.005;

    final pillarPaint = Paint()..color = ironDark;
    final outlinePaint = Paint()
      ..color = ironHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = (u * 0.004).clamp(1.0, 2.5);

    final leftPillar = Rect.fromLTWH(
      leftPillarX - pillarW * 0.5,
      beamY,
      pillarW,
      baseY - beamY,
    );
    final rightPillar = Rect.fromLTWH(
      rightPillarX - pillarW * 0.5,
      beamY,
      pillarW,
      baseY - beamY,
    );
    final topBeam = Rect.fromLTWH(
      leftPillarX - pillarW * 1.1,
      beamY - pillarW * 0.4,
      (rightPillarX - leftPillarX) + pillarW * 2.2,
      pillarW * 1.1,
    );

    canvas.drawRect(leftPillar, pillarPaint);
    canvas.drawRect(rightPillar, pillarPaint);
    canvas.drawRect(topBeam, pillarPaint);
    canvas.drawRect(leftPillar, outlinePaint);
    canvas.drawRect(rightPillar, outlinePaint);
    canvas.drawRect(topBeam, outlinePaint);

    // Warm metallic firelight edge along gantry
    canvas.drawLine(
      Offset(leftPillar.left, leftPillar.top),
      Offset(leftPillar.left, leftPillar.bottom),
      Paint()
        ..color = rimWarm
        ..strokeWidth = 1.4,
    );

    // 2. Overhead Forge Chains descending from crossbeam
    final chainDrop = (snapInProgress < 0.99 && !isCoolingDown)
        ? (1.0 - Curves.easeInCubic.transform((snapInProgress / 0.62).clamp(0.0, 1.0))) *
            (rig.height * 0.14)
        : 0.0;
    _drawChain(
      canvas,
      Offset(rig.center.dx - rig.width * 0.16, topBeam.bottom),
      rig.height * 0.18 - chainDrop * 0.5,
      u,
      ironHighlight,
    );
    _drawChain(
      canvas,
      Offset(rig.center.dx + rig.width * 0.16, topBeam.bottom),
      rig.height * 0.18 - chainDrop * 0.5,
      u,
      ironHighlight,
    );

    // 3. Rig Steel Base Pedestal & Foot Clamps
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rig.center.dx, baseY),
        width: rig.width * 0.78,
        height: u * 0.042,
      ),
      Radius.circular(u * 0.012),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ironHighlight, ironDark],
        ).createShader(baseRect.outerRect),
    );
    canvas.drawRRect(baseRect, outlinePaint);

    // 4. Heavy Iron-Bound Forge Workbench (lower-right foreground)
    final tableTop = RRect.fromRectAndRadius(
      Rect.fromLTWH(bench.left, bench.top, bench.width, bench.height * 0.36),
      Radius.circular(u * 0.010),
    );
    final tableBody = Rect.fromLTWH(
      bench.left + bench.width * 0.06,
      bench.top + bench.height * 0.32,
      bench.width * 0.88,
      bench.height * 0.68,
    );

    // Soft grounding shadow under workbench
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bench.center.dx, bench.bottom + u * 0.01),
        width: bench.width * 1.06,
        height: u * 0.045,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.52)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawRect(
      tableBody,
      Paint()..color = isCoolingDown ? const Color(0xFF141822) : const Color(0xFF1D181A),
    );
    canvas.drawRect(tableBody, outlinePaint);
    canvas.drawRRect(
      tableTop,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isCoolingDown
              ? const [Color(0xFF3A4454), Color(0xFF212632)]
              : const [Color(0xFF56443A), Color(0xFF2B2220)],
        ).createShader(tableTop.outerRect),
    );
    canvas.drawRRect(tableTop, outlinePaint);

    // Top-edge warm specular line across workbench
    canvas.drawLine(
      Offset(tableTop.left + 4, tableTop.top + 1.2),
      Offset(tableTop.right - 4, tableTop.top + 1.2),
      Paint()
        ..color = rimWarm
        ..strokeWidth = 1.4,
    );
  }

  /// Paints the dark wrought-iron Arcane Forge Pedestal / Anvil Cradle
  /// proportioned to naturally seat the scaled-down Titanium Robot Egg
  /// (Week 0 & Weeks 10–39).
  void _paintArcaneEggPedestal(Canvas canvas) {
    final u = geom.unit;
    final pt = geom.pedestalTopCenter;
    final isOvercharged = phase == ForgeAssemblyPhase.eggOvercharged;
    final strokeW = (u * 0.0042).clamp(1.0, 2.3);

    const ironDeep = Color(0xFF16161D);
    const ironMid = Color(0xFF2A2933);
    const ironRim = Color(0xFF5E575E);
    final runeAccent = isOvercharged
        ? const Color(0xFFFF1744)
        : const Color(0xFFE040FB);
    final emberEdge = const Color(0xFFFFB300).withValues(alpha: 0.50);

    final outlinePaint = Paint()
      ..color = ironRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeJoin = StrokeJoin.round;

    final baseBottomY = pt.dy + u * 0.146;

    // 1. Grounding floor shadow & warm subterranean rune glow under anvil base
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pt.dx, baseBottomY + u * 0.005),
        width: u * 0.28,
        height: u * 0.054,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pt.dx, baseBottomY),
        width: u * 0.26,
        height: u * 0.046,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            runeAccent.withValues(alpha: isOvercharged ? 0.34 : 0.22),
            const Color(0xFFFF6D00).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: Offset(pt.dx, baseBottomY),
            width: u * 0.26,
            height: u * 0.065,
          ),
        ),
    );

    // 2. Stepped heavy wrought-iron anvil plinth (bottom slab resting on forge stone)
    final lowerBase = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pt.dx, baseBottomY - u * 0.015),
        width: u * 0.215,
        height: u * 0.032,
      ),
      Radius.circular(u * 0.008),
    );
    canvas.drawRRect(
      lowerBase,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [ironDeep, ironMid, Color(0xFF3A3642), ironDeep],
          stops: [0.0, 0.32, 0.62, 1.0],
        ).createShader(lowerBase.outerRect),
    );
    canvas.drawRRect(lowerBase, outlinePaint);

    // 3. Tapered forged iron pedestal column rising from plinth to egg cradle
    final waistTopY = pt.dy + u * 0.008;
    final waistBotY = lowerBase.top + u * 0.003;
    final waistPath = Path()
      ..moveTo(pt.dx - u * 0.056, waistTopY)
      ..lineTo(pt.dx + u * 0.056, waistTopY)
      ..quadraticBezierTo(
        pt.dx + u * 0.044,
        (waistTopY + waistBotY) * 0.54,
        pt.dx + u * 0.084,
        waistBotY,
      )
      ..lineTo(pt.dx - u * 0.084, waistBotY)
      ..quadraticBezierTo(
        pt.dx - u * 0.044,
        (waistTopY + waistBotY) * 0.54,
        pt.dx - u * 0.056,
        waistTopY,
      )
      ..close();

    canvas.drawPath(
      waistPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF383440), ironMid, ironDeep],
        ).createShader(waistPath.getBounds()),
    );
    canvas.drawPath(waistPath, outlinePaint);

    // Central carved arcane rune channel running vertically down the iron pedestal
    final grooveTop = Offset(pt.dx, waistTopY + u * 0.014);
    final grooveBot = Offset(pt.dx, waistBotY - u * 0.010);
    canvas.drawLine(
      grooveTop,
      grooveBot,
      Paint()
        ..color = runeAccent.withValues(alpha: 0.45)
        ..strokeWidth = (u * 0.012).clamp(2.5, 6.0)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawLine(
      grooveTop,
      grooveBot,
      Paint()
        ..color = const Color(0xFFFF80AB).withValues(alpha: 0.85)
        ..strokeWidth = (u * 0.0042).clamp(1.1, 2.3)
        ..strokeCap = StrokeCap.round,
    );

    // 4. Forged iron collar cup cleanly seating the base of the scaled-down egg
    final collarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pt.dx, pt.dy),
        width: u * 0.136,
        height: u * 0.025,
      ),
      Radius.circular(u * 0.009),
    );
    canvas.drawRRect(
      collarRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4B444E), ironMid, ironDeep],
        ).createShader(collarRect.outerRect),
    );
    canvas.drawRRect(collarRect, outlinePaint);

    // Recessed dark cradle bed shadow directly beneath the egg's lower tip
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pt.dx, pt.dy - u * 0.006),
        width: u * 0.095,
        height: u * 0.016,
      ),
      Paint()..color = const Color(0xFF0C0B10),
    );

    // Warm forge-light rim highlight + bolted iron rivets on collar & plinth
    canvas.drawLine(
      Offset(collarRect.left + u * 0.010, collarRect.top + strokeW * 0.8),
      Offset(collarRect.right - u * 0.010, collarRect.top + strokeW * 0.8),
      Paint()
        ..color = emberEdge
        ..strokeWidth = (u * 0.0036).clamp(0.9, 1.8),
    );
    final rivetPaint = Paint()..color = const Color(0xFF7B707B);
    final rivetR = (u * 0.0046).clamp(1.2, 2.6);
    for (final dx in [-0.048, -0.020, 0.020, 0.048]) {
      canvas.drawCircle(Offset(pt.dx + u * dx, pt.dy), rivetR, rivetPaint);
    }
    for (final dx in [-0.075, -0.036, 0.036, 0.075]) {
      canvas.drawCircle(
        Offset(pt.dx + u * dx, lowerBase.center.dy),
        rivetR,
        rivetPaint,
      );
    }

    // 5. Curved wrought-iron Anvil Cradle Prongs clasping the lower contour of the scaled-down egg
    final prongW = (u * 0.014).clamp(3.0, 8.0);
    for (final side in [-1.0, 1.0]) {
      final prongPath = Path()
        ..moveTo(pt.dx + side * u * 0.052, pt.dy - u * 0.003)
        ..quadraticBezierTo(
          pt.dx + side * u * 0.078,
          pt.dy - u * 0.018,
          pt.dx + side * u * 0.064,
          pt.dy - u * 0.052,
        )
        ..lineTo(pt.dx + side * u * 0.050, pt.dy - u * 0.043)
        ..quadraticBezierTo(
          pt.dx + side * u * 0.060,
          pt.dy - u * 0.018,
          pt.dx + side * u * 0.034,
          pt.dy - u * 0.004,
        )
        ..close();

      canvas.drawPath(
        prongPath,
        Paint()
          ..shader = LinearGradient(
            begin: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0xFF4E4752), ironMid, ironDeep],
          ).createShader(prongPath.getBounds()),
      );
      canvas.drawPath(prongPath, outlinePaint);

      // Subtle glowing rune tip at each iron prong
      canvas.drawCircle(
        Offset(pt.dx + side * u * 0.058, pt.dy - u * 0.045),
        prongW * 0.28,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.72)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
    }
  }

  void _drawChain(
    Canvas canvas,
    Offset top,
    double length,
    double unit,
    Color color,
  ) {
    final linkH = (unit * 0.022).clamp(4.0, 10.0);
    final linkW = linkH * 0.58;
    final count = math.max(2, (length / (linkH * 0.78)).floor());
    final paint = Paint()
      ..color = color.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (unit * 0.005).clamp(1.2, 2.4);

    for (int i = 0; i < count; i++) {
      final cy = top.dy + i * linkH * 0.78 + linkH * 0.5;
      final w = i.isEven ? linkW : linkW * 0.55;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(top.dx, cy), width: w, height: linkH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForgeWorkshopBackdropPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.currentWeek != currentWeek ||
        oldDelegate.snapInProgress != snapInProgress ||
        oldDelegate.isCoolingDown != isCoolingDown ||
        oldDelegate.geom.size != geom.size;
  }
}

/// Draws a dashed cyan-amber blueprint schematic outline + technical ticks
/// around the unbuilt portions of the Robot Archmage silhouette (Weeks 0–7).
class _BlueprintSchematicOutlinePainter extends CustomPainter {
  final int currentWeek;
  final double ambientProgress;
  final bool animationsEnabled;

  const _BlueprintSchematicOutlinePainter({
    required this.currentWeek,
    required this.ambientProgress,
    required this.animationsEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = animationsEnabled
        ? 0.55 + 0.35 * math.sin(ambientProgress * 6.0 * math.pi)
        : 0.72;
    final cyanPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.38 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.006).clamp(1.0, 2.0)
      ..strokeCap = StrokeCap.round;

    final amberPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.32 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.005).clamp(0.9, 1.7)
      ..strokeCap = StrokeCap.round;

    Offset p(double u, double v) => Offset(size.width * u, size.height * v);

    // Subtle vertical blueprint center axis
    _drawDashedLine(canvas, p(0.516, 0.03), p(0.516, 0.96), cyanPaint, 5, 5);

    // Corner calibration brackets
    final bLen = size.width * 0.065;
    for (final corner in [
      (Offset(size.width * 0.24, size.height * 0.04), 1.0, 1.0),
      (Offset(size.width * 0.78, size.height * 0.04), -1.0, 1.0),
      (Offset(size.width * 0.24, size.height * 0.96), 1.0, -1.0),
      (Offset(size.width * 0.78, size.height * 0.96), -1.0, -1.0),
    ]) {
      final c = corner.$1;
      canvas.drawLine(c, c + Offset(bLen * corner.$2, 0), amberPaint);
      canvas.drawLine(c, c + Offset(0, bLen * corner.$3), amberPaint);
    }

    // Draw dashed blueprint outlines ONLY for parts not yet installed
    // Head (installed at Week 7)
    if (currentWeek < 7) {
      _drawDashedOval(
        canvas,
        Rect.fromCenter(
          center: p(0.516, 0.115),
          width: size.width * 0.11,
          height: size.height * 0.145,
        ),
        cyanPaint,
      );
    }
    // Right arm (viewer-left, installed at Week 6)
    if (currentWeek < 6) {
      _drawDashedPolyline(
        canvas,
        [p(0.42, 0.21), p(0.36, 0.29), p(0.34, 0.44), p(0.34, 0.58)],
        cyanPaint,
      );
    }
    // Left arm (viewer-right, installed at Week 5)
    if (currentWeek < 5) {
      _drawDashedPolyline(
        canvas,
        [p(0.61, 0.21), p(0.69, 0.29), p(0.71, 0.44), p(0.71, 0.58)],
        cyanPaint,
      );
    }
    // Torso (installed at Week 4)
    if (currentWeek < 4) {
      _drawDashedPolyline(
        canvas,
        [
          p(0.43, 0.22),
          p(0.60, 0.22),
          p(0.58, 0.42),
          p(0.45, 0.42),
          p(0.43, 0.22),
        ],
        amberPaint,
      );
    }
    // Waist / pelvis (installed at Week 3)
    if (currentWeek < 3) {
      _drawDashedPolyline(
        canvas,
        [p(0.44, 0.43), p(0.59, 0.43), p(0.52, 0.53), p(0.44, 0.43)],
        amberPaint,
      );
    }
    // Left leg (viewer-right, installed at Week 2)
    if (currentWeek < 2) {
      _drawDashedPolyline(
        canvas,
        [p(0.56, 0.49), p(0.64, 0.69), p(0.72, 0.96)],
        cyanPaint,
      );
    }
    // Right leg (viewer-left, installed at Week 1)
    if (currentWeek < 1) {
      _drawDashedPolyline(
        canvas,
        [p(0.46, 0.49), p(0.45, 0.69), p(0.46, 0.91)],
        cyanPaint,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dash,
    double gap,
  ) {
    final total = (end - start).distance;
    if (total <= 0) return;
    final dir = (end - start) / total;
    double d = 0.0;
    while (d < total) {
      final segEnd = math.min(d + dash, total);
      canvas.drawLine(start + dir * d, start + dir * segEnd, paint);
      d += dash + gap;
    }
  }

  void _drawDashedPolyline(Canvas canvas, List<Offset> pts, Paint paint) {
    for (int i = 0; i < pts.length - 1; i++) {
      _drawDashedLine(canvas, pts[i], pts[i + 1], paint, 4.5, 4.0);
    }
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    const segments = 14;
    for (int i = 0; i < segments; i += 2) {
      final a0 = (i / segments) * 2 * math.pi;
      final sweep = (1.0 / segments) * 2 * math.pi;
      canvas.drawArc(rect, a0, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintSchematicOutlinePainter oldDelegate) {
    return oldDelegate.currentWeek != currentWeek ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.animationsEnabled != animationsEnabled;
  }
}

/// Week 8 localized power-off dim/dark mask painted cleanly over the Robot
/// Archmage's crimson optical eye and glowing purple runic staff orb so the
/// complete cloaked Archmage stands dormant and unpowered before Week 9.
class _ArchmagePowerOffMaskPainter extends CustomPainter {
  const _ArchmagePowerOffMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final eyeCenter = Offset(
      size.width * WatchtowerForgeView.archmageEyeNormalized.dx,
      size.height * WatchtowerForgeView.archmageEyeNormalized.dy,
    );
    final eyeR = size.width * 0.044;

    // 1. Suppress crimson optical flare & replace with dark unlit gunmetal lens
    canvas.drawOval(
      Rect.fromCenter(
        center: eyeCenter,
        width: eyeR * 2.35,
        height: eyeR * 1.15,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF141822).withValues(alpha: 0.96),
            const Color(0xFF1D2330).withValues(alpha: 0.82),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(
          Rect.fromCircle(center: eyeCenter, radius: eyeR * 1.3),
        ),
    );
    // Unlit obsidian optical aperture core + subtle cold steel rim
    canvas.drawCircle(
      eyeCenter,
      eyeR * 0.46,
      Paint()..color = const Color(0xFF10141D),
    );
    canvas.drawCircle(
      eyeCenter,
      eyeR * 0.46,
      Paint()
        ..color = const Color(0xFF566173).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width * 0.005).clamp(1.0, 2.0),
    );

    // 2. Dim the glowing purple staff crystal & golden outer rune ring into dormant dark quartz
    final orbCenter = Offset(
      size.width * WatchtowerForgeView.archmageStaffOrbNormalized.dx,
      size.height * WatchtowerForgeView.archmageStaffOrbNormalized.dy,
    );
    final orbR = size.width * 0.068;

    // Dim outer golden rune ring
    canvas.drawCircle(
      orbCenter,
      size.width * 0.125,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF13141E).withValues(alpha: 0.88),
            const Color(0xFF161622).withValues(alpha: 0.72),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(
          Rect.fromCircle(center: orbCenter, radius: size.width * 0.125),
        ),
    );
    // Unpowered smoky crystal sphere
    canvas.drawCircle(
      orbCenter,
      orbR * 0.82,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: const [
            Color(0xFF3E3B4E),
            Color(0xFF1F1D2B),
            Color(0xFF111018),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbR)),
    );
  }

  @override
  bool shouldRepaint(covariant _ArchmagePowerOffMaskPainter oldDelegate) =>
      false;
}

/// Week 9 overdrive crimson eye & purple-gold runic staff crystal glow.
class _ArchmagePowerOnGlowPainter extends CustomPainter {
  final double pulse;
  final double ignitionFlash;

  const _ArchmagePowerOnGlowPainter({
    required this.pulse,
    required this.ignitionFlash,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final eyeCenter = Offset(
      size.width * WatchtowerForgeView.archmageEyeNormalized.dx,
      size.height * WatchtowerForgeView.archmageEyeNormalized.dy,
    );
    final orbCenter = Offset(
      size.width * WatchtowerForgeView.archmageStaffOrbNormalized.dx,
      size.height * WatchtowerForgeView.archmageStaffOrbNormalized.dy,
    );

    // 1. Blazing crimson optical eye glow + horizontal lens flare
    final eyeRadius = size.width * (0.075 + 0.018 * pulse);
    canvas.drawCircle(
      eyeCenter,
      eyeRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF5252).withValues(alpha: 0.85),
            const Color(0xFFFF1744).withValues(alpha: 0.36 + 0.18 * pulse),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: eyeCenter, radius: eyeRadius)),
    );
    // Crisp crimson lens streak
    final flareHalfW = size.width * (0.095 + 0.03 * pulse);
    canvas.drawLine(
      eyeCenter - Offset(flareHalfW, 0),
      eyeCenter + Offset(flareHalfW, 0),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFFF8A80).withValues(alpha: 0.88),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCenter(center: eyeCenter, width: flareHalfW * 2, height: 4),
        )
        ..strokeWidth = (size.width * 0.008).clamp(1.4, 3.2),
    );

    // 2. Radiant purple-gold runic staff crystal aura
    final orbRadius = size.width * (0.145 + 0.025 * pulse);
    canvas.drawCircle(
      orbCenter,
      orbRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE040FB).withValues(alpha: 0.52 + 0.18 * pulse),
            const Color(0xFFFFD54F).withValues(alpha: 0.24 + 0.12 * pulse),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius)),
    );

    // 3. First-visit Week 9 arcane ignition surge flash
    if (ignitionFlash > 0.02) {
      final flashCenter = Offset(size.width * 0.46, size.height * 0.24);
      final flashR = size.width * 0.44;
      canvas.drawCircle(
        flashCenter,
        flashR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF8E1).withValues(alpha: 0.72 * ignitionFlash),
              const Color(0xFFD500F9).withValues(alpha: 0.36 * ignitionFlash),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: flashCenter, radius: flashR)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArchmagePowerOnGlowPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.ignitionFlash != ignitionFlash;
  }
}

class _ForgeSpyglassVfxPainter extends CustomPainter {
  final _ForgeSceneGeometry geom;
  final ForgeAssemblyPhase phase;
  final int currentWeek;
  final double ambientProgress;
  final double snapInProgress;
  final bool animationsEnabled;
  final bool isFullScreen;
  final bool isCoolingDown;

  const _ForgeSpyglassVfxPainter({
    required this.geom,
    required this.phase,
    required this.currentWeek,
    required this.ambientProgress,
    required this.snapInProgress,
    required this.animationsEnabled,
    required this.isFullScreen,
    required this.isCoolingDown,
  });

  static const List<
    ({double x, double yStart, double speed, double phase, double radius, double sway})
  > _emberSpecs = [
    (x: 0.10, yStart: 0.88, speed: 1.0, phase: 0.04, radius: 1.9, sway: 7.0),
    (x: 0.16, yStart: 0.82, speed: 1.2, phase: 0.37, radius: 1.4, sway: 5.5),
    (x: 0.26, yStart: 0.90, speed: 0.9, phase: 0.62, radius: 1.6, sway: 6.5),
    (x: 0.42, yStart: 0.86, speed: 1.1, phase: 0.19, radius: 1.5, sway: 8.0),
    (x: 0.55, yStart: 0.84, speed: 1.3, phase: 0.78, radius: 1.7, sway: 7.5),
    (x: 0.66, yStart: 0.92, speed: 1.0, phase: 0.46, radius: 1.4, sway: 6.0),
    (x: 0.74, yStart: 0.86, speed: 1.4, phase: 0.11, radius: 2.0, sway: 9.0),
    (x: 0.82, yStart: 0.80, speed: 1.2, phase: 0.53, radius: 2.2, sway: 10.0),
    (x: 0.86, yStart: 0.78, speed: 1.5, phase: 0.28, radius: 1.8, sway: 8.5),
    (x: 0.90, yStart: 0.84, speed: 1.1, phase: 0.89, radius: 1.6, sway: 7.0),
    (x: 0.48, yStart: 0.74, speed: 0.95, phase: 0.33, radius: 1.3, sway: 6.5),
    (x: 0.77, yStart: 0.88, speed: 1.35, phase: 0.74, radius: 1.8, sway: 9.5),
  ];

  static const List<({double angle, double speed, double phase})>
      _jointSparkSpecs = [
    (angle: -2.55, speed: 1.0, phase: 0.02),
    (angle: -2.05, speed: 1.25, phase: 0.17),
    (angle: -1.45, speed: 1.10, phase: 0.33),
    (angle: -0.95, speed: 1.30, phase: 0.48),
    (angle: -0.35, speed: 0.95, phase: 0.64),
    (angle: 0.25, speed: 1.15, phase: 0.79),
    (angle: 0.85, speed: 1.05, phase: 0.12),
    (angle: 1.55, speed: 0.90, phase: 0.56),
    (angle: -1.75, speed: 1.35, phase: 0.88),
    (angle: -0.60, speed: 1.20, phase: 0.41),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = animationsEnabled ? ambientProgress : 0.25;
    final firePulse = 0.5 + 0.5 * math.sin(t * 6.0 * math.pi);
    final intensity = isCoolingDown ? 0.34 : 1.0;
    final scale = isFullScreen ? 1.32 : 1.0;

    // 1. Warm pulsing firelight overlays
    final furnaceCenter = Offset(size.width * 0.86, size.height * 0.72);
    final furnaceRadius = size.shortestSide * 0.42;
    canvas.drawCircle(
      furnaceCenter,
      furnaceRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6D00).withValues(
              alpha: (0.14 + 0.08 * firePulse) * intensity,
            ),
            const Color(0xFFFFAB00).withValues(
              alpha: (0.06 + 0.04 * firePulse) * intensity,
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: furnaceCenter, radius: furnaceRadius),
        ),
    );

    // 2. Rising glowing orange/gold embers (or faint cooling embers when cooling down)
    for (final spec in _emberSpecs) {
      final cycle = (t * spec.speed + spec.phase) % 1.0;
      final y = size.height * (spec.yStart - 0.62 * cycle);
      final x = size.width * spec.x +
          math.sin(cycle * 2.0 * math.pi + spec.phase * 9.0) *
              spec.sway *
              scale;
      final fade = math.sin(cycle * math.pi).clamp(0.0, 1.0);
      final alpha = (0.78 * fade * intensity).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final pos = Offset(x, y);
      final r = spec.radius * scale;
      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..color = (isCoolingDown
                  ? const Color(0xFFFF5722)
                  : const Color(0xFFFF6D00))
              .withValues(alpha: alpha * 0.52)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: alpha),
      );
    }

    // 3. Targeted Joint Welding Beam & Spark Shower (Weeks 1–8)
    if (!isCoolingDown && currentWeek >= 1 && currentWeek <= 8) {
      final normJoint =
          WatchtowerForgeView.weldingJointNormalizedForWeek(currentWeek);
      if (normJoint != null) {
        final target = geom.rigPoint(normJoint);
        _paintTargetedWeldingBeam(canvas, geom.staffOrigin, target, t, scale);
      }
    }

    // 4. Week 9 Arcane Purple-Gold Ignition Discharge from Metal Wizard's gear-staff
    if (phase == ForgeAssemblyPhase.archmagePowered) {
      final eyeTarget = geom.rigPoint(WatchtowerForgeView.archmageEyeNormalized);
      final orbTarget =
          geom.rigPoint(WatchtowerForgeView.archmageStaffOrbNormalized);
      _paintArcaneEnergyArc(
        canvas,
        geom.staffOrigin,
        eyeTarget,
        t,
        scale,
        primaryColor: const Color(0xFFD500F9),
        coreColor: const Color(0xFFFFE082),
        seed: 1.0,
      );
      _paintArcaneEnergyArc(
        canvas,
        geom.staffOrigin,
        orbTarget,
        t,
        scale,
        primaryColor: const Color(0xFFFFB300),
        coreColor: const Color(0xFFEA80FC),
        seed: 2.3,
      );
    }

    // 5. First-visit snap-in bright welding impact flash (Weeks 1–8)
    if (!isCoolingDown &&
        snapInProgress < 0.99 &&
        snapInProgress >= 0.56 &&
        currentWeek >= 1 &&
        currentWeek <= 8) {
      final normJoint =
          WatchtowerForgeView.weldingJointNormalizedForWeek(currentWeek);
      if (normJoint != null) {
        final impact = geom.rigPoint(normJoint);
        final u = ((snapInProgress - 0.56) / 0.36).clamp(0.0, 1.0);
        final flash = math.sin(u * math.pi);
        final flashR = geom.unit * (0.08 + 0.14 * flash);
        canvas.drawCircle(
          impact,
          flashR,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95 * flash),
                const Color(0xFFFFE57F).withValues(alpha: 0.72 * flash),
                const Color(0xFFFF6D00).withValues(alpha: 0.32 * flash),
                Colors.transparent,
              ],
              stops: const [0.0, 0.30, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: impact, radius: flashR)),
        );
      }
    }

    // 6. Spyglass optical vignette overlay
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = (isFullScreen
                ? RadialGradient(
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.36),
                    ],
                    stops: const [0.0, 0.62, 1.0],
                  )
                : RadialGradient(
                    radius: 0.92,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF04141C).withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.62, 0.86, 1.0],
                  ))
            .createShader(Offset.zero & size),
    );
  }

  void _paintTargetedWeldingBeam(
    Canvas canvas,
    Offset origin,
    Offset target,
    double t,
    double scale,
  ) {
    final flicker = 0.68 + 0.32 * math.sin(t * 42.0 * math.pi);

    // Outer warm welding glow along beam
    canvas.drawLine(
      origin,
      target,
      Paint()
        ..color = const Color(0xFFFF9100).withValues(alpha: 0.38 * flicker)
        ..strokeWidth = 5.5 * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    // Crisp white-gold inner beam
    canvas.drawLine(
      origin,
      target,
      Paint()
        ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.86 * flicker)
        ..strokeWidth = 1.6 * scale
        ..strokeCap = StrokeCap.round,
    );

    // Glowing weld hotspot at exact joint coordinate
    final spotR = 11.0 * scale * (0.85 + 0.25 * flicker);
    canvas.drawCircle(
      target,
      spotR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * flicker),
            const Color(0xFFFFD54F).withValues(alpha: 0.72 * flicker),
            const Color(0xFFFF6D00).withValues(alpha: 0.28 * flicker),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: target, radius: spotR)),
    );

    // Directional welding spark shower bursting from the joint
    for (final s in _jointSparkSpecs) {
      final cycle = (t * 4.5 * s.speed + s.phase) % 1.0;
      if (cycle > 0.58) continue;
      final u = cycle / 0.58;
      final fade = (1.0 - u).clamp(0.0, 1.0);
      final dist = (14.0 + 20.0 * s.speed) * scale * u;
      final gravity = 16.0 * scale * u * u;
      final head = Offset(
        target.dx + math.cos(s.angle) * dist,
        target.dy + math.sin(s.angle) * dist + gravity,
      );
      final tail = Offset(
        target.dx + math.cos(s.angle) * (dist * 0.72),
        target.dy + math.sin(s.angle) * (dist * 0.72) + gravity * 0.65,
      );
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..color = const Color(0xFFFFF59D).withValues(alpha: fade * 0.95)
          ..strokeWidth = 1.5 * scale
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintArcaneEnergyArc(
    Canvas canvas,
    Offset start,
    Offset end,
    double t,
    double scale, {
    required Color primaryColor,
    required Color coreColor,
    required double seed,
  }) {
    final path = Path()..moveTo(start.dx, start.dy);
    const segments = 9;
    final delta = end - start;
    final len = delta.distance;
    if (len <= 1.0) return;
    final perp = Offset(-delta.dy / len, delta.dx / len);

    for (int i = 1; i < segments; i++) {
      final f = i / segments;
      final env = math.sin(f * math.pi);
      final jitter = math.sin(t * 28.0 * math.pi + i * 2.1 + seed) *
          (9.0 * scale * env);
      final pt = Offset(
        start.dx + delta.dx * f + perp.dx * jitter,
        start.dy + delta.dy * f + perp.dy * jitter,
      );
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(end.dx, end.dy);

    final pulse = 0.70 + 0.30 * math.sin(t * 20.0 * math.pi + seed);
    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.62 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = coreColor.withValues(alpha: 0.94 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ForgeSpyglassVfxPainter oldDelegate) {
    return oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.snapInProgress != snapInProgress ||
        oldDelegate.phase != phase ||
        oldDelegate.currentWeek != currentWeek ||
        oldDelegate.animationsEnabled != animationsEnabled ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.isCoolingDown != isCoolingDown ||
        oldDelegate.geom.size != geom.size;
  }
}

/// Render pass selector for [EggEnchantmentPainter] so the rear/upper half of
/// the elliptical runic ring (`π` to `2π`) and background aura/embers render
/// behind the wrought-iron pedestal & Titanium Robot Egg while the front/lower
/// arc (`0` to `π`), staff lightning conduits, optical visor pulse, and
/// Tap-to-Resonate shockwave render cleanly in front.
enum EggEnchantmentLayer {
  /// Back pass painted underneath the iron pedestal and Titanium Robot Egg.
  back,

  /// Front pass painted in front of the Titanium Robot Egg and pedestal base.
  front,

  /// Combined single-pass render (back then front).
  both,
}

/// Dedicated 60 FPS arcane enchantment overlay rendered whenever the Titanium
/// Robot Egg rests on the wrought-iron forge pedestal (Week 0 ritual &
/// Weeks 10–39 Overcharged / Awakening state).
///
/// Renders:
/// 1. Glowing crimson-violet (`#E040FB` / `#FF1744`) and molten-amber
///    (`#FFB300`) energy conduits & crackling lightning tendrils streaming
///    from the Metal Wizard's clockwork staff into the scaled-down egg's red
///    optical eye.
/// 2. Slowly rotating concentric golden-and-crimson magic rune ring around
///    the iron pedestal (Z-ordered so `π..2π` passes behind the egg/pedestal
///    and `0..π` wraps cleanly in front of the pedestal base), rising
///    incandescent embers/mana motes, and a smooth rhythmic heartbeat glow
///    (`~2.2s` Week 0 / `~1.1s` Overcharged) illuminating the egg's crimson
///    runes and red visor.
/// 3. Interactive Tap-to-Resonate defensive crimson-violet shockwave ring and
///    optical visor flare (`~450ms`).
class EggEnchantmentPainter extends CustomPainter {
  final Offset staffOrigin;
  final Rect eggRect;
  final Offset eggEyeCenter;
  final Offset pedestalCenter;
  final double unit;
  final double ambientProgress;
  final double resonanceProgress;
  final bool isOvercharged;
  final bool animationsEnabled;
  final bool isFullScreen;
  final EggEnchantmentLayer layer;

  const EggEnchantmentPainter({
    required this.staffOrigin,
    required this.eggRect,
    required this.eggEyeCenter,
    required this.pedestalCenter,
    required this.unit,
    required this.ambientProgress,
    required this.resonanceProgress,
    required this.isOvercharged,
    required this.animationsEnabled,
    required this.isFullScreen,
    this.layer = EggEnchantmentLayer.both,
  });

  static const Color _violetArcane = Color(0xFFE040FB);
  static const Color _crimsonCore = Color(0xFFFF1744);
  static const Color _moltenAmber = Color(0xFFFFB300);
  static const Color _hotFilament = Color(0xFFFFF3E0);

  static const List<
    ({double angleOffset, double radiusFactor, double speed, double phase, double size, int colorIdx})
  > _manaMoteSpecs = [
    (angleOffset: 0.15, radiusFactor: 0.85, speed: 1.0, phase: 0.04, size: 1.7, colorIdx: 0),
    (angleOffset: 0.82, radiusFactor: 1.05, speed: 1.3, phase: 0.21, size: 1.4, colorIdx: 1),
    (angleOffset: 1.54, radiusFactor: 0.72, speed: 1.1, phase: 0.39, size: 1.9, colorIdx: 2),
    (angleOffset: 2.28, radiusFactor: 0.96, speed: 1.4, phase: 0.56, size: 1.5, colorIdx: 0),
    (angleOffset: 2.95, radiusFactor: 0.80, speed: 0.95, phase: 0.73, size: 1.6, colorIdx: 1),
    (angleOffset: 3.68, radiusFactor: 1.08, speed: 1.25, phase: 0.88, size: 1.4, colorIdx: 2),
    (angleOffset: 4.35, radiusFactor: 0.76, speed: 1.15, phase: 0.14, size: 1.8, colorIdx: 0),
    (angleOffset: 5.08, radiusFactor: 0.92, speed: 1.35, phase: 0.47, size: 1.5, colorIdx: 1),
    (angleOffset: 5.74, radiusFactor: 0.68, speed: 1.05, phase: 0.65, size: 1.3, colorIdx: 2),
    (angleOffset: 0.52, radiusFactor: 0.62, speed: 1.50, phase: 0.31, size: 1.6, colorIdx: 1),
    (angleOffset: 2.62, radiusFactor: 1.12, speed: 1.20, phase: 0.79, size: 1.4, colorIdx: 0),
    (angleOffset: 4.72, radiusFactor: 0.88, speed: 1.45, phase: 0.92, size: 1.8, colorIdx: 2),
  ];

  /// Computes a smooth cardiac double-pulse (`lub-dub`) heartbeat value in `[0, 1]`.
  double _computeHeartbeat(double t) {
    final beatsPerLoop = isOvercharged ? 12.0 : 6.0;
    final beatPhase = (t * beatsPerLoop) % 1.0;
    final primaryBeat = math.exp(-math.pow((beatPhase - 0.14) / 0.085, 2));
    final echoBeat =
        0.60 * math.exp(-math.pow((beatPhase - 0.31) / 0.105, 2));
    final baseline = isOvercharged ? 0.30 : 0.18;
    return (baseline + (1.0 - baseline) * math.max(primaryBeat, echoBeat))
        .clamp(0.0, 1.0);
  }

  Offset _eggPoint(double u, double v) => Offset(
        eggRect.left + eggRect.width * u,
        eggRect.top + eggRect.height * v,
      );

  static double _normalizeAngle(double a) {
    const twoPi = 2.0 * math.pi;
    final r = a % twoPi;
    return r < 0 ? r + twoPi : r;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = animationsEnabled ? ambientProgress : 0.14;
    final scale = isFullScreen ? 1.30 : 1.0;
    final heartbeat = _computeHeartbeat(t);
    final intensity = isOvercharged ? 1.32 : 1.0;
    final resActive = resonanceProgress > 0.001 && resonanceProgress < 0.999;
    final resSurge =
        resActive ? math.sin(resonanceProgress * math.pi).clamp(0.0, 1.0) : 0.0;

    final drawBack = layer == EggEnchantmentLayer.back ||
        layer == EggEnchantmentLayer.both;
    final drawFront = layer == EggEnchantmentLayer.front ||
        layer == EggEnchantmentLayer.both;

    if (drawBack) {
      // Back Layer (Behind Pedestal & Egg):
      // 1. Rear/upper half (π to 2π) of the concentric rotating golden & crimson rune ring + floor aura
      _paintRotatingRunicPedestalHalf(
        canvas,
        t: t,
        heartbeat: heartbeat,
        scale: scale,
        intensity: intensity,
        isBackHalf: true,
      );

      // 2. Soft ambient heartbeat crimson-violet halo behind the Titanium Robot Egg
      _paintEggBackgroundAura(canvas, heartbeat, resSurge);

      // 3. Background rising incandescent embers/mana motes orbiting behind the egg
      _paintRisingManaMotes(
        canvas,
        t: t,
        scale: scale,
        intensity: intensity,
        isBackHalf: true,
      );
    }

    if (drawFront) {
      // Front Layer (In Front of Egg & Pedestal Base):
      // 1. Front/lower half (0 to π) of the concentric rotating golden & crimson rune ring
      _paintRotatingRunicPedestalHalf(
        canvas,
        t: t,
        heartbeat: heartbeat,
        scale: scale,
        intensity: intensity,
        isBackHalf: false,
      );

      // 2. Heartbeat crimson-violet rune & red optical visor glow over the scaled-down egg
      _paintEggFrontHeartbeatAndVisorGlow(
        canvas,
        heartbeat,
        scale,
        intensity,
        resSurge,
      );

      // 3. Arcane energy conduit & crackling lightning tendrils (Staff -> Egg & Eye)
      _paintStaffToEggConduits(canvas, t, heartbeat, scale, intensity, resSurge);

      // 4. Foreground rising incandescent embers & mana motes
      _paintRisingManaMotes(
        canvas,
        t: t,
        scale: scale,
        intensity: intensity,
        isBackHalf: false,
      );

      // 5. Interactive Tap-to-Resonate shockwave ring & optical visor flare (~450ms)
      if (resActive) {
        _paintTapResonanceBurst(canvas, scale);
      }
    }
  }

  /// Paints either the rear/upper half (`π` to `2π`, behind pedestal & egg) or
  /// the front/lower half (`0` to `π`, wrapping cleanly in front of the
  /// pedestal base below the egg) of the rotating concentric rune ring.
  void _paintRotatingRunicPedestalHalf(
    Canvas canvas, {
    required double t,
    required double heartbeat,
    required double scale,
    required double intensity,
    required bool isBackHalf,
  }) {
    final outerRx = unit * 0.158;
    final outerRy = unit * 0.041;
    final innerRx = outerRx * 0.73;
    final innerRy = outerRy * 0.73;

    // Soft glowing floor aura painted once in the back layer behind pedestal & egg
    if (isBackHalf) {
      final glowRect = Rect.fromCenter(
        center: pedestalCenter,
        width: outerRx * 2.35,
        height: outerRy * 2.8,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _crimsonCore.withValues(
                alpha: (0.20 + 0.16 * heartbeat) * intensity.clamp(1.0, 1.25),
              ),
              _violetArcane.withValues(alpha: 0.10 + 0.08 * heartbeat),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(glowRect),
      );
    }

    final outerOval = Rect.fromCenter(
      center: pedestalCenter,
      width: outerRx * 2.0,
      height: outerRy * 2.0,
    );
    final innerOval = Rect.fromCenter(
      center: pedestalCenter,
      width: innerRx * 2.0,
      height: innerRy * 2.0,
    );

    // Back/upper arc covers [π, 2π] (sin <= 0); Front/lower arc covers [0, π] (sin >= 0)
    final startAngle = isBackHalf ? math.pi : 0.0;
    const sweepAngle = math.pi;
    final depthFade = isBackHalf ? 0.76 : 1.0;

    // Outer golden magic circle arc halo + crisp ring
    final goldAlpha =
        ((0.48 + 0.34 * heartbeat) * depthFade).clamp(0.0, 0.95);
    canvas.drawArc(
      outerOval,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = _moltenAmber.withValues(alpha: goldAlpha * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8 * scale
        ..strokeCap = StrokeCap.butt
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
    );
    canvas.drawArc(
      outerOval,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = _moltenAmber.withValues(alpha: goldAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25 * scale
        ..strokeCap = StrokeCap.butt,
    );

    // Inner counter-rotating crimson-violet ring arc
    final crimsonAlpha =
        ((0.52 + 0.36 * heartbeat) * depthFade).clamp(0.0, 0.96);
    canvas.drawArc(
      innerOval,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = _crimsonCore.withValues(alpha: crimsonAlpha * 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * scale
        ..strokeCap = StrokeCap.butt
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.drawArc(
      innerOval,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = _violetArcane.withValues(alpha: crimsonAlpha * 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05 * scale
        ..strokeCap = StrokeCap.butt,
    );

    // Slowly rotating outer golden arcane rune ticks & glyphs filtered strictly to this half
    final rotOuter = t * 2.0 * math.pi * (isOvercharged ? 2.0 : 1.0);
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15 * scale
      ..strokeCap = StrokeCap.round;
    const outerRunes = 12;
    for (int i = 0; i < outerRunes; i++) {
      final a = _normalizeAngle(rotOuter + (i / outerRunes) * 2.0 * math.pi);
      final inBack = a >= math.pi;
      if (inBack != isBackHalf) continue;

      final ca = math.cos(a);
      final sa = math.sin(a);
      final depth = 0.65 + 0.35 * ((sa + 1.0) * 0.5);
      final pOuter = Offset(
        pedestalCenter.dx + ca * outerRx,
        pedestalCenter.dy + sa * outerRy,
      );
      final pInner = Offset(
        pedestalCenter.dx + ca * (outerRx * 0.86),
        pedestalCenter.dy + sa * (outerRy * 0.86),
      );
      canvas.drawLine(
        pInner,
        pOuter,
        tickPaint
          ..color = const Color(0xFFFFE082).withValues(alpha: goldAlpha * depth),
      );

      if (i.isEven) {
        final glyphCenter = Offset(
          pedestalCenter.dx + ca * (outerRx * 0.93),
          pedestalCenter.dy + sa * (outerRy * 0.93),
        );
        canvas.drawCircle(
          glyphCenter,
          1.45 * scale,
          Paint()
            ..color = _moltenAmber.withValues(alpha: goldAlpha * depth),
        );
      }
    }

    // Counter-rotating inner crimson rune nodes filtered strictly to this half
    final rotInner = -t * 4.0 * math.pi * (isOvercharged ? 1.5 : 1.0);
    const innerRunes = 6;
    for (int i = 0; i < innerRunes; i++) {
      final a = _normalizeAngle(rotInner + (i / innerRunes) * 2.0 * math.pi);
      final inBack = a >= math.pi;
      if (inBack != isBackHalf) continue;

      final node = Offset(
        pedestalCenter.dx + math.cos(a) * innerRx,
        pedestalCenter.dy + math.sin(a) * innerRy,
      );
      canvas.drawCircle(
        node,
        3.1 * scale,
        Paint()
          ..color = _crimsonCore.withValues(alpha: 0.42 * crimsonAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawCircle(
        node,
        1.25 * scale,
        Paint()..color = const Color(0xFFFF8A80).withValues(alpha: crimsonAlpha),
      );
    }
  }

  /// Soft rhythmic crimson-violet aura halo painted behind the Titanium Robot Egg.
  void _paintEggBackgroundAura(
    Canvas canvas,
    double heartbeat,
    double resSurge,
  ) {
    final boost = (heartbeat + resSurge * 0.75).clamp(0.0, 1.45);
    final eggCenter = eggRect.center;
    final auraR = eggRect.width * (0.76 + 0.12 * heartbeat);
    canvas.drawCircle(
      eggCenter,
      auraR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _crimsonCore.withValues(
              alpha: (0.20 + 0.20 * boost).clamp(0.0, 0.50),
            ),
            _violetArcane.withValues(
              alpha: (0.10 + 0.14 * boost).clamp(0.0, 0.34),
            ),
            Colors.transparent,
          ],
          stops: const [0.22, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: eggCenter, radius: auraR)),
    );
  }

  /// Foreground heartbeat glow pulse illuminating the scaled-down egg's
  /// crimson runes and central red optical visor.
  void _paintEggFrontHeartbeatAndVisorGlow(
    Canvas canvas,
    double heartbeat,
    double scale,
    double intensity,
    double resSurge,
  ) {
    final boost = (heartbeat + resSurge * 0.75).clamp(0.0, 1.45);

    // 1. Crisp pulsing highlights along the egg's crimson-violet & amber rune fissures
    const runePoints = [
      (u: 0.33, v: 0.23, isAmber: true),
      (u: 0.67, v: 0.22, isAmber: true),
      (u: 0.24, v: 0.50, isAmber: false),
      (u: 0.76, v: 0.50, isAmber: false),
      (u: 0.29, v: 0.68, isAmber: true),
      (u: 0.70, v: 0.68, isAmber: true),
    ];
    final runeBaseR = eggRect.width * (0.075 + 0.025 * heartbeat);
    for (final rp in runePoints) {
      final pt = _eggPoint(rp.u, rp.v);
      final c = rp.isAmber ? _moltenAmber : _violetArcane;
      final a = ((0.16 + 0.30 * boost) * (isOvercharged ? 1.2 : 1.0))
          .clamp(0.0, 0.68);
      canvas.drawCircle(
        pt,
        runeBaseR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c.withValues(alpha: a),
              _crimsonCore.withValues(alpha: a * 0.42),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: pt, radius: runeBaseR)),
      );
    }

    // 2. Rhythmic heartbeat glow illuminating the central red optical visor
    final visorR = eggRect.width * (0.21 + 0.065 * boost);
    canvas.drawCircle(
      eggEyeCenter,
      visorR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8A80).withValues(
              alpha: (0.44 + 0.38 * boost).clamp(0.0, 0.94),
            ),
            _crimsonCore.withValues(
              alpha: (0.26 + 0.32 * boost).clamp(0.0, 0.80),
            ),
            _violetArcane.withValues(
              alpha: (0.08 + 0.14 * boost).clamp(0.0, 0.38),
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 0.70, 1.0],
        ).createShader(Rect.fromCircle(center: eggEyeCenter, radius: visorR)),
    );

    // Crisp horizontal crimson optical lens streak pulsing with heartbeat
    final flareHalfW =
        eggRect.width * (0.24 + 0.14 * heartbeat * intensity);
    canvas.drawLine(
      eggEyeCenter - Offset(flareHalfW, 0),
      eggEyeCenter + Offset(flareHalfW, 0),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _crimsonCore.withValues(alpha: (0.55 + 0.35 * heartbeat).clamp(0.0, 0.95)),
            _hotFilament.withValues(alpha: (0.62 + 0.34 * heartbeat).clamp(0.0, 0.98)),
            _crimsonCore.withValues(alpha: (0.55 + 0.35 * heartbeat).clamp(0.0, 0.95)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: eggEyeCenter,
            width: flareHalfW * 2.0,
            height: 3.4 * scale,
          ),
        )
        ..strokeWidth = (1.35 + 0.85 * heartbeat) * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintStaffToEggConduits(
    Canvas canvas,
    double t,
    double heartbeat,
    double scale,
    double intensity,
    double resSurge,
  ) {
    final surge = 1.0 + 0.45 * resSurge;

    // 1. Glowing clockwork-core energy flare at the Metal Wizard's staff origin
    final staffFlareR =
        unit * (0.056 + 0.015 * heartbeat) * (isOvercharged ? 1.18 : 1.0);
    canvas.drawCircle(
      staffOrigin,
      staffFlareR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _hotFilament.withValues(alpha: 0.82),
            _moltenAmber.withValues(alpha: 0.56 + 0.20 * heartbeat),
            _violetArcane.withValues(alpha: 0.30 + 0.16 * heartbeat),
            Colors.transparent,
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: staffOrigin, radius: staffFlareR)),
    );

    // 2. Smooth glowing curved arcane energy conduit stream (Staff -> Scaled-Down Egg Red Visor)
    final midCtrl = Offset(
      (staffOrigin.dx + eggEyeCenter.dx) * 0.52,
      (staffOrigin.dy + eggEyeCenter.dy) * 0.5 -
          unit * (0.042 + 0.012 * math.sin(t * 12.0 * math.pi)),
    );
    final conduitPath = Path()
      ..moveTo(staffOrigin.dx, staffOrigin.dy)
      ..quadraticBezierTo(
        midCtrl.dx,
        midCtrl.dy,
        eggEyeCenter.dx,
        eggEyeCenter.dy,
      );

    final conduitAlpha =
        ((0.46 + 0.28 * heartbeat) * intensity).clamp(0.0, 0.92);
    canvas.drawPath(
      conduitPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _moltenAmber.withValues(alpha: conduitAlpha * 0.72),
            _violetArcane.withValues(alpha: conduitAlpha * 0.85),
            _crimsonCore.withValues(alpha: conduitAlpha * 0.92),
          ],
        ).createShader(Rect.fromPoints(staffOrigin, eggEyeCenter).inflate(24))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2 * scale * surge
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawPath(
      conduitPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _hotFilament.withValues(alpha: 0.88),
            const Color(0xFFFF80AB).withValues(alpha: 0.92),
            _crimsonCore.withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromPoints(staffOrigin, eggEyeCenter).inflate(12))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45 * scale * surge
        ..strokeCap = StrokeCap.round,
    );

    // Traveling luminous mana pulses flowing along the Bezier conduit into the visor
    final pulseCount = isOvercharged ? 5 : 3;
    for (int i = 0; i < pulseCount; i++) {
      final p = ((t * (isOvercharged ? 7.0 : 4.0)) + i / pulseCount) % 1.0;
      final inv = 1.0 - p;
      final pos = Offset(
        inv * inv * staffOrigin.dx +
            2 * inv * p * midCtrl.dx +
            p * p * eggEyeCenter.dx,
        inv * inv * staffOrigin.dy +
            2 * inv * p * midCtrl.dy +
            p * p * eggEyeCenter.dy,
      );
      final fade = math.sin(p * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        3.6 * scale,
        Paint()
          ..color = (i.isEven ? _violetArcane : _moltenAmber)
              .withValues(alpha: 0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        pos,
        1.55 * scale,
        Paint()..color = _hotFilament.withValues(alpha: 0.95 * fade),
      );
    }

    // 3. Crackling crimson-violet & molten-amber lightning tendrils converging on the egg
    final jitterScale = (isOvercharged ? 1.32 : 1.0) * surge;
    // Main crimson-violet lightning arc directly onto the scaled-down egg's red optical visor
    _paintLightningTendril(
      canvas,
      staffOrigin,
      eggEyeCenter,
      t: t,
      scale: scale * 0.92,
      primaryColor: _violetArcane,
      coreColor: _crimsonCore,
      jitterAmp: 8.5 * jitterScale,
      seed: 1.4,
      speedMult: isOvercharged ? 44.0 : 30.0,
    );

    // Molten-amber arcane lightning stream arching into the egg's upper titanium rune seam
    final upperRuneTarget = _eggPoint(0.36, 0.25);
    _paintLightningTendril(
      canvas,
      staffOrigin,
      upperRuneTarget,
      t: t,
      scale: scale * 0.78,
      primaryColor: _moltenAmber,
      coreColor: _hotFilament,
      jitterAmp: 7.2 * jitterScale,
      seed: 3.7,
      speedMult: isOvercharged ? 38.0 : 26.0,
    );

    // Lower crimson-violet tendril channeling into the egg's lower rune fissure
    final lowerRuneTarget = _eggPoint(0.32, 0.68);
    _paintLightningTendril(
      canvas,
      staffOrigin,
      lowerRuneTarget,
      t: t,
      scale: scale * 0.74,
      primaryColor: _crimsonCore,
      coreColor: _violetArcane,
      jitterAmp: 7.5 * jitterScale,
      seed: 6.2,
      speedMult: isOvercharged ? 40.0 : 28.0,
    );

    // 4. Weeks 10–39 Overcharged extra lightning arcs crackling tightly across the egg shell
    if (isOvercharged) {
      final rightUpper = _eggPoint(0.74, 0.30);
      final rightLower = _eggPoint(0.70, 0.72);
      _paintLightningTendril(
        canvas,
        eggEyeCenter,
        rightUpper,
        t: t,
        scale: scale * 0.68,
        primaryColor: _crimsonCore,
        coreColor: _moltenAmber,
        jitterAmp: 4.5,
        seed: 9.1,
        speedMult: 48.0,
      );
      _paintLightningTendril(
        canvas,
        upperRuneTarget,
        rightLower,
        t: t,
        scale: scale * 0.62,
        primaryColor: _violetArcane,
        coreColor: _hotFilament,
        jitterAmp: 5.0,
        seed: 11.8,
        speedMult: 52.0,
      );
    }
  }

  void _paintLightningTendril(
    Canvas canvas,
    Offset start,
    Offset end, {
    required double t,
    required double scale,
    required Color primaryColor,
    required Color coreColor,
    required double jitterAmp,
    required double seed,
    required double speedMult,
  }) {
    final delta = end - start;
    final len = delta.distance;
    if (len <= 1.0) return;

    const segments = 9;
    final perp = Offset(-delta.dy / len, delta.dx / len);
    final path = Path()..moveTo(start.dx, start.dy);

    for (int i = 1; i < segments; i++) {
      final f = i / segments;
      final env = math.sin(f * math.pi);
      final wave = math.sin(t * speedMult * math.pi + i * 2.35 + seed) +
          0.45 * math.cos(t * (speedMult * 1.4) * math.pi - i * 3.1 + seed);
      final offsetDist = wave * jitterAmp * scale * env * 0.72;
      path.lineTo(
        start.dx + delta.dx * f + perp.dx * offsetDist,
        start.dy + delta.dy * f + perp.dy * offsetDist,
      );
    }
    path.lineTo(end.dx, end.dy);

    final flicker = 0.68 + 0.32 * math.sin(t * 24.0 * math.pi + seed);
    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.62 * flicker)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = coreColor.withValues(alpha: 0.94 * flicker)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintRisingManaMotes(
    Canvas canvas, {
    required double t,
    required double scale,
    required double intensity,
    required bool isBackHalf,
  }) {
    final riseHeight = unit * 0.28;
    final orbitRx = unit * 0.145;

    for (final m in _manaMoteSpecs) {
      final cycle = (t * m.speed * (isOvercharged ? 1.5 : 1.0) + m.phase) % 1.0;
      final angle = _normalizeAngle(m.angleOffset + cycle * 1.6 * math.pi);
      final inBack = angle >= math.pi;
      if (inBack != isBackHalf) continue;

      final x = pedestalCenter.dx +
          math.cos(angle) * orbitRx * m.radiusFactor * (1.0 - 0.25 * cycle);
      final y = pedestalCenter.dy - cycle * riseHeight;
      final fade = math.sin(cycle * math.pi).clamp(0.0, 1.0);
      final alpha = (0.82 * fade * intensity.clamp(1.0, 1.2)).clamp(0.0, 1.0);
      if (alpha <= 0.03) continue;

      final color = switch (m.colorIdx) {
        0 => _violetArcane,
        1 => _crimsonCore,
        _ => _moltenAmber,
      };
      final pos = Offset(x, y);
      final r = m.size * scale;

      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = _hotFilament.withValues(alpha: alpha * 0.92),
      );
    }
  }

  void _paintTapResonanceBurst(Canvas canvas, double scale) {
    final u = Curves.easeOutCubic.transform(resonanceProgress.clamp(0.0, 1.0));
    final fade = ((1.0 - resonanceProgress) * (1.0 - resonanceProgress * 0.3))
        .clamp(0.0, 1.0);
    final center = eggRect.center;

    // 1. Primary expanding crimson-violet defensive shockwave ring
    final ringR = unit * (0.045 + 0.22 * u);
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..color = _violetArcane.withValues(alpha: 0.68 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (7.2 * (1.0 - 0.55 * u)) * scale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
    );
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..color = _crimsonCore.withValues(alpha: 0.95 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.4 * (1.0 - 0.45 * u)) * scale,
    );
    canvas.drawCircle(
      center,
      ringR * 0.96,
      Paint()
        ..color = _hotFilament.withValues(alpha: 0.72 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    // 2. Secondary harmonic molten-amber ripple ring
    if (resonanceProgress > 0.14) {
      final u2 = Curves.easeOutQuad.transform(
        ((resonanceProgress - 0.14) / 0.86).clamp(0.0, 1.0),
      );
      final fade2 = (1.0 - u2).clamp(0.0, 1.0);
      final ringR2 = unit * (0.032 + 0.175 * u2);
      canvas.drawCircle(
        center,
        ringR2,
        Paint()
          ..color = _moltenAmber.withValues(alpha: 0.62 * fade2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * scale,
      );
    }

    // 3. Blazing optical visor flare at the Titanium Robot Egg's red eye
    final flareEnv = math.sin(resonanceProgress * math.pi).clamp(0.0, 1.0);
    final burstR = eggRect.width * (0.28 + 0.36 * flareEnv);
    canvas.drawCircle(
      eggEyeCenter,
      burstR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * flareEnv),
            const Color(0xFFFF5252).withValues(alpha: 0.82 * flareEnv),
            _violetArcane.withValues(alpha: 0.46 * flareEnv),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: eggEyeCenter, radius: burstR)),
    );

    // Wide anamorphic crimson optical visor streak
    final streakHalfW = eggRect.width * (0.42 + 0.68 * flareEnv);
    canvas.drawLine(
      eggEyeCenter - Offset(streakHalfW, 0),
      eggEyeCenter + Offset(streakHalfW, 0),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _crimsonCore.withValues(alpha: 0.90 * flareEnv),
            Colors.white.withValues(alpha: 0.98 * flareEnv),
            _crimsonCore.withValues(alpha: 0.90 * flareEnv),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: eggEyeCenter,
            width: streakHalfW * 2.0,
            height: 5.0 * scale,
          ),
        )
        ..strokeWidth = (2.8 * flareEnv + 0.9) * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant EggEnchantmentPainter oldDelegate) {
    return oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.resonanceProgress != resonanceProgress ||
        oldDelegate.isOvercharged != isOvercharged ||
        oldDelegate.animationsEnabled != animationsEnabled ||
        oldDelegate.isFullScreen != isFullScreen ||
        oldDelegate.layer != layer ||
        oldDelegate.staffOrigin != staffOrigin ||
        oldDelegate.eggRect != eggRect ||
        oldDelegate.eggEyeCenter != eggEyeCenter ||
        oldDelegate.pedestalCenter != pedestalCenter ||
        oldDelegate.unit != unit;
  }
}

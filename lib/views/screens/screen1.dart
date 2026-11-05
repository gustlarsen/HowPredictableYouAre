import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/game_controller.dart';
import '../../services/localization_service.dart';

class Screen1 extends StatefulWidget {
  final GameController controller;

  const Screen1({
    super.key,
    required this.controller,
  });

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  int _lastAnimatedTick = 0;
  bool _isShowing100Dialog = false;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (controller.animation == 1 &&
        controller.animationTick != _lastAnimatedTick) {
      _lastAnimatedTick = controller.animationTick;
      _animController.forward(from: 0.0);
    }

    final alert = controller.consumeAlertMessage();
    if (alert != null && alert.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(alert),
              duration: const Duration(seconds: 2),
            ),
          );
      });
    }

    if (controller.show100RoundDialog && !_isShowing100Dialog) {
      _isShowing100Dialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _show100TurnCustomDialog();
        _isShowing100Dialog = false;
      });
    }
  }

  Future<void> _showHelpDialog() async {
    final rawMessage = controller.tr(34);
    final formattedMessage = rawMessage
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .trim();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(controller.tr(35, 'Help')),
        content: SingleChildScrollView(
          child: Text(formattedMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(controller.tr(36, 'Ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _show100TurnCustomDialog() async {
    final continueText = controller.tr(77, 'CONTINUE');
    final tryAgainText = controller.tr(76, 'TRY AGAIN');
    final selection = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.label100TurnText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              controller.labelEmojiWinLoseText,
              style: const TextStyle(fontSize: 50),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(tryAgainText),
            child: Text(tryAgainText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(continueText),
            child: Text(continueText),
          ),
        ],
      ),
    );
    await controller.handle100RoundDialogSelection(selection ?? continueText);
  }

  Widget _buildAnimatedHand({
    required Widget child,
    required bool isUserHand,
  }) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        if (controller.animation != 1 || !_animController.isAnimating) {
          return child;
        }
        final t = _animController.value;
        final outcome = controller.lastRoundOutcome;

        double dx = 0.0;
        double angle = 0.0;

        // Curve that lunges out in first half and returns in second half
        final lungeProgress = math.sin(t * math.pi);

        if (outcome == RoundOutcome.userWin) {
          if (isUserHand) {
            dx = 42.0 * lungeProgress;
          } else {
            angle = t * 2 * math.pi;
          }
        } else if (outcome == RoundOutcome.pcWin) {
          if (isUserHand) {
            angle = t * 2 * math.pi;
          } else {
            dx = -42.0 * lungeProgress;
          }
        } else if (outcome == RoundOutcome.draw) {
          angle = t * 2 * math.pi;
        }

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final fgColor = controller.textColor;
        final bgAsset = controller.backgroundImageAsset;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (controller.viewMode != ScreenViewMode.normal) {
              controller.navigateBackToNormal();
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: controller.screenBackgroundColor,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: bgAsset.isNotEmpty
                  ? BoxDecoration(
                      color: controller.screenBackgroundColor,
                      image: DecorationImage(
                        image: AssetImage(bgAsset),
                        fit: BoxFit.cover,
                      ),
                    )
                  : BoxDecoration(
                      color: controller.screenBackgroundColor,
                    ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopNavigationBar(fgColor),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: _buildActiveArrangement(context, fgColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// `Horizontal_Arrangement1` in `Screen1.scm`
  Widget _buildTopNavigationBar(Color fgColor) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (controller.buttonSecretVisible)
            TextButton(
              key: const Key('ButtonSecret'),
              onPressed: controller.onButtonSecretClick,
              child: Text(
                'DevMod',
                style: TextStyle(color: fgColor),
              ),
            ),
          if (controller.buttonGiftVisible)
            IconButton(
              key: const Key('ButtonGift'),
              onPressed: controller.onButtonGiftClick,
              icon: const Text(
                '🎁',
                style: TextStyle(fontSize: 22),
              ),
            ),
          if (controller.buttonHelpVisible)
            IconButton(
              key: const Key('ButtonHelp'),
              onPressed: _showHelpDialog,
              icon: Icon(Icons.help_outline, color: fgColor, size: 24),
              tooltip: controller.tr(35, 'Help'),
            ),
          if (controller.buttonAchievementsVisible)
            IconButton(
              key: const Key('ButtonAchievments'),
              onPressed: controller.openAchievements,
              icon: Icon(Icons.emoji_events, color: fgColor, size: 24),
              tooltip: controller.tr(60, 'Achievements'),
            ),
          if (controller.buttonShopVisible)
            IconButton(
              key: const Key('ButtonShop'),
              onPressed: controller.openShop,
              icon: Icon(Icons.shopping_cart, color: fgColor, size: 24),
              tooltip: 'Shop',
            ),
          if (controller.buttonSettingsVisible)
            IconButton(
              key: const Key('ButtonSettings'),
              onPressed: controller.openSettings,
              icon: Icon(Icons.settings, color: fgColor, size: 24),
              tooltip: 'Settings',
            ),
          if (controller.buttonSettingsBackVisible)
            SizedBox(
              width: 60,
              height: 45,
              child: IconButton(
                key: const Key('ButtonSettingsBack'),
                onPressed: controller.navigateBackToNormal,
                icon: Icon(Icons.keyboard_backspace, color: fgColor, size: 24),
                tooltip: 'Back',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveArrangement(BuildContext context, Color fgColor) {
    switch (controller.viewMode) {
      case ScreenViewMode.normal:
        return _buildNormalArrangement(context, fgColor);
      case ScreenViewMode.settings:
        return _buildSettingsArrangement(fgColor);
      case ScreenViewMode.shoppingCart:
        return _buildShoppingCartArrangement(fgColor);
      case ScreenViewMode.achievements:
        return _buildAchievementsArrangement(fgColor);
    }
  }

  /// `Vertical_ArrNormal` in `Screen1.scm`
  Widget _buildNormalArrangement(BuildContext context, Color fgColor) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final handImageHeight = math.max(64.0, screenHeight * 0.10);
    final textStyle = TextStyle(color: fgColor, fontSize: 14);
    final boldTextStyle = TextStyle(
      color: fgColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return Column(
      key: const Key('Vertical_ArrNormal'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Vertical_Arrangement2
        if (controller.isLabel100RoundsVisible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              controller.tr(1, 'Play at leat 100 rounds to see your Evaluation'),
              key: const Key('Label100Rouns'),
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(
                '${controller.tr(2, 'You are:')} ',
                key: const Key('Label2'),
                style: textStyle,
              ),
              Text(
                controller.evaluationText,
                key: const Key('LabelEvaluation'),
                style: boldTextStyle,
              ),
            ],
          ),
        ),

        // ScoreHorizArrangement_copy (Diamonds & Predictability Score)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                controller.tr(4, 'Diamonds:'),
                key: const Key('UserScoreLabel_copy'),
                style: textStyle,
              ),
              Text(
                '${controller.diamonds}',
                key: const Key('LabelDiamonds'),
                style: boldTextStyle,
              ),
              Text(
                '💎',
                key: const Key('LabelDiam_copy'),
                style: textStyle,
              ),
              if (controller.predictability > 1) ...[
                const SizedBox(width: 8),
                Row(
                  key: const Key('Horizontal_ArrangementPredictability'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${controller.tr(5, 'Predictability Score:')} ',
                      key: const Key('CompScoreLabel_copy'),
                      style: textStyle,
                    ),
                    Text(
                      controller.formattedPercentPredict,
                      key: const Key('LabelPredictability'),
                      style: boldTextStyle,
                    ),
                    Text(
                      '%',
                      key: const Key('PercentLabel'),
                      style: textStyle,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ScoreHorizArrangement (Your Score, PC Score, Total)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                controller.tr(6, 'Your Score:'),
                key: const Key('UserScoreLabel'),
                style: textStyle,
              ),
              Text(
                '${controller.userScore}',
                key: const Key('UserScore'),
                style: boldTextStyle,
              ),
              const SizedBox(width: 4),
              Text(
                controller.tr(7, 'PC Score:'),
                key: const Key('CompScoreLabel'),
                style: textStyle,
              ),
              Text(
                '${controller.pcScore}',
                key: const Key('CompScore'),
                style: boldTextStyle,
              ),
              const SizedBox(width: 4),
              Text(
                controller.tr(8, 'Total:'),
                key: const Key('TotalLabel'),
                style: textStyle,
              ),
              Text(
                '${controller.total}',
                key: const Key('Total'),
                style: boldTextStyle,
              ),
            ],
          ),
        ),

        // ChoiceHorizArrangement (You Chose / PC Chose)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                controller.tr(9, 'You Chose:'),
                key: const Key('UserLabel'),
                style: textStyle,
              ),
              Text(
                controller.userChoiceLabelText,
                key: const Key('UserChoiceLabel'),
                style: boldTextStyle,
              ),
              const SizedBox(width: 6),
              Text(
                controller.tr(52, 'PC Chose:'),
                key: const Key('CompLabel'),
                style: textStyle,
              ),
              Text(
                controller.compChoiceLabelText,
                key: const Key('CompChoiceLabel'),
                style: boldTextStyle,
              ),
            ],
          ),
        ),

        // ChoiceImageHorizArrangement (UserChoiceImage X CompChoiceImage)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: handImageHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAnimatedHand(
                  isUserHand: true,
                  child: Image.asset(
                    controller.userChoiceImageAsset,
                    key: const Key('UserChoiceImage'),
                    height: handImageHeight,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  'X',
                  key: const Key('Label1'),
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 20),
                _buildAnimatedHand(
                  isUserHand: false,
                  child: Image.asset(
                    controller.compChoiceImageAsset,
                    key: const Key('CompChoiceImage'),
                    height: handImageHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),

        // WinnerHorizArrangement
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                controller.tr(10, 'The winner of this round:'),
                key: const Key('WinnerTitleLabel'),
                style: textStyle,
              ),
              Text(
                controller.winner,
                key: const Key('WinnerLabel'),
                style: boldTextStyle,
              ),
            ],
          ),
        ),

        // Vertical_ArrangementMarkovVert (Markov Transition Matrix)
        if (controller.algorithm > 1)
          Padding(
            key: const Key('Vertical_ArrangementMarkovVert'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(
                  controller.tr(11, 'Markov Transition Matrix'),
                  key: const Key('MarkovLabel'),
                  textAlign: TextAlign.center,
                  style: boldTextStyle,
                ),
                const SizedBox(height: 4),
                _buildMarkovTable3x3(fgColor),
              ],
            ),
          ),

        // Horizontal_ArrangementYourPrediction
        if (controller.yourPrediction > 1)
          Padding(
            key: const Key('Horizontal_ArrangementYourPrediction'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                Text(
                  controller.tr(12, 'Probably you will Chose:'),
                  key: const Key('PredictionLabel'),
                  style: textStyle,
                ),
                Text(
                  controller.yourPredictionValue,
                  key: const Key('YourPrediction'),
                  style: boldTextStyle,
                ),
              ],
            ),
          ),

        // Horizontal_ArrangementPCNextRound
        if (controller.nextMove > 1)
          Padding(
            key: const Key('Horizontal_ArrangementPCNextRound'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                Text(
                  controller.tr(13, 'PC will Chose:'),
                  key: const Key('CompLabel2'),
                  style: textStyle,
                ),
                Text(
                  controller.pcNextMove,
                  key: const Key('LabelPCNextMove'),
                  style: boldTextStyle,
                ),
              ],
            ),
          ),

        // Horizontal_ArrangementSugestion
        if (controller.sugestion > 1)
          Padding(
            key: const Key('Horizontal_ArrangementSugestion'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                Text(
                  controller.tr(14, 'Sugestion:'),
                  key: const Key('SugestLabel'),
                  style: textStyle,
                ),
                Text(
                  controller.sugestionValue,
                  key: const Key('Sugestion'),
                  style: boldTextStyle,
                ),
              ],
            ),
          ),

        // Vertical_Arrangement1 (Action & Hand Buttons)
        const SizedBox(height: 8),
        if (controller.reset > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ElevatedButton(
              key: const Key('ResetButton'),
              onPressed: controller.resetGame,
              child: Text(controller.tr(53, 'RESET')),
            ),
          ),
        if (controller.newHands > 1)
          Padding(
            key: const Key('Horizontal_ArrangementNewHands'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                ElevatedButton(
                  key: const Key('ButtonSpock'),
                  onPressed: () => controller.playRound(5),
                  child: Text(controller.tr(69, 'SPOCK')),
                ),
                ElevatedButton(
                  key: const Key('ButtonLizard'),
                  onPressed: () => controller.playRound(6),
                  child: Text(controller.tr(68, 'LIZARD')),
                ),
              ],
            ),
          ),
        Wrap(
          key: const Key('UserButtonHorizArrangement'),
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              key: const Key('RockButton'),
              onPressed: () => controller.playRound(1),
              child: Text(controller.tr(17, 'ROCK')),
            ),
            ElevatedButton(
              key: const Key('PaperButton'),
              onPressed: () => controller.playRound(2),
              child: Text(controller.tr(18, 'PAPER')),
            ),
            ElevatedButton(
              key: const Key('ScissorsButton'),
              onPressed: () => controller.playRound(3),
              child: Text(controller.tr(19, 'SCISSORS')),
            ),
            if (controller.random > 1)
              ElevatedButton(
                key: const Key('ButtonRandom'),
                onPressed: () => controller.playRound(4),
                child: Text(controller.tr(16, 'RANDOM')),
              ),
          ],
        ),
      ],
    );
  }

  /// `Table_Arrangement1` (4x4 table for 3x3 Markov Matrix)
  Widget _buildMarkovTable3x3(Color fgColor) {
    final m = controller.markovEngine.matrix;
    final cellStyle = TextStyle(color: fgColor, fontSize: 14);

    Widget cell(String text, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            key: key,
            textAlign: TextAlign.center,
            style: cellStyle,
          ),
        );

    return Table(
      key: const Key('Table_Arrangement1'),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(
          children: [
            cell(''),
            cell('👊', key: const Key('Label4')),
            cell('🖐', key: const Key('Label5')),
            cell('✌', key: const Key('Label6')),
          ],
        ),
        TableRow(
          children: [
            cell('👊', key: const Key('Label7')),
            cell('${m[0][0]}', key: const Key('Label00')),
            cell('${m[0][1]}', key: const Key('Label01')),
            cell('${m[0][2]}', key: const Key('Label02')),
          ],
        ),
        TableRow(
          children: [
            cell('🖐', key: const Key('Label8')),
            cell('${m[1][0]}', key: const Key('Label10')),
            cell('${m[1][1]}', key: const Key('Label11')),
            cell('${m[1][2]}', key: const Key('Label12')),
          ],
        ),
        TableRow(
          children: [
            cell('✌', key: const Key('Label9')),
            cell('${m[2][0]}', key: const Key('Label20')),
            cell('${m[2][1]}', key: const Key('Label21')),
            cell('${m[2][2]}', key: const Key('Label22')),
          ],
        ),
      ],
    );
  }

  /// `Vertical_ArrSettings` in `Screen1.scm`
  Widget _buildSettingsArrangement(Color fgColor) {
    final textStyle = TextStyle(color: fgColor, fontSize: 15);
    return Column(
      key: const Key('Vertical_ArrSettings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal_ArrangementLanguage
        Row(
          children: [
            Text(
              '${controller.tr(55, 'Language:')} ',
              key: const Key('Label3_copy'),
              style: textStyle,
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              key: const Key('SpinnerLanguage'),
              value: controller.spinnerLanguageSelection,
              dropdownColor:
                  controller.darkMode == 1 ? Colors.grey[900] : Colors.white,
              style: textStyle,
              items: LocalizationService.spinnerElements
                  .map(
                    (el) => DropdownMenuItem<String>(
                      value: el,
                      child: Text(el),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  controller.selectLanguageFromSpinner(val);
                }
              },
            ),
          ],
        ),

        // Horizontal_ArrangementAnimations
        Row(
          children: [
            Text(
              controller.tr(78, 'Animations: '),
              key: const Key('Label250'),
              style: textStyle,
            ),
            Checkbox(
              key: const Key('Checkbox_Animations'),
              value: controller.animation == 1,
              side: BorderSide(color: fgColor),
              onChanged: (val) {
                if (val != null) {
                  controller.toggleAnimations(val);
                }
              },
            ),
            Text(
              controller.animation == 1
                  ? controller.tr(49, 'Enabled')
                  : controller.tr(48, 'Disabled'),
              style: textStyle,
            ),
          ],
        ),

        // Horizontal_ArrangementDarkMode
        Row(
          children: [
            Text(
              controller.tr(54, 'Dark Mode:'),
              key: const Key('Label3'),
              style: textStyle,
            ),
            Checkbox(
              key: const Key('Checkbox_DarkMode'),
              value: controller.darkMode == 1,
              side: BorderSide(color: fgColor),
              onChanged: (val) {
                if (val != null) {
                  controller.updateDarkMode(val);
                }
              },
            ),
            Text(
              controller.darkMode == 1
                  ? controller.tr(49, 'Enabled')
                  : controller.tr(48, 'Disabled'),
              style: textStyle,
            ),
          ],
        ),

        const SizedBox(height: 8),
        // ButtonMusic
        IconButton(
          key: const Key('ButtonMusic'),
          onPressed: controller.toggleMusic,
          icon: Icon(
            controller.music == 1 ? Icons.volume_up : Icons.volume_off,
            color: fgColor,
            size: 28,
          ),
        ),

        // ButtonVibration
        IconButton(
          key: const Key('ButtonVibration'),
          onPressed: controller.toggleVibration,
          icon: Icon(
            controller.vibration == 1 ? Icons.vibration : Icons.highlight_off,
            color: fgColor,
            size: 28,
          ),
        ),
      ],
    );
  }

  /// `Vertical_ArrShoppingCart` in `Screen1.scm`
  Widget _buildShoppingCartArrangement(Color fgColor) {
    final textStyle = TextStyle(color: fgColor, fontSize: 14);
    return Column(
      key: const Key('Vertical_ArrShoppingCart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal_Arrangement8 (Diamonds balance)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(
                '${controller.tr(4, 'Diamonds:')} ',
                key: const Key('Label23'),
                style: textStyle,
              ),
              Text(
                '${controller.diamonds}',
                key: const Key('LabelDiamonds2'),
                style: textStyle.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                ' 💎',
                key: const Key('Label24'),
                style: textStyle,
              ),
            ],
          ),
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25'),
          labelText: controller.tr(37, 'Reset Button'),
          stateValue: controller.reset,
          checkboxKey: const Key('CheckboxReset'),
          onCheckboxChanged: controller.toggleResetCheckbox,
          showPurchaseButton: true,
          purchaseButtonKey: const Key('ButtonPurchaseReset'),
          onPurchasePressed: controller.unlockReset,
          unlockButtonKey: const Key('ButtonUnlockReset'),
          unlockCostText: '100💎',
          onUnlockPressed: controller.unlockReset,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy'),
          labelText: controller.tr(38, 'Predictability Score'),
          stateValue: controller.predictability,
          checkboxKey: const Key('CheckboxPredictability'),
          onCheckboxChanged: controller.togglePredictabilityCheckbox,
          showPurchaseButton: true,
          purchaseButtonKey: const Key('ButtonPurchasePredictability'),
          onPurchasePressed: controller.unlockPredictability,
          unlockButtonKey: const Key('ButtonUnlockPredictability'),
          unlockCostText: '150💎',
          onUnlockPressed: controller.unlockPredictability,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy_copy11'),
          labelText: controller.tr(39, 'Random Button'),
          stateValue: controller.random,
          checkboxKey: const Key('CheckboxRandom'),
          onCheckboxChanged: controller.toggleRandomCheckbox,
          showPurchaseButton: true,
          purchaseButtonKey: const Key('ButtonPurchaseRandom'),
          onPurchasePressed: controller.unlockRandom,
          unlockButtonKey: const Key('ButtonUnlockRandom'),
          unlockCostText: '300💎',
          onUnlockPressed: controller.unlockRandom,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy_copy10'),
          labelText: controller.tr(40, 'Show Algorithm'),
          stateValue: controller.algorithm,
          checkboxKey: const Key('CheckboxAlgorithm'),
          onCheckboxChanged: controller.toggleAlgorithmCheckbox,
          showPurchaseButton: false,
          purchaseButtonKey: const Key('ButtonPurchaseAlgorithm'),
          onPurchasePressed: controller.purchaseAlgorithm,
          unlockButtonKey: const Key('ButtonUnlockAlgorithm'),
          unlockCostText: '500💎',
          onUnlockPressed: controller.unlockAlgorithm,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy_copy8'),
          labelText: controller.tr(41, 'Your Prediction'),
          stateValue: controller.yourPrediction,
          checkboxKey: const Key('CheckboxYourPrediction'),
          onCheckboxChanged: controller.toggleYourPredictionCheckbox,
          showPurchaseButton: false,
          purchaseButtonKey: const Key('ButtonPurchaseYourPrediction'),
          onPurchasePressed: controller.purchaseYourPrediction,
          unlockButtonKey: const Key('ButtonUnlockYourPrediction'),
          unlockCostText: '1000💎',
          onUnlockPressed: controller.unlockYourPrediction,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy_copy7'),
          labelText: controller.tr(42, 'PC Next Move'),
          stateValue: controller.nextMove,
          checkboxKey: const Key('CheckboxNextMove'),
          onCheckboxChanged: controller.toggleNextMoveCheckbox,
          showPurchaseButton: false,
          purchaseButtonKey: const Key('ButtonPurchaseNextMove'),
          onPurchasePressed: controller.purchaseNextMove,
          unlockButtonKey: const Key('ButtonUnlockNextMove'),
          unlockCostText: '3000💎',
          onUnlockPressed: controller.unlockNextMove,
        ),

        _buildShopItemRow(
          fgColor: fgColor,
          labelKey: const Key('Label25_copy_copy6'),
          labelText: controller.tr(43, 'Sugestion'),
          stateValue: controller.sugestion,
          checkboxKey: const Key('CheckboxSugestion'),
          onCheckboxChanged: controller.toggleSugestionCheckbox,
          showPurchaseButton: false,
          purchaseButtonKey: const Key('ButtonPurchaseSugestion'),
          onPurchasePressed: controller.purchaseSugestion,
          unlockButtonKey: const Key('ButtonUnlockSugestion'),
          unlockCostText: '5000💎',
          onUnlockPressed: controller.unlockSugestion,
        ),

        // Remove Ads row (Horizontal_Arrangement5_copy_copy4)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  controller.tr(44, 'Remove Ads'),
                  key: const Key('Label25_copy_copy4'),
                  style: textStyle,
                ),
              ),
              if (controller.ads == 0)
                ElevatedButton(
                  key: const Key('ButtonUnlockAds'),
                  onPressed: controller.unlockAds,
                  child: const Text('10000💎'),
                )
              else
                Text(
                  controller.tr(67, 'Ads Removed'),
                  key: const Key('LabelAdsRemoved'),
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),

        // Free Diamonds row (Horizontal_Arrangement5_copy_copy2)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  controller.tr(45, 'Free Diamonds'),
                  key: const Key('Label25_copy_copy2'),
                  style: textStyle,
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  ElevatedButton(
                    key: const Key('ButtonViewVideoAds'),
                    onPressed: () {},
                    child: Text(controller.tr(46, 'View Video')),
                  ),
                  ElevatedButton(
                    key: const Key('ButtonViewBannerAds'),
                    onPressed: () {},
                    child: Text(controller.tr(47, 'View Banner')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShopItemRow({
    required Color fgColor,
    required Key labelKey,
    required String labelText,
    required int stateValue,
    required Key checkboxKey,
    required ValueChanged<bool> onCheckboxChanged,
    required bool showPurchaseButton,
    required Key purchaseButtonKey,
    required VoidCallback onPurchasePressed,
    required Key unlockButtonKey,
    required String unlockCostText,
    required VoidCallback onUnlockPressed,
  }) {
    final textStyle = TextStyle(color: fgColor, fontSize: 14);
    final isUnlocked = stateValue > 0;
    final isEnabled = stateValue > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              labelText,
              key: labelKey,
              style: textStyle,
            ),
          ),
          if (isUnlocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  key: checkboxKey,
                  value: isEnabled,
                  side: BorderSide(color: fgColor),
                  onChanged: (val) {
                    if (val != null) {
                      onCheckboxChanged(val);
                    }
                  },
                ),
                Text(
                  isEnabled
                      ? controller.tr(49, 'Enabled')
                      : controller.tr(48, 'Disabled'),
                  style: textStyle,
                ),
              ],
            )
          else
            Wrap(
              spacing: 6,
              children: [
                if (showPurchaseButton)
                  ElevatedButton(
                    key: purchaseButtonKey,
                    onPressed: onPurchasePressed,
                    child: Text(controller.tr(61, 'Purchase')),
                  ),
                ElevatedButton(
                  key: unlockButtonKey,
                  onPressed: onUnlockPressed,
                  child: Text(unlockCostText),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// `Vertical_ArrAchiev` in `Screen1.scm`
  Widget _buildAchievementsArrangement(Color fgColor) {
    final textStyle = TextStyle(color: fgColor, fontSize: 14);
    return Column(
      key: const Key('Vertical_ArrAchiev'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Achievements',
            key: const Key('Label245'),
            textAlign: TextAlign.center,
            style: textStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Table(
          key: const Key('Table_Arrangement3'),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('Name', style: textStyle),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    controller.gamesName,
                    key: const Key('LabelGamesName'),
                    style: textStyle,
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('Id', style: textStyle),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    controller.gamesId,
                    key: const Key('LabelGamesId'),
                    style: textStyle,
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('Level', style: textStyle),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    controller.gamesLevel,
                    key: const Key('LabelGamesLevel'),
                    style: textStyle,
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('XP', style: textStyle),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    controller.gamesXp,
                    key: const Key('LabelGamesXP'),
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < 14; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text('100', style: textStyle),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('?'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}


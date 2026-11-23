import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/move.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyDiamondsIfNeeded();
  }

  /// Migrates legacy `diamonds` balance once into Elemental Orbs if the player
  /// had legacy diamonds > 0 and all 5 elemental orb counts are currently 0.
  Future<void> _migrateLegacyDiamondsIfNeeded() async {
    final legacy = _prefs.getInt('diamonds') ?? 0;
    if (legacy > 0 && totalOrbs == 0) {
      await setAllOrbs(
        fire: legacy,
        water: legacy,
        wood: legacy,
        earth: legacy,
        metal: legacy,
      );
      await _prefs.setInt('diamonds', 0);
      await _prefs.setBool('legacy_diamonds_migrated', true);
    }
  }

  // Elemental Orbs Inventory (Fire, Water, Wood, Earth, Metal)
  int get fireOrbs => _prefs.getInt('orbs_fire') ?? 0;
  Future<void> setFireOrbs(int val) => _prefs.setInt('orbs_fire', val);

  int get waterOrbs => _prefs.getInt('orbs_water') ?? 0;
  Future<void> setWaterOrbs(int val) => _prefs.setInt('orbs_water', val);

  int get woodOrbs => _prefs.getInt('orbs_wood') ?? 0;
  Future<void> setWoodOrbs(int val) => _prefs.setInt('orbs_wood', val);

  int get earthOrbs => _prefs.getInt('orbs_earth') ?? 0;
  Future<void> setEarthOrbs(int val) => _prefs.setInt('orbs_earth', val);

  int get metalOrbs => _prefs.getInt('orbs_metal') ?? 0;
  Future<void> setMetalOrbs(int val) => _prefs.setInt('orbs_metal', val);

  int get totalOrbs =>
      fireOrbs + waterOrbs + woodOrbs + earthOrbs + metalOrbs;

  Map<HandMove, int> get elementalOrbs => {
    HandMove.rock: fireOrbs,
    HandMove.paper: waterOrbs,
    HandMove.scissors: woodOrbs,
    HandMove.lizard: earthOrbs,
    HandMove.spock: metalOrbs,
  };

  int orbsFor(HandMove move) {
    switch (move) {
      case HandMove.rock:
        return fireOrbs;
      case HandMove.paper:
        return waterOrbs;
      case HandMove.scissors:
        return woodOrbs;
      case HandMove.lizard:
        return earthOrbs;
      case HandMove.spock:
        return metalOrbs;
    }
  }

  Future<void> setOrbsFor(HandMove move, int val) {
    switch (move) {
      case HandMove.rock:
        return setFireOrbs(val);
      case HandMove.paper:
        return setWaterOrbs(val);
      case HandMove.scissors:
        return setWoodOrbs(val);
      case HandMove.lizard:
        return setEarthOrbs(val);
      case HandMove.spock:
        return setMetalOrbs(val);
    }
  }

  Future<void> setAllOrbs({
    required int fire,
    required int water,
    required int wood,
    required int earth,
    required int metal,
  }) {
    return Future.wait([
      setFireOrbs(fire),
      setWaterOrbs(water),
      setWoodOrbs(wood),
      setEarthOrbs(earth),
      setMetalOrbs(metal),
    ]);
  }

  // Turn 0 Battle Baseline Orb Snapshot
  static const String _turn0FireKey = 'turn0_orbs_fire';
  static const String _turn0WaterKey = 'turn0_orbs_water';
  static const String _turn0WoodKey = 'turn0_orbs_wood';
  static const String _turn0EarthKey = 'turn0_orbs_earth';
  static const String _turn0MetalKey = 'turn0_orbs_metal';

  bool get hasTurn0OrbSnapshot =>
      _prefs.containsKey(_turn0FireKey) &&
      _prefs.containsKey(_turn0WaterKey) &&
      _prefs.containsKey(_turn0WoodKey) &&
      _prefs.containsKey(_turn0EarthKey) &&
      _prefs.containsKey(_turn0MetalKey);

  int get turn0FireOrbs => _prefs.getInt(_turn0FireKey) ?? fireOrbs;
  Future<void> setTurn0FireOrbs(int val) => _prefs.setInt(_turn0FireKey, val);

  int get turn0WaterOrbs => _prefs.getInt(_turn0WaterKey) ?? waterOrbs;
  Future<void> setTurn0WaterOrbs(int val) => _prefs.setInt(_turn0WaterKey, val);

  int get turn0WoodOrbs => _prefs.getInt(_turn0WoodKey) ?? woodOrbs;
  Future<void> setTurn0WoodOrbs(int val) => _prefs.setInt(_turn0WoodKey, val);

  int get turn0EarthOrbs => _prefs.getInt(_turn0EarthKey) ?? earthOrbs;
  Future<void> setTurn0EarthOrbs(int val) => _prefs.setInt(_turn0EarthKey, val);

  int get turn0MetalOrbs => _prefs.getInt(_turn0MetalKey) ?? metalOrbs;
  Future<void> setTurn0MetalOrbs(int val) => _prefs.setInt(_turn0MetalKey, val);

  Future<void> setTurn0Orbs({
    required int fire,
    required int water,
    required int wood,
    required int earth,
    required int metal,
  }) {
    return Future.wait([
      setTurn0FireOrbs(fire),
      setTurn0WaterOrbs(water),
      setTurn0WoodOrbs(wood),
      setTurn0EarthOrbs(earth),
      setTurn0MetalOrbs(metal),
    ]);
  }

  Future<void> clearTurn0Orbs() {
    return Future.wait([
      _prefs.remove(_turn0FireKey),
      _prefs.remove(_turn0WaterKey),
      _prefs.remove(_turn0WoodKey),
      _prefs.remove(_turn0EarthKey),
      _prefs.remove(_turn0MetalKey),
    ]);
  }

  // Legacy diamond key accessor (used only for one-time legacy save migration)
  int get legacyDiamonds => _prefs.getInt('diamonds') ?? 0;
  Future<void> clearLegacyDiamonds() => _prefs.setInt('diamonds', 0);

  // QA Tester Bonus Persistence
  bool get hasClaimedQaBonus => _prefs.getBool('hasClaimedQaBonus') ?? false;
  Future<void> setHasClaimedQaBonus(bool val) =>
      _prefs.setBool('hasClaimedQaBonus', val);

  static const String placeholderPlayerId = 'GPG-PLAYER';

  /// Returns true only when [id] is a real, non-empty Google Play Games
  /// player ID and not the legacy placeholder (`GPG-PLAYER`).
  static bool isValidPlayerId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toUpperCase() == placeholderPlayerId) return false;
    return true;
  }

  // Last Signed-In Google Play Games Player ID
  String? get lastPlayerId {
    final raw = _prefs.getString('last_player_id');
    if (!isValidPlayerId(raw)) return null;
    return raw!.trim();
  }

  Future<void> setLastPlayerId(String? id) {
    if (!isValidPlayerId(id)) {
      return _prefs.remove('last_player_id');
    }
    return _prefs.setString('last_player_id', id!.trim());
  }

  int get userScore => _prefs.getInt('userScore') ?? 0;
  Future<void> setUserScore(int val) => _prefs.setInt('userScore', val);

  int get pcScore => _prefs.getInt('pcScore') ?? 0;
  Future<void> setPcScore(int val) => _prefs.setInt('pcScore', val);

  int get total => _prefs.getInt('total') ?? 0;
  Future<void> setTotal(int val) => _prefs.setInt('total', val);

  // RPG Hand HP (Player base 50 + upgrades; PC 100)
  int get userHp => _prefs.getInt('userHp') ?? 50;
  int? get userHpRaw => _prefs.getInt('userHp');
  Future<void> setUserHp(int val) => _prefs.setInt('userHp', val);

  int get pcHp => _prefs.getInt('pcHp') ?? 100;
  int? get pcHpRaw => _prefs.getInt('pcHp');
  Future<void> setPcHp(int val) => _prefs.setInt('pcHp', val);

  // Boss Stage Progression (1 = Guardian Robot, 2 = Robot Archmage, 3 = Metal Wizard, 4 = Baby Mage Robot)
  static const String enemyStageKey = 'enemy_stage';
  static const String enemyPhaseKey = 'enemy_phase';
  static const String enemyMaxHpKey = 'enemy_max_hp';

  int get enemyStage {
    final raw =
        _prefs.getInt(enemyStageKey) ?? _prefs.getInt(enemyPhaseKey) ?? 1;
    if (raw < 1) return 1;
    if (raw > 4) return 4;
    return raw;
  }

  Future<void> setEnemyStage(int val) {
    final clamped = val.clamp(1, 4);
    return Future.wait([
      _prefs.setInt(enemyStageKey, clamped),
      _prefs.setInt(enemyPhaseKey, clamped),
    ]);
  }

  int get enemyPhase => enemyStage;
  Future<void> setEnemyPhase(int val) => setEnemyStage(val);

  int get enemyMaxHp {
    final raw = _prefs.getInt(enemyMaxHpKey);
    if (raw != null && raw > 0) return raw;
    switch (enemyStage) {
      case 2:
        return 200;
      case 3:
        return 300;
      case 4:
        return 400;
      default:
        return 100;
    }
  }

  int? get enemyMaxHpRaw => _prefs.getInt(enemyMaxHpKey);
  Future<void> setEnemyMaxHp(int val) =>
      _prefs.setInt(enemyMaxHpKey, val < 1 ? 100 : val);

  // Cleric Infinite Stat Upgrades & Hall of Heroes All-Time Peaks
  static const String _hpUpgradeLevelKey = 'hp_upgrade_level';
  static const String _manaUpgradeLevelKey = 'mana_upgrade_level';
  static const String _peakHpUpgradeLevelKey = 'peak_hp_upgrade_level';
  static const String _peakManaUpgradeLevelKey = 'peak_mana_upgrade_level';
  static const String _hallOfHeroesClaimAvailableKey =
      'hall_of_heroes_claim_available';
  static const String _legacyHallHpKey = 'hall_of_heroes_hp_bonus';
  static const String _legacyHallManaKey = 'hall_of_heroes_mana_bonus';

  int get hpUpgradeLevel {
    final val = _prefs.getInt(_hpUpgradeLevelKey) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> setHpUpgradeLevel(int val) =>
      _prefs.setInt(_hpUpgradeLevelKey, val < 0 ? 0 : val);

  int get manaUpgradeLevel {
    final val = _prefs.getInt(_manaUpgradeLevelKey) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> setManaUpgradeLevel(int val) =>
      _prefs.setInt(_manaUpgradeLevelKey, val < 0 ? 0 : val);

  int get peakHpUpgradeLevel {
    final val = _prefs.getInt(_peakHpUpgradeLevelKey) ??
        _prefs.getInt(_legacyHallHpKey) ??
        0;
    return val < 0 ? 0 : val;
  }

  Future<void> setPeakHpUpgradeLevel(int val) => Future.wait([
        _prefs.setInt(_peakHpUpgradeLevelKey, val < 0 ? 0 : val),
        _prefs.remove(_legacyHallHpKey),
      ]);

  int get peakManaUpgradeLevel {
    final val = _prefs.getInt(_peakManaUpgradeLevelKey) ??
        _prefs.getInt(_legacyHallManaKey) ??
        0;
    return val < 0 ? 0 : val;
  }

  Future<void> setPeakManaUpgradeLevel(int val) => Future.wait([
        _prefs.setInt(_peakManaUpgradeLevelKey, val < 0 ? 0 : val),
        _prefs.remove(_legacyHallManaKey),
      ]);

  bool get hallOfHeroesClaimAvailable {
    final stored = _prefs.getBool(_hallOfHeroesClaimAvailableKey);
    if (stored != null) return stored;
    return (_prefs.getInt(_legacyHallHpKey) ?? 0) > 0 ||
        (_prefs.getInt(_legacyHallManaKey) ?? 0) > 0;
  }

  Future<void> setHallOfHeroesClaimAvailable(bool val) =>
      _prefs.setBool(_hallOfHeroesClaimAvailableKey, val);

  // Campaign Week Calendar (always starts at Week 0)
  static const String currentWeekKey = 'current_week';
  int get currentWeek {
    final val = _prefs.getInt(currentWeekKey) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> setCurrentWeek(int val) =>
      _prefs.setInt(currentWeekKey, val < 0 ? 0 : val);

  // Post-Week-0 Scream Warning Modal Persistence Flags (per-campaign)
  static const String hasShownWeek0ScreamWarningKey =
      'has_shown_week0_scream_warning';
  static const String pendingWeek0ScreamWarningKey =
      'pending_week0_scream_warning';

  bool get hasShownWeek0ScreamWarning =>
      _prefs.getBool(hasShownWeek0ScreamWarningKey) ?? false;
  Future<void> setHasShownWeek0ScreamWarning(bool val) =>
      _prefs.setBool(hasShownWeek0ScreamWarningKey, val);

  bool get pendingWeek0ScreamWarning =>
      _prefs.getBool(pendingWeek0ScreamWarningKey) ?? false;
  Future<void> setPendingWeek0ScreamWarning(bool val) =>
      _prefs.setBool(pendingWeek0ScreamWarningKey, val);

  // Sacred Temple Consagration Weekly Ad Cap & Prayer Room Sacred Blessings
  static const String _adConsagrationsThisWeekKey =
      'ad_consagrations_this_week';
  static const String _pendingBattleBlessingKey = 'pending_battle_blessing';
  static const String _activeBattleBlessingKey = 'active_battle_blessing';
  static const String _battleBonusTempHpKey = 'battle_bonus_temp_hp';
  static const String _lastFreeDailyPrayerDateKey =
      'last_free_daily_prayer_date';

  int get adConsagrationsThisWeek {
    final val = _prefs.getInt(_adConsagrationsThisWeekKey) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> setAdConsagrationsThisWeek(int val) =>
      _prefs.setInt(_adConsagrationsThisWeekKey, val < 0 ? 0 : val);

  String? get pendingBattleBlessing {
    final raw = _prefs.getString(_pendingBattleBlessingKey)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> setPendingBattleBlessing(String? id) {
    final clean = id?.trim();
    if (clean == null || clean.isEmpty) {
      return _prefs.remove(_pendingBattleBlessingKey);
    }
    return _prefs.setString(_pendingBattleBlessingKey, clean);
  }

  String? get activeBattleBlessing {
    final raw = _prefs.getString(_activeBattleBlessingKey)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> setActiveBattleBlessing(String? id) {
    final clean = id?.trim();
    if (clean == null || clean.isEmpty) {
      return _prefs.remove(_activeBattleBlessingKey);
    }
    return _prefs.setString(_activeBattleBlessingKey, clean);
  }

  int get battleBonusTempHp {
    final val = _prefs.getInt(_battleBonusTempHpKey) ?? 0;
    return val < 0 ? 0 : val;
  }

  Future<void> setBattleBonusTempHp(int val) =>
      _prefs.setInt(_battleBonusTempHpKey, val < 0 ? 0 : val);

  String? get lastFreeDailyPrayerDate {
    final raw = _prefs.getString(_lastFreeDailyPrayerDateKey)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> setLastFreeDailyPrayerDate(String? dateKey) {
    final clean = dateKey?.trim();
    if (clean == null || clean.isEmpty) {
      return _prefs.remove(_lastFreeDailyPrayerDateKey);
    }
    return _prefs.setString(_lastFreeDailyPrayerDateKey, clean);
  }

  // Persisted Real-Money Google Play IAP Product IDs (survives Permadeath Reset)
  static const String purchasedIapProductIdsKey = 'iap_purchased_product_ids';

  Set<String> get purchasedIapProductIds {
    final list = _prefs.getStringList(purchasedIapProductIdsKey);
    if (list == null) return <String>{};
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> addPurchasedIapProductId(String productId) {
    final clean = productId.trim();
    if (clean.isEmpty) return Future.value();
    final updated = {...purchasedIapProductIds, clean};
    return setPurchasedIapProductIds(updated);
  }

  Future<void> setPurchasedIapProductIds(Set<String> productIds) {
    final sorted =
        productIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _prefs.setStringList(purchasedIapProductIdsKey, sorted);
  }

  // Settings
  bool get darkMode => _prefs.getBool('darkMode') ?? true;
  Future<void> setDarkMode(bool val) => _prefs.setBool('darkMode', val);

  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  Future<void> setSoundEnabled(bool val) => _prefs.setBool('soundEnabled', val);

  bool get musicEnabled => _prefs.getBool('musicEnabled') ?? true;
  Future<void> setMusicEnabled(bool val) => _prefs.setBool('musicEnabled', val);

  bool get vibrationEnabled => _prefs.getBool('vibrationEnabled') ?? true;
  Future<void> setVibrationEnabled(bool val) =>
      _prefs.setBool('vibrationEnabled', val);

  bool get animationsEnabled => _prefs.getBool('animationsEnabled') ?? true;
  Future<void> setAnimationsEnabled(bool val) =>
      _prefs.setBool('animationsEnabled', val);

  String get language => _prefs.getString('language') ?? 'en';
  Future<void> setLanguage(String val) => _prefs.setString('language', val);

  // Battle Teleport confirmation preference (true = show confirmation dialog)
  static const String confirmBattleTeleportKey = 'confirm_battle_teleport';
  bool get confirmBattleTeleport =>
      _prefs.getBool(confirmBattleTeleportKey) ?? true;
  Future<void> setConfirmBattleTeleport(bool val) =>
      _prefs.setBool(confirmBattleTeleportKey, val);

  // Unlocks (Purchased in shop)
  bool get unlockedReset => _prefs.getBool('unlockedReset') ?? false;
  Future<void> setUnlockedReset(bool val) =>
      _prefs.setBool('unlockedReset', val);

  bool get unlockedPredictability =>
      _prefs.getBool('unlockedPredictability') ?? false;
  Future<void> setUnlockedPredictability(bool val) =>
      _prefs.setBool('unlockedPredictability', val);

  bool get unlockedRandom => _prefs.getBool('unlockedRandom') ?? false;
  Future<void> setUnlockedRandom(bool val) =>
      _prefs.setBool('unlockedRandom', val);

  bool get unlockedAlgorithm => _prefs.getBool('unlockedAlgorithm') ?? false;
  Future<void> setUnlockedAlgorithm(bool val) =>
      _prefs.setBool('unlockedAlgorithm', val);

  bool get unlockedNewHands => _prefs.getBool('unlockedNewHands') ?? false;
  Future<void> setUnlockedNewHands(bool val) =>
      _prefs.setBool('unlockedNewHands', val);

  bool get unlockedYourPrediction =>
      _prefs.getBool('unlockedYourPrediction') ?? false;
  Future<void> setUnlockedYourPrediction(bool val) =>
      _prefs.setBool('unlockedYourPrediction', val);

  bool get unlockedNextMove => _prefs.getBool('unlockedNextMove') ?? false;
  Future<void> setUnlockedNextMove(bool val) =>
      _prefs.setBool('unlockedNextMove', val);

  bool get unlockedSuggestion => _prefs.getBool('unlockedSuggestion') ?? false;
  Future<void> setUnlockedSuggestion(bool val) =>
      _prefs.setBool('unlockedSuggestion', val);

  bool get unlockedAds =>
      (_prefs.getBool('unlockedAds') ?? false) ||
      (_prefs.getBool('unlock_remove_ads') ?? false);
  Future<void> setUnlockedAds(bool val) async {
    await _prefs.setBool('unlockedAds', val);
    await _prefs.setBool('unlock_remove_ads', val);
  }

  bool get hasRemoveAdsEnabledPreference =>
      _prefs.containsKey('removeAdsEnabled');

  bool get removeAdsEnabled =>
      _prefs.getBool('removeAdsEnabled') ?? unlockedAds;
  Future<void> setRemoveAdsEnabled(bool val) =>
      _prefs.setBool('removeAdsEnabled', val);
  Future<void> clearRemoveAdsEnabledPreference() =>
      _prefs.remove('removeAdsEnabled');

  bool get unlockedNewSkin => _prefs.getBool('unlockedNewSkin') ?? false;
  Future<void> setUnlockedNewSkin(bool val) =>
      _prefs.setBool('unlockedNewSkin', val);

  bool get unlockedCrystalBall =>
      _prefs.getBool('unlockedCrystalBall') ?? false;
  Future<void> setUnlockedCrystalBall(bool val) =>
      _prefs.setBool('unlockedCrystalBall', val);

  bool get unlockedCrystalBallPlus =>
      _prefs.getBool('unlockedCrystalBallPlus') ?? false;
  Future<void> setUnlockedCrystalBallPlus(bool val) =>
      _prefs.setBool('unlockedCrystalBallPlus', val);

  bool get unlockedMarkovRecalibrator =>
      _prefs.getBool('unlockedMarkovRecalibrator') ?? false;
  Future<void> setUnlockedMarkovRecalibrator(bool val) =>
      _prefs.setBool('unlockedMarkovRecalibrator', val);

  // Feature Active Toggles
  bool get showCrystalBall => _prefs.getBool('showCrystalBall') ?? false;
  Future<void> setShowCrystalBall(bool val) =>
      _prefs.setBool('showCrystalBall', val);

  bool get showCrystalBallPlus =>
      _prefs.getBool('showCrystalBallPlus') ?? false;
  Future<void> setShowCrystalBallPlus(bool val) =>
      _prefs.setBool('showCrystalBallPlus', val);

  bool get crystalBallPlusSavedState =>
      _prefs.getBool('crystalBallPlusSavedState') ?? showCrystalBallPlus;
  Future<void> setCrystalBallPlusSavedState(bool val) =>
      _prefs.setBool('crystalBallPlusSavedState', val);
  bool get showPredictability =>
      _prefs.getBool('showPredictability') ?? false;
  Future<void> setShowPredictability(bool val) =>
      _prefs.setBool('showPredictability', val);

  bool get showAlgorithm => _prefs.getBool('showAlgorithm') ?? false;
  Future<void> setShowAlgorithm(bool val) =>
      _prefs.setBool('showAlgorithm', val);

  bool get showYourPrediction =>
      _prefs.getBool('showYourPrediction') ?? false;
  Future<void> setShowYourPrediction(bool val) =>
      _prefs.setBool('showYourPrediction', val);

  bool get showNextMove => _prefs.getBool('showNextMove') ?? false;
  Future<void> setShowNextMove(bool val) => _prefs.setBool('showNextMove', val);

  bool get showSuggestion => _prefs.getBool('showSuggestion') ?? false;
  Future<void> setShowSuggestion(bool val) =>
      _prefs.setBool('showSuggestion', val);

  bool get showNewHands => _prefs.getBool('showNewHands') ?? false;
  Future<void> setShowNewHands(bool val) => _prefs.setBool('showNewHands', val);

  bool get showNewSkin => _prefs.getBool('showNewSkin') ?? false;
  Future<void> setShowNewSkin(bool val) => _prefs.setBool('showNewSkin', val);

  bool get showRandom => _prefs.getBool('showRandom') ?? false;
  Future<void> setShowRandom(bool val) => _prefs.setBool('showRandom', val);

  bool get showReset => _prefs.getBool('showReset') ?? false;
  Future<void> setShowReset(bool val) => _prefs.setBool('showReset', val);

  bool get showMarkovRecalibrator =>
      _prefs.getBool('showMarkovRecalibrator') ?? false;
  Future<void> setShowMarkovRecalibrator(bool val) =>
      _prefs.setBool('showMarkovRecalibrator', val);

  bool get giftBoxUnlocked => _prefs.getBool('giftBoxUnlocked') ?? false;
  Future<void> setGiftBoxUnlocked(bool val) =>
      _prefs.setBool('giftBoxUnlocked', val);

  bool get giftBoxEnabled => _prefs.getBool('giftBoxEnabled') ?? false;
  Future<void> setGiftBoxEnabled(bool val) =>
      _prefs.setBool('giftBoxEnabled', val);

  // Overcharged Staff Tiered Upgrade & Speed Persistence
  static const String overchargedStaffLevelKey = 'overcharged_staff_level';
  static const String overchargedStaffEnabledKey = 'overcharged_staff_enabled';
  static const String overchargedStaffSelectedSpeedKey =
      'overcharged_staff_selected_speed';

  int get overchargedStaffLevel {
    final val = _prefs.getInt(overchargedStaffLevelKey) ?? 0;
    return val.clamp(0, 6);
  }

  Future<void> setOverchargedStaffLevel(int val) =>
      _prefs.setInt(overchargedStaffLevelKey, val.clamp(0, 6));

  bool get overchargedStaffEnabled =>
      _prefs.getBool(overchargedStaffEnabledKey) ?? false;

  Future<void> setOverchargedStaffEnabled(bool val) =>
      _prefs.setBool(overchargedStaffEnabledKey, val);

  int get overchargedStaffSelectedSpeed {
    final val = _prefs.getInt(overchargedStaffSelectedSpeedKey) ?? 1;
    if (val == 1 ||
        val == 2 ||
        val == 5 ||
        val == 10 ||
        val == 20 ||
        val == 30) {
      return val;
    }
    return 1;
  }

  Future<void> setOverchargedStaffSelectedSpeed(int val) {
    final sanitized = (val == 1 ||
            val == 2 ||
            val == 5 ||
            val == 10 ||
            val == 20 ||
            val == 30)
        ? val
        : 1;
    return _prefs.setInt(overchargedStaffSelectedSpeedKey, sanitized);
  }

  // Story Cutscene Persistence Flags
  bool get hasSeenStoryIntro =>
      _prefs.getBool('has_seen_story_intro') ?? false;
  Future<void> setHasSeenStoryIntro(bool val) =>
      _prefs.setBool('has_seen_story_intro', val);

  bool get hasSeenIntro => hasSeenStoryIntro;
  Future<void> setHasSeenIntro(bool val) => setHasSeenStoryIntro(val);

  bool get hasSeenStoryReset =>
      _prefs.getBool('has_seen_story_reset') ?? false;
  Future<void> setHasSeenStoryReset(bool val) =>
      _prefs.setBool('has_seen_story_reset', val);

  bool get hasSeenStoryPredictability =>
      _prefs.getBool('has_seen_story_predictability') ?? false;
  Future<void> setHasSeenStoryPredictability(bool val) =>
      _prefs.setBool('has_seen_story_predictability', val);

  bool get hasSeenStoryRandom =>
      _prefs.getBool('has_seen_story_random') ?? false;
  Future<void> setHasSeenStoryRandom(bool val) =>
      _prefs.setBool('has_seen_story_random', val);

  bool get hasSeenStoryAlgorithm =>
      _prefs.getBool('has_seen_story_algorithm') ?? false;
  Future<void> setHasSeenStoryAlgorithm(bool val) =>
      _prefs.setBool('has_seen_story_algorithm', val);

  bool get hasSeenStoryYourPrediction =>
      _prefs.getBool('has_seen_story_your_prediction') ?? false;
  Future<void> setHasSeenStoryYourPrediction(bool val) =>
      _prefs.setBool('has_seen_story_your_prediction', val);

  bool get hasSeenStoryPcNextMove =>
      _prefs.getBool('has_seen_story_pc_next_move') ?? false;
  Future<void> setHasSeenStoryPcNextMove(bool val) =>
      _prefs.setBool('has_seen_story_pc_next_move', val);

  bool get hasSeenStorySuggestion =>
      _prefs.getBool('has_seen_story_suggestion') ?? false;
  Future<void> setHasSeenStorySuggestion(bool val) =>
      _prefs.setBool('has_seen_story_suggestion', val);

  bool get hasSeenStoryCrystalBall =>
      _prefs.getBool('has_seen_story_crystal_ball') ?? false;
  Future<void> setHasSeenStoryCrystalBall(bool val) =>
      _prefs.setBool('has_seen_story_crystal_ball', val);

  bool hasSeenStory(String prefsKey) => _prefs.getBool(prefsKey) ?? false;
  Future<void> setHasSeenStory(String prefsKey, bool val) =>
      _prefs.setBool(prefsKey, val);

  // Last Played Hands Persistence
  HandMove? get lastUserMove {
    final id = _prefs.getInt('last_user_move');
    if (id == null) return null;
    for (final move in HandMove.values) {
      if (move.id == id) return move;
    }
    return null;
  }

  Future<void> setLastUserMove(HandMove? move) {
    if (move == null) {
      return _prefs.remove('last_user_move');
    }
    return _prefs.setInt('last_user_move', move.id);
  }

  HandMove? get lastComputerMove {
    final id = _prefs.getInt('last_computer_move');
    if (id == null) return null;
    for (final move in HandMove.values) {
      if (move.id == id) return move;
    }
    return null;
  }

  Future<void> setLastComputerMove(HandMove? move) {
    if (move == null) {
      return _prefs.remove('last_computer_move');
    }
    return _prefs.setInt('last_computer_move', move.id);
  }

  // Markov Matrix Persistence
  List<List<int>>? getMarkovMatrix(int size) {
    final str = _prefs.getString('markov_matrix_$size');
    if (str == null) return null;
    try {
      final List<dynamic> decoded = json.decode(str);
      return decoded
          .map((row) => (row as List).map((v) => v as int).toList())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> setMarkovMatrix(List<List<int>> matrix) {
    final size = matrix.length;
    return _prefs.setString('markov_matrix_$size', json.encode(matrix));
  }

  Future<void> removeMarkovMatrix(int size) {
    return _prefs.remove('markov_matrix_$size');
  }

  static const String shortTermTransitionsKey = 'short_term_transitions';

  Map<int, int> get shortTermTransitions {
    final str = _prefs.getString(shortTermTransitionsKey);
    if (str == null || str.isEmpty) return const {};
    try {
      final decoded = json.decode(str);
      if (decoded is! Map) return const {};
      final result = <int, int>{};
      for (final entry in decoded.entries) {
        final k = int.tryParse(entry.key.toString());
        final v = (entry.value as num?)?.toInt();
        if (k != null && v != null) {
          result[k] = v;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<void> setShortTermTransitions(Map<int, int> transitions) {
    if (transitions.isEmpty) {
      return _prefs.remove(shortTermTransitionsKey);
    }
    final encoded = <String, int>{
      for (final entry in transitions.entries) '${entry.key}': entry.value,
    };
    return _prefs.setString(shortTermTransitionsKey, json.encode(encoded));
  }

  Future<void> removeShortTermTransitions() {
    return _prefs.remove(shortTermTransitionsKey);
  }

  // Royal Treasury Piggy Bank Orbs (shared vault capacity)
  static const int defaultTreasuryMaxCapacity = 200;
  static const int defaultTreasuryVaultLevel = 1;
  static const String _treasuryFireKey = 'treasury_orbs_fire';
  static const String _treasuryWaterKey = 'treasury_orbs_water';
  static const String _treasuryWoodKey = 'treasury_orbs_wood';
  static const String _treasuryEarthKey = 'treasury_orbs_earth';
  static const String _treasuryMetalKey = 'treasury_orbs_metal';
  static const String _treasuryMaxCapacityKey = 'treasury_max_capacity';
  static const String _treasuryVaultLevelKey = 'treasury_vault_level';
  static const String _treasuryEarthMetalBonusGrantedKey =
      'treasury_earth_metal_bonus_granted';

  int get treasuryFireOrbs => _prefs.getInt(_treasuryFireKey) ?? 0;
  Future<void> setTreasuryFireOrbs(int val) =>
      _prefs.setInt(_treasuryFireKey, val);

  int get treasuryWaterOrbs => _prefs.getInt(_treasuryWaterKey) ?? 0;
  Future<void> setTreasuryWaterOrbs(int val) =>
      _prefs.setInt(_treasuryWaterKey, val);

  int get treasuryWoodOrbs => _prefs.getInt(_treasuryWoodKey) ?? 0;
  Future<void> setTreasuryWoodOrbs(int val) =>
      _prefs.setInt(_treasuryWoodKey, val);

  int get treasuryEarthOrbs => _prefs.getInt(_treasuryEarthKey) ?? 0;
  Future<void> setTreasuryEarthOrbs(int val) =>
      _prefs.setInt(_treasuryEarthKey, val);

  int get treasuryMetalOrbs => _prefs.getInt(_treasuryMetalKey) ?? 0;
  Future<void> setTreasuryMetalOrbs(int val) =>
      _prefs.setInt(_treasuryMetalKey, val);

  int get treasuryMaxCapacity {
    final val = _prefs.getInt(_treasuryMaxCapacityKey);
    if (val == null || val < defaultTreasuryMaxCapacity) {
      return defaultTreasuryMaxCapacity;
    }
    return val;
  }

  Future<void> setTreasuryMaxCapacity(int val) => _prefs.setInt(
    _treasuryMaxCapacityKey,
    val < defaultTreasuryMaxCapacity ? defaultTreasuryMaxCapacity : val,
  );

  int get treasuryVaultLevel {
    final val = _prefs.getInt(_treasuryVaultLevelKey);
    if (val == null || val < defaultTreasuryVaultLevel) {
      return defaultTreasuryVaultLevel;
    }
    return val;
  }

  Future<void> setTreasuryVaultLevel(int val) => _prefs.setInt(
    _treasuryVaultLevelKey,
    val < defaultTreasuryVaultLevel ? defaultTreasuryVaultLevel : val,
  );

  bool get treasuryEarthMetalBonusGranted =>
      _prefs.getBool(_treasuryEarthMetalBonusGrantedKey) ?? false;

  Future<void> setTreasuryEarthMetalBonusGranted(bool val) =>
      _prefs.setBool(_treasuryEarthMetalBonusGrantedKey, val);

  Future<void> setAllTreasuryOrbs({
    required int fire,
    required int water,
    required int wood,
    required int earth,
    required int metal,
  }) {
    return Future.wait([
      setTreasuryFireOrbs(fire),
      setTreasuryWaterOrbs(water),
      setTreasuryWoodOrbs(wood),
      setTreasuryEarthOrbs(earth),
      setTreasuryMetalOrbs(metal),
    ]);
  }

  // Spoils of War Orbs (orbs lost on Turn 0 Reset or Campaign Defeat)
  static const String _spoilsFireKey = 'spoils_orbs_fire';
  static const String _spoilsWaterKey = 'spoils_orbs_water';
  static const String _spoilsWoodKey = 'spoils_orbs_wood';
  static const String _spoilsEarthKey = 'spoils_orbs_earth';
  static const String _spoilsMetalKey = 'spoils_orbs_metal';

  int get spoilsFireOrbs => _prefs.getInt(_spoilsFireKey) ?? 0;
  Future<void> setSpoilsFireOrbs(int val) => _prefs.setInt(_spoilsFireKey, val);

  int get spoilsWaterOrbs => _prefs.getInt(_spoilsWaterKey) ?? 0;
  Future<void> setSpoilsWaterOrbs(int val) =>
      _prefs.setInt(_spoilsWaterKey, val);

  int get spoilsWoodOrbs => _prefs.getInt(_spoilsWoodKey) ?? 0;
  Future<void> setSpoilsWoodOrbs(int val) => _prefs.setInt(_spoilsWoodKey, val);

  int get spoilsEarthOrbs => _prefs.getInt(_spoilsEarthKey) ?? 0;
  Future<void> setSpoilsEarthOrbs(int val) =>
      _prefs.setInt(_spoilsEarthKey, val);

  int get spoilsMetalOrbs => _prefs.getInt(_spoilsMetalKey) ?? 0;
  Future<void> setSpoilsMetalOrbs(int val) =>
      _prefs.setInt(_spoilsMetalKey, val);

  Future<void> setAllSpoilsOrbs({
    required int fire,
    required int water,
    required int wood,
    required int earth,
    required int metal,
  }) {
    return Future.wait([
      setSpoilsFireOrbs(fire),
      setSpoilsWaterOrbs(water),
      setSpoilsWoodOrbs(wood),
      setSpoilsEarthOrbs(earth),
      setSpoilsMetalOrbs(metal),
    ]);
  }

  // Relic Chamber Stored Upgrades (snapshot of lost run's orb-bought upgrades)
  static const String _relicChamberUpgradesKey = 'relic_chamber_upgrades';

  List<String> get relicChamberUpgrades {
    final list = _prefs.getStringList(_relicChamberUpgradesKey);
    if (list == null) return const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> setRelicChamberUpgrades(List<String> upgrades) {
    final cleaned =
        upgrades
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _prefs.setStringList(_relicChamberUpgradesKey, cleaned);
  }

  // Royal Library: Narrative Endings & Markov Bestiary
  static const String _unlockedEndingsKey = 'unlocked_endings';
  static const String _encounteredBestiaryKey = 'encountered_bestiary';

  List<String> get unlockedEndings {
    final list = _prefs.getStringList(_unlockedEndingsKey);
    if (list == null) return const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> setUnlockedEndings(List<String> endings) {
    final cleaned =
        endings
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _prefs.setStringList(_unlockedEndingsKey, cleaned);
  }

  List<String> get encounteredBestiary {
    final list = _prefs.getStringList(_encounteredBestiaryKey);
    if (list == null) return const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> setEncounteredBestiary(List<String> creatures) {
    final cleaned =
        creatures
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _prefs.setStringList(_encounteredBestiaryKey, cleaned);
  }

  // Royal Decrees State
  static const String _activeDecreeIdsKey = 'royal_decrees_active_ids';
  static const String _completedCycleDecreeIdsKey =
      'royal_decrees_completed_cycle_ids';
  static const String _totalDecreesCompletedKey =
      'royal_decrees_total_completed';
  static const String _decreeNoRepeatWinsKey = 'decree_no_repeat_win_count';
  static const String _decreeWinStreakKey = 'decree_win_streak';
  static const String _decreeDefeatedElementsKey = 'decree_defeated_elements';

  List<String>? get activeDecreeIds {
    final list = _prefs.getStringList(_activeDecreeIdsKey);
    if (list == null || list.isEmpty) return null;
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> setActiveDecreeIds(List<String> ids) =>
      _prefs.setStringList(_activeDecreeIdsKey, ids);

  List<String> get completedCycleDecreeIds {
    final list = _prefs.getStringList(_completedCycleDecreeIdsKey);
    if (list == null) return const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> setCompletedCycleDecreeIds(List<String> ids) =>
      _prefs.setStringList(_completedCycleDecreeIdsKey, ids.toSet().toList());

  int get totalDecreesCompleted =>
      _prefs.getInt(_totalDecreesCompletedKey) ?? 0;
  Future<void> setTotalDecreesCompleted(int val) =>
      _prefs.setInt(_totalDecreesCompletedKey, val);

  int get decreeNoRepeatWinCount => _prefs.getInt(_decreeNoRepeatWinsKey) ?? 0;
  Future<void> setDecreeNoRepeatWinCount(int val) =>
      _prefs.setInt(_decreeNoRepeatWinsKey, val);

  int get decreeWinStreak => _prefs.getInt(_decreeWinStreakKey) ?? 0;
  Future<void> setDecreeWinStreak(int val) =>
      _prefs.setInt(_decreeWinStreakKey, val);

  List<String> get decreeDefeatedElements =>
      _prefs.getStringList(_decreeDefeatedElementsKey) ?? const [];
  Future<void> setDecreeDefeatedElements(List<String> elements) =>
      _prefs.setStringList(_decreeDefeatedElementsKey, elements.toSet().toList());

  Future<void> clearBattleDecreeProgress() {
    return Future.wait([
      setDecreeNoRepeatWinCount(0),
      setDecreeWinStreak(0),
      setDecreeDefeatedElements(const []),
      setCompletedCycleDecreeIds(const []),
    ]);
  }

  // Lifetime Account Chronicles & Run Statistics (never reset on cycle end; cleared only on account switch)
  static const String _totalCyclesCountKey = 'total_cycles_count';
  static const String _deathDefeatCountKey = 'death_defeat_count';
  static const String _timeoutDefeatCountKey = 'timeout_defeat_count';
  static const String _forfeitRunCountKey = 'forfeit_run_count';
  static const String _standardVictoryCountKey = 'standard_victory_count';
  static const String _secretVictoryCountKey = 'secret_victory_count';
  static const String _fastestVictoryWeekKey = 'fastest_victory_week';
  static const String _guardianRobotDefeatedCountKey =
      'guardian_robot_defeated_count';
  static const String _robotArchmageDefeatedCountKey =
      'robot_archmage_defeated_count';
  static const String _metalWizardDefeatedCountKey =
      'metal_wizard_defeated_count';
  static const String _babyMageRobotDefeatedCountKey =
      'baby_mage_robot_defeated_count';

  int _nonNegativeInt(String key) {
    final val = _prefs.getInt(key) ?? 0;
    return val < 0 ? 0 : val;
  }

  int get totalCyclesCount => _nonNegativeInt(_totalCyclesCountKey);
  Future<void> setTotalCyclesCount(int val) =>
      _prefs.setInt(_totalCyclesCountKey, val < 0 ? 0 : val);

  int get deathDefeatCount => _nonNegativeInt(_deathDefeatCountKey);
  Future<void> setDeathDefeatCount(int val) =>
      _prefs.setInt(_deathDefeatCountKey, val < 0 ? 0 : val);

  int get timeoutDefeatCount => _nonNegativeInt(_timeoutDefeatCountKey);
  Future<void> setTimeoutDefeatCount(int val) =>
      _prefs.setInt(_timeoutDefeatCountKey, val < 0 ? 0 : val);

  int get forfeitRunCount => _nonNegativeInt(_forfeitRunCountKey);
  Future<void> setForfeitRunCount(int val) =>
      _prefs.setInt(_forfeitRunCountKey, val < 0 ? 0 : val);

  int get standardVictoryCount => _nonNegativeInt(_standardVictoryCountKey);
  Future<void> setStandardVictoryCount(int val) =>
      _prefs.setInt(_standardVictoryCountKey, val < 0 ? 0 : val);

  int get secretVictoryCount => _nonNegativeInt(_secretVictoryCountKey);
  Future<void> setSecretVictoryCount(int val) =>
      _prefs.setInt(_secretVictoryCountKey, val < 0 ? 0 : val);

  int? get fastestVictoryWeek {
    final val = _prefs.getInt(_fastestVictoryWeekKey);
    if (val == null || val < 0) return null;
    return val;
  }

  Future<void> setFastestVictoryWeek(int? val) {
    if (val == null || val < 0) {
      return _prefs.remove(_fastestVictoryWeekKey);
    }
    return _prefs.setInt(_fastestVictoryWeekKey, val);
  }

  int get guardianRobotDefeatedCount =>
      _nonNegativeInt(_guardianRobotDefeatedCountKey);
  Future<void> setGuardianRobotDefeatedCount(int val) =>
      _prefs.setInt(_guardianRobotDefeatedCountKey, val < 0 ? 0 : val);

  int get robotArchmageDefeatedCount =>
      _nonNegativeInt(_robotArchmageDefeatedCountKey);
  Future<void> setRobotArchmageDefeatedCount(int val) =>
      _prefs.setInt(_robotArchmageDefeatedCountKey, val < 0 ? 0 : val);

  int get metalWizardDefeatedCount =>
      _nonNegativeInt(_metalWizardDefeatedCountKey);
  Future<void> setMetalWizardDefeatedCount(int val) =>
      _prefs.setInt(_metalWizardDefeatedCountKey, val < 0 ? 0 : val);

  int get babyMageRobotDefeatedCount =>
      _nonNegativeInt(_babyMageRobotDefeatedCountKey);
  Future<void> setBabyMageRobotDefeatedCount(int val) =>
      _prefs.setInt(_babyMageRobotDefeatedCountKey, val < 0 ? 0 : val);

  Future<void> clearAllCastleData() {
    return Future.wait([
      setAllTreasuryOrbs(fire: 0, water: 0, wood: 0, earth: 0, metal: 0),
      setTreasuryMaxCapacity(defaultTreasuryMaxCapacity),
      setTreasuryVaultLevel(defaultTreasuryVaultLevel),
      setTreasuryEarthMetalBonusGranted(false),
      setAllSpoilsOrbs(fire: 0, water: 0, wood: 0, earth: 0, metal: 0),
      setRelicChamberUpgrades(const []),
      setPeakHpUpgradeLevel(0),
      setPeakManaUpgradeLevel(0),
      setHallOfHeroesClaimAvailable(false),
      setUnlockedEndings(const []),
      setEncounteredBestiary(const []),
      _prefs.remove(_activeDecreeIdsKey),
      setTotalDecreesCompleted(0),
      setTotalCyclesCount(0),
      setDeathDefeatCount(0),
      setTimeoutDefeatCount(0),
      setForfeitRunCount(0),
      setStandardVictoryCount(0),
      setSecretVictoryCount(0),
      setFastestVictoryWeek(null),
      setGuardianRobotDefeatedCount(0),
      setRobotArchmageDefeatedCount(0),
      setMetalWizardDefeatedCount(0),
      setBabyMageRobotDefeatedCount(0),
      clearBattleDecreeProgress(),
    ]);
  }

  Future<void> clearGameStats({int userMaxHp = 50, int pcMaxHp = 100}) {
    return Future.wait([
      setUserScore(0),
      setPcScore(0),
      setTotal(0),
      setUserHp(userMaxHp),
      setPcHp(pcMaxHp),
      _prefs.remove('last_user_move'),
      _prefs.remove('last_computer_move'),
      _prefs.remove('markov_matrix_3'),
      _prefs.remove('markov_matrix_5'),
      removeShortTermTransitions(),
    ]);
  }

  /// Resets UI settings (language, dark mode, sound, music, vibration, animations)
  /// back to their default values.
  Future<void> resetSettingsToDefault() {
    return Future.wait([
      setLanguage('en'),
      setDarkMode(true),
      setSoundEnabled(true),
      setMusicEnabled(true),
      setVibrationEnabled(true),
      setAnimationsEnabled(true),
      setConfirmBattleTeleport(true),
    ]);
  }

  /// Wipes all local gameplay progression (elemental orbs, scores, shop unlocks,
  /// active toggles, story chapter flags, last moves, and Markov matrices).
  /// When [includeSettings] is true (e.g., on multi-account switch), also resets
  /// UI settings back to defaults so settings are isolated per account.
  /// When [includeCastleMeta] is true (e.g., full progress reset or account switch),
  /// also clears Castle Treasury, Relic Chamber, Spoils of War, Hall of Heroes,
  /// Endings, Bestiary, and Royal Decrees.
  Future<void> clearGameplayProgress({
    bool includeSettings = false,
    bool includeCastleMeta = false,
    bool preserveStoryFlags = false,
    bool? preserveRemoveAds,
  }) {
    final shouldPreserveRemoveAds = preserveRemoveAds ?? !includeCastleMeta;
    return Future.wait([
      if (includeSettings) resetSettingsToDefault(),
      if (includeCastleMeta) clearAllCastleData(),
      setConfirmBattleTeleport(true),
      setAllOrbs(fire: 0, water: 0, wood: 0, earth: 0, metal: 0),
      clearTurn0Orbs(),
      clearLegacyDiamonds(),
      setHasClaimedQaBonus(false),
      setUserScore(0),
      setPcScore(0),
      setTotal(0),
      setUserHp(50),
      setPcHp(100),
      setEnemyStage(1),
      setEnemyMaxHp(100),
      setHpUpgradeLevel(0),
      setManaUpgradeLevel(0),
      setCurrentWeek(0),
      setHasShownWeek0ScreamWarning(false),
      setPendingWeek0ScreamWarning(false),
      setAdConsagrationsThisWeek(0),
      setPendingBattleBlessing(null),
      setActiveBattleBlessing(null),
      setBattleBonusTempHp(0),
      setUnlockedReset(false),
      setUnlockedPredictability(false),
      setUnlockedRandom(false),
      setUnlockedAlgorithm(false),
      setUnlockedNewHands(false),
      setUnlockedYourPrediction(false),
      setUnlockedNextMove(false),
      setUnlockedSuggestion(false),
      if (!shouldPreserveRemoveAds) ...[
        setUnlockedAds(false),
        clearRemoveAdsEnabledPreference(),
      ],
      setUnlockedNewSkin(false),
      setUnlockedCrystalBall(false),
      setUnlockedCrystalBallPlus(false),
      setUnlockedMarkovRecalibrator(false),
      setGiftBoxUnlocked(false),
      setShowReset(false),
      setShowPredictability(false),
      setShowRandom(false),
      setShowAlgorithm(false),
      setShowNewHands(false),
      setShowNewSkin(false),
      setShowYourPrediction(false),
      setShowNextMove(false),
      setShowSuggestion(false),
      setShowCrystalBall(false),
      setShowCrystalBallPlus(false),
      setCrystalBallPlusSavedState(false),
      setShowMarkovRecalibrator(false),
      setGiftBoxEnabled(false),
      setOverchargedStaffLevel(0),
      setOverchargedStaffEnabled(false),
      setOverchargedStaffSelectedSpeed(1),
      if (!preserveStoryFlags) ...[
        setHasSeenStoryIntro(false),
        setHasSeenStoryReset(false),
        setHasSeenStoryPredictability(false),
        setHasSeenStoryRandom(false),
        setHasSeenStoryAlgorithm(false),
        setHasSeenStoryYourPrediction(false),
        setHasSeenStoryPcNextMove(false),
        setHasSeenStorySuggestion(false),
        setHasSeenStoryCrystalBall(false),
      ],
      _prefs.remove('last_user_move'),
      _prefs.remove('last_computer_move'),
      _prefs.remove('markov_matrix_3'),
      _prefs.remove('markov_matrix_5'),
      removeShortTermTransitions(),
    ]);
  }
}

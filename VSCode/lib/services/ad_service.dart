import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Abstraction over the Google Mobile Ads (`google_mobile_ads`) SDK so that
/// [AdService] uses the official AdMob SDK in production while remaining
/// deterministically testable in unit and widget tests.
abstract class AdMobClient {
  Future<void> initialize();

  Future<bool> isPrivacyOptionsRequired() async => false;

  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    onDismissed?.call(null);
  }

  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  });

  Widget? buildBannerWidget();

  void disposeBanner();

  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  });

  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  });

  void disposeRewarded();
}

/// Default production implementation of [AdMobClient] backed by
/// the official `google_mobile_ads` plugin (including UMP / GDPR consent APIs).
class DefaultAdMobClient implements AdMobClient {
  BannerAd? _bannerAd;
  RewardedAd? _rewardedAd;

  @override
  Future<void> initialize() async {
    final completer = Completer<void>();

    Future<void> initializeMobileAds() async {
      try {
        await MobileAds.instance.initialize();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    }

    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired(
              (FormError? formError) async {
                await initializeMobileAds();
              },
            );
          } catch (_) {
            await initializeMobileAds();
          }
        },
        (FormError error) async {
          await initializeMobileAds();
        },
      );
    } catch (_) {
      await initializeMobileAds();
    }

    return completer.future;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    await ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      onDismissed?.call(formError);
    });
  }

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    _bannerAd?.dispose();
    _bannerAd = null;

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (identical(_bannerAd, ad)) {
            _bannerAd = null;
          }
          onFailed();
        },
      ),
    );

    _bannerAd = banner;
    await banner.load();
  }

  @override
  Widget? buildBannerWidget() {
    final banner = _bannerAd;
    if (banner == null) return null;
    return AdWidget(ad: banner);
  }

  @override
  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          onLoaded();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          onFailed();
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) return false;
    _rewardedAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onFailedToShow();
      },
    );

    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onUserEarnedReward();
      },
    );
    return true;
  }

  @override
  void disposeRewarded() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

/// Manages Google AdMob initialization, bottom banner lifecycle, and
/// preloaded rewarded video ads (+50 diamonds) with offline-safe fallback.
class AdService extends ChangeNotifier {
  /// Production AdMob App ID (configured in AndroidManifest.xml).
  static const String productionAppId =
      'ca-app-pub-2990586338327178~5364692228';

  /// Google's official test AdMob App ID for Android.
  static const String testAppId =
      'ca-app-pub-3940256099942544~3347511713';

  /// Production Banner Ad Unit ID (Release builds).
  static const String productionBannerAdUnitId =
      'ca-app-pub-2990586338327178/5227771481';

  /// Production Rewarded Video Ad Unit ID (Release builds).
  static const String productionRewardedAdUnitId =
      'ca-app-pub-2990586338327178/9766971660';

  /// Google's official test Banner Ad Unit ID for Android (Debug builds).
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Google's official test Rewarded Video Ad Unit ID for Android (Debug builds).
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Active Banner Ad Unit ID (automatically uses Google's test ID in [kDebugMode]
  /// and [productionBannerAdUnitId] in release builds).
  static String get bannerAdUnitId =>
      resolveBannerAdUnitId(isDebug: kDebugMode);

  /// Active Rewarded Ad Unit ID (automatically uses Google's test ID in [kDebugMode]
  /// and [productionRewardedAdUnitId] in release builds).
  static String get rewardedAdUnitId =>
      resolveRewardedAdUnitId(isDebug: kDebugMode);

  /// Resolves the Banner Ad Unit ID for debug vs. release builds.
  static String resolveBannerAdUnitId({required bool isDebug}) =>
      isDebug ? testBannerAdUnitId : productionBannerAdUnitId;

  /// Resolves the Rewarded Ad Unit ID for debug vs. release builds.
  static String resolveRewardedAdUnitId({required bool isDebug}) =>
      isDebug ? testRewardedAdUnitId : productionRewardedAdUnitId;

  /// Explicit policy-compliant disclosure label for the rewarded video ad button.
  static const String rewardedAdButtonLabel = 'Watch Ad +50 💎';

  final AdMobClient _client;

  bool _isInitialized = false;
  bool _adsRemoved = false;
  bool _isBannerAdLoaded = false;
  bool _isRewardedAdLoaded = false;
  bool _isLoadingRewardedAd = false;
  bool _isPrivacyOptionsRequiredCached = false;
  int _rewardedConsecutiveFailures = 0;

  AdService({AdMobClient? client}) : _client = client ?? DefaultAdMobClient();

  bool get isInitialized => _isInitialized;
  bool get adsRemoved => _adsRemoved;

  /// Synchronous last-known value of [isPrivacyOptionsRequired] for immediate UI rendering.
  bool get isPrivacyOptionsRequiredSync => _isPrivacyOptionsRequiredCached;

  /// True when the Google UMP SDK indicates that a privacy options entry point
  /// is required (`ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required`,
  /// e.g. for users in the EEA / UK / Switzerland).
  Future<bool> get isPrivacyOptionsRequired async {
    try {
      final required = await _client.isPrivacyOptionsRequired();
      _isPrivacyOptionsRequiredCached = required;
      return required;
    } catch (_) {
      return false;
    }
  }

  /// Presents the Google UMP privacy options form so players can review, update,
  /// or revoke their GDPR ad consent at any time.
  Future<void> showPrivacyOptionsForm({
    OnConsentFormDismissedListener? onDismissed,
  }) async {
    try {
      await _client.showPrivacyOptionsForm(
        onDismissed: (FormError? formError) async {
          _isPrivacyOptionsRequiredCached = await isPrivacyOptionsRequired;
          onDismissed?.call(formError);
          notifyListeners();
        },
      );
    } catch (_) {
      onDismissed?.call(null);
    }
  }

  /// True only when a banner ad has loaded successfully AND "Remove Ads" is not unlocked.
  bool get isBannerAdLoaded => !_adsRemoved && _isBannerAdLoaded;

  /// True when a rewarded video ad is preloaded and ready to be shown.
  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  /// True when a rewarded video ad is preloaded and ready to be shown.
  bool get isRewardedAdReady => _isRewardedAdLoaded && !_isLoadingRewardedAd;

  AdSize get bannerSize => AdSize.banner;

  /// Collapses to `0.0` when offline, failed to load, or when Remove Ads is unlocked.
  double get bannerHeight =>
      isBannerAdLoaded ? bannerSize.height.toDouble() : 0.0;

  double get bannerWidth =>
      isBannerAdLoaded ? bannerSize.width.toDouble() : 0.0;

  /// Runs the UMP / GDPR consent flow (`requestConsentInfoUpdate` and
  /// `loadAndShowConsentFormIfRequired`), initializes the Mobile Ads SDK
  /// asynchronously without blocking offline gameplay, loads the bottom banner
  /// (unless [adsRemoved] is true), and preloads a rewarded ad.
  Future<void> initialize({bool adsRemoved = false}) async {
    _adsRemoved = adsRemoved;
    try {
      await _client.initialize();
      _isInitialized = true;
      _isPrivacyOptionsRequiredCached = await isPrivacyOptionsRequired;
      notifyListeners();
    } catch (_) {
      _isInitialized = false;
      return;
    }

    if (!_adsRemoved) {
      unawaited(loadBannerAd());
    }
    unawaited(loadRewardedAd());
  }

  /// Loads the standard bottom banner ad ([AdSize.banner]).
  /// Gracefully collapses to height 0 on failure or when offline.
  Future<void> loadBannerAd() async {
    if (_adsRemoved) {
      disposeBannerAd();
      return;
    }

    try {
      await _client.loadBanner(
        adUnitId: bannerAdUnitId,
        size: bannerSize,
        onLoaded: () {
          if (_adsRemoved) {
            disposeBannerAd();
            return;
          }
          _isBannerAdLoaded = true;
          notifyListeners();
        },
        onFailed: () {
          _isBannerAdLoaded = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _isBannerAdLoaded = false;
      notifyListeners();
    }
  }

  /// Permanently hides and disposes the active bottom banner ad.
  void disposeBannerAd() {
    _client.disposeBanner();
    if (_isBannerAdLoaded) {
      _isBannerAdLoaded = false;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  /// Updates the "Remove Ads" purchase state. When [removed] is true,
  /// permanently hides and disposes the bottom banner ad while keeping
  /// the optional Rewarded Video ad available.
  void setAdsRemoved(bool removed) {
    final previous = _adsRemoved;
    _adsRemoved = removed;
    if (removed) {
      disposeBannerAd();
    } else if (previous && !removed && _isInitialized) {
      unawaited(loadBannerAd());
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  /// Preloads a [RewardedAd] in the background.
  Future<void> loadRewardedAd() async {
    if (_isLoadingRewardedAd || _isRewardedAdLoaded) return;
    _isLoadingRewardedAd = true;

    try {
      await _client.loadRewarded(
        adUnitId: rewardedAdUnitId,
        onLoaded: () {
          _isLoadingRewardedAd = false;
          _isRewardedAdLoaded = true;
          _rewardedConsecutiveFailures = 0;
          notifyListeners();
        },
        onFailed: () {
          _isLoadingRewardedAd = false;
          _isRewardedAdLoaded = false;
          _rewardedConsecutiveFailures++;
          notifyListeners();
          // Automatically attempt reload once on failure; stops if offline to avoid tight loops.
          if (_rewardedConsecutiveFailures <= 1) {
            unawaited(loadRewardedAd());
          }
        },
      );
    } catch (_) {
      _isLoadingRewardedAd = false;
      _isRewardedAdLoaded = false;
      notifyListeners();
    }
  }

  /// Shows the preloaded [RewardedAd] and invokes [onRewardEarned] (or
  /// [onUserEarnedReward]) exclusively when the player finishes watching the ad
  /// inside `onUserEarnedReward`. Automatically preloads the next [RewardedAd]
  /// after the ad is closed or fails to show.
  Future<bool> showRewardedAd({
    VoidCallback? onRewardEarned,
    VoidCallback? onUserEarnedReward,
  }) async {
    final rewardCallback = onUserEarnedReward ?? onRewardEarned;
    if (!isRewardedAdReady || rewardCallback == null) {
      _rewardedConsecutiveFailures = 0;
      unawaited(loadRewardedAd());
      return false;
    }

    _isRewardedAdLoaded = false;
    notifyListeners();

    bool rewardGranted = false;
    try {
      final shown = await _client.showRewarded(
        onUserEarnedReward: () {
          if (!rewardGranted) {
            rewardGranted = true;
            rewardCallback();
          }
        },
        onDismissed: () {
          _rewardedConsecutiveFailures = 0;
          notifyListeners();
          unawaited(loadRewardedAd());
        },
        onFailedToShow: () {
          _rewardedConsecutiveFailures = 0;
          notifyListeners();
          unawaited(loadRewardedAd());
        },
      );
      if (!shown) {
        _rewardedConsecutiveFailures = 0;
        unawaited(loadRewardedAd());
      }
      return shown && rewardGranted;
    } catch (_) {
      _rewardedConsecutiveFailures = 0;
      unawaited(loadRewardedAd());
      return false;
    }
  }

  /// Builds the bottom banner widget when loaded and ads are not removed,
  /// or collapses to a zero-height [SizedBox.shrink] when offline, failed, or removed.
  Widget buildBannerWidget() {
    if (!isBannerAdLoaded) {
      return const SizedBox.shrink();
    }
    final widget = _client.buildBannerWidget();
    if (widget == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      key: const ValueKey('admob_banner_box'),
      width: bannerWidth,
      height: bannerHeight,
      child: widget,
    );
  }

  @override
  void dispose() {
    _client.disposeBanner();
    _client.disposeRewarded();
    super.dispose();
  }
}

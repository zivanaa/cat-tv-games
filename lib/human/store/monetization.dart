/// Everything that can take money or show an ad. Human surface only.
///
/// The architecture test asserts that nothing under lib/cat/ imports this file
/// or the SDKs behind it. That test is the guardrail for the AdMob account:
/// a cat generating ad clicks reads as invalid traffic, and the penalty is
/// account suspension rather than a warning.
library;

// TODO(store): wire google_mobile_ads and purchases_flutter (RevenueCat) here.
//
// Rewarded ads: only reachable from the theme picker, behind an explicit
//   "Watch an ad to unlock" button. Never on a timer, never between sessions,
//   never on the cat surface.
// IAP: RevenueCat rather than raw StoreKit + Play Billing. Cross-platform
//   entitlements for a one-person team are not worth hand-rolling.

abstract class ThemeUnlockService {
  Future<bool> isUnlocked(String themeId);

  /// Returns true if the ad completed and the theme is now unlocked.
  Future<bool> unlockWithRewardedAd(String themeId);

  Future<bool> purchasePremium();
}

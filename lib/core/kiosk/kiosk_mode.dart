import 'package:flutter/services.dart';

/// Keeps a cat inside the app.
///
/// An unsupervised cat on an unlocked phone will eventually leave the app and
/// tap something else. This is a real feature and a real selling point, not a
/// polish item — "your cat cannot exit, buy anything, or call anyone".
///
/// Android can do this from code. iOS cannot: Guided Access is user-enabled
/// only, so [prepare] returns instructions instead and the onboarding walks the
/// owner through Settings > Accessibility > Guided Access.
class KioskMode {
  static const _channel = MethodChannel('cattv/kiosk');

  static Future<KioskAvailability> availability() async {
    // TODO(platform): Android returns whether startLockTask is permitted.
    return KioskAvailability.manualOnly;
  }

  /// Android: startLockTask() plus immersive sticky mode.
  /// iOS: hides the home indicator and disables idle timeout; that is all the
  /// platform allows without MDM.
  static Future<void> enter() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The channel does not exist yet on either platform. Immersive mode alone
    // is still worth having, so a missing handler must not break the session.
    try {
      await _channel.invokeMethod<void>('enter');
    } on MissingPluginException {
      // TODO(platform): remove once the Android handler lands.
    } on PlatformException {
      // Lock task is not always permitted; degrade to immersive only.
    }
  }

  static Future<void> exit() async {
    try {
      await _channel.invokeMethod<void>('exit');
    } on MissingPluginException {
      // See enter().
    } on PlatformException {
      // Nothing to unwind.
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

enum KioskAvailability {
  /// Android with lock task available — the app can pin itself.
  automatic,

  /// iOS, or Android where pinning is blocked. Onboarding must teach the owner
  /// to turn on Guided Access.
  manualOnly,
}

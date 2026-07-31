# First hour after cloning

```bash
flutter create . --org com.yourdomain --platforms android,ios
flutter pub get
flutter pub add flame flutter_riverpod
dart format lib test          # do this before the first commit or CI goes red
flutter analyze
flutter test
```

`flutter analyze` will flag lint issues in the skeleton — `prefer_const_constructors`
and friends. That is intended; clear them as you touch each file rather than
loosening `analysis_options.yaml`.

The two tests that ship here are the ones worth keeping green from day one.
`paw_input_test.dart` pins the hit-detection behaviour that decides whether cats
engage. `architecture_test.dart` is what stops the AdMob account from getting
suspended. Neither should ever be deleted to make a build pass.

## Verify before building anything else

The skeleton assumes cats will chase a slow fish on a phone screen. Test that
assumption on real cats in week one, before the Isar layer, before capture,
before the store. If they do not engage, the fix is in `PawInputConfig` and the
audio layer, not in more features.

Watch specifically for a session that ends with a score of zero. That is the
signal that hit detection is too strict, and it is the most likely way this
product fails.

## What and why

<!-- The diff shows what. Explain why, and what you considered instead. -->

## Surface

<!-- Delete whichever does not apply. -->
- [ ] Cat surface (`lib/cat/`) — no ads, no purchases, no exits, no dialogs
- [ ] Human surface (`lib/human/`)
- [ ] Shared / infrastructure

## Checks

- [ ] `flutter analyze` clean
- [ ] `flutter test` passes, including `architecture_test.dart`
- [ ] `dart format lib test` applied

## If this touches the cat surface

- [ ] Hit testing still goes through `PawInput` — no raw distance comparisons
- [ ] Targets are at least `minTargetRadius`, and register on pointer down
- [ ] Tested with a real cat, or noted below why not

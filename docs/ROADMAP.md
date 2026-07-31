# Roadmap

Ordered by what de-risks the product soonest. The point of this order is to find
out whether cats engage at all before building anything expensive.

## Milestone 1 — does a cat actually play this?

- Fish game rendered in Flame, wired to `PawInput`
- Audio layer with a handful of samples
- Session cap and wind-down
- `ExitGuard` and Android kiosk mode
- Single hardcoded cat profile

Ship to a handful of real cats. If they do not engage with fish, nothing later in
this list saves the product. Watch for the zero-score failure and tune
`PawInputConfig` before anything else.

## Milestone 2 — why the owner opens the app

- Isar persistence, real cat profiles, multi-cat
- Stats screen: contacts per minute, accuracy trend, session history
- TV mode, procedurally generated

Contacts per minute is the number that tells an owner their cat cared. Lead with
it, not with score.

## Milestone 3 — the shareable part

- `RollingBuffer` platform channels, Android first (CameraX is much less work)
- `HighlightDetector` wired in, gallery screen
- Export and share, from the human surface only

This is the most expensive feature in the app and the one most likely to drive
word of mouth, which is why it is third and not first.

## Milestone 4 — money

- Theme system, two free and several unlockable
- RevenueCat entitlements, one-time premium unlock
- Rewarded ads in the theme picker only

Do not add ads before there is a reason to open the app twice. And re-read the
boundary rule in `CLAUDE.md` before wiring the ad SDK.

## Later

- Mouse and laser modes
- iOS capture implementation
- Difficulty presets for kittens and senior cats
- Apple TV / Android TV — a big screen is a better cat TV than a phone, and
  the input problem disappears entirely in TV mode

# CLAUDE.md

Cat TV + Cat Games. A Flutter + Flame app with two kinds of user: **cats play it, humans pay for it.**
Every architectural decision in this repo follows from that split.

## Commands

```bash
flutter pub get
flutter analyze                 # must be clean before commit
flutter test                    # includes the architecture boundary test
flutter run -d <device>
flutter build apk --release
flutter build ipa --release
dart format lib test
```

`test/architecture_test.dart` is not a normal unit test — it enforces the boundary rule below.
If it fails, the fix is to move code, never to weaken the test.

## The one architectural rule

`lib/` is split into two surfaces:

| Directory | Surface | Who is looking at the screen |
|---|---|---|
| `lib/cat/` | Cat surface | A cat, alone, unsupervised |
| `lib/human/` | Human surface | The owner, deliberately |
| `lib/core/`, `lib/data/`, `lib/shared/`, `lib/capture/` | Shared | Either |

**Nothing under `lib/cat/` may import, reference, or trigger:**

- ad SDKs (`google_mobile_ads`) — a cat tapping ads is invalid traffic and gets the AdMob account banned, not warned
- purchase SDKs (`purchases_flutter`, `in_app_purchase`) — accidental purchases
- `url_launcher`, share sheets, deep links, or anything that leaves the app
- dialogs, snackbars, or any UI element that responds to a single tap by changing screen

Monetization lives in `lib/human/store/` only. The cat surface reads the *result*
(which theme is unlocked) through `ThemeRepository`, never the SDK.

Exiting the cat surface requires a deliberate human gesture — see `lib/shared/widgets/exit_guard.dart`
(long-press 2s in a corner). Never a plain tap, never a back gesture.

## Cat UX rules — these are not preferences, they are the product

Read `docs/CAT_UX.md` before touching anything under `lib/cat/`. Summary:

1. **Hit detection must be forgiving.** Cat paw pads conduct poorly and claws not at all.
   All hit testing goes through `PawInput` (`lib/cat/engine/paw_input.dart`). Never compare
   raw distance to a sprite's visual radius. A cat that plays for five minutes and scores
   zero produces a one-star review.
2. **Register on pointer down, never on tap-up.** A paw swipe rarely produces a clean tap.
3. **Minimum touch target is `PawInput.minTargetRadius` (~64 logical px), assist radius ~2.5x that.**
   Visual size and hit size are decoupled on purpose.
4. **Audio drives engagement more than visuals.** High-frequency chirps and rustling.
   Never ship a game mode with no sound layer.
5. **Cap the cat surface at 40fps and avoid particle storms.** Sessions are 30 minutes on
   a device that may be lying on a rug. Thermal throttling ends the session, not the cat.
6. **Sessions end themselves.** Hard cap, then a wind-down animation. Cats do not stop.

## Conventions

- State: Riverpod. Providers live next to the feature, not in a global `providers.dart`.
- Persistence: Isar via `lib/data/local/`. Repositories return domain models from `lib/data/models/`,
  never Isar collection objects — keeps the DB swappable and the models testable.
- Flame components own their own rendering only. Game rules live in plain Dart classes under
  `lib/cat/engine/` so they can be unit tested without a game loop.
- No `print`. Use `AppLog` in `lib/core/`.
- Every new game mode implements `CatGame` and registers in `lib/cat/games/game_catalog.dart`.

## Things that look like bugs but are not

- `PawInput` awards a hit for touches that miss the sprite. Intentional. See rule 1.
- `RollingBuffer` discards video constantly and only writes on trigger. Intentional —
  recording 30 minutes straight fills storage, drains battery, and invites App Store review
  questions about why a cat app needs continuous camera access.
- The cat surface has no back button. Intentional. See `exit_guard.dart`.

## Git

Branches: `<type>/<kebab-case>`, e.g. `feat/paw-input-assist`, `fix/generous-tier-reach`.
Types: `feat` `fix` `chore` `docs` `refactor` `test` `perf` `ci` `build` `style`.
Use `feat`, never `feature`. Never commit or push directly to `main`.

Commits: Conventional Commits, `<type>(<scope>): <subject>`. Subject lower case,
imperative, 72 characters max. Scopes are listed in `docs/CONTRIBUTING.md`.
Explain *why* in the body; the diff already shows what.

**Commits carry the repository owner's name only.** Add no `Co-Authored-By`
trailer, no "Generated with" line, and no session URL. `.claude/settings.json`
configures this, `.githooks/commit-msg` strips it as a backstop, and CI fails the
PR if any slips through. A human `Co-Authored-By` for an actual person is fine.

Before proposing a commit, run `dart format lib test`, `flutter analyze`, and
`flutter test`.

## Current state

Skeleton. Implemented: paw input, highlight detection, session tracking, architecture test.
Stubbed with TODOs: Isar layer, capture platform channels, kiosk platform channels, mouse/laser
games, TV mode generator, store. See `docs/ROADMAP.md` for the intended build order.

Platform folders (`android/`, `ios/`) are not committed yet — run `flutter create .` first.

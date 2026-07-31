# Cat TV + Cat Games

Games and ambient video for cats, with per-cat stats, auto-captured highlight clips,
and unlockable themes. Flutter + Flame, one codebase for Android and iOS.

## Repo setup

One command, run once from the project root:

```bash
chmod +x scripts/setup-repo.sh .githooks/*
./scripts/setup-repo.sh "Your Name" "you@example.com" cat-tv-games private
```

(The `chmod` matters — the executable bit does not survive being zipped and
downloaded, and a hook without it is silently skipped by git.)

It sets your git identity for this repo, installs the hooks, makes the first
commit, and creates the GitHub repo through your own `gh` session. Sign in first
if you have not:

```bash
gh auth login
```

Everything after that goes through a branch:

```bash
git switch -c feat/fish-game-render
git commit -m "feat(fish): render the pond in Flame"
git push
gh pr create --fill
```

Branch and commit conventions are in `docs/CONTRIBUTING.md` and enforced by
`.githooks/` plus CI. Commits carry your name only — see the attribution section
there.

## Getting started

The platform folders are not committed. Generate them first:

```bash
flutter create . --org com.yourdomain --platforms android,ios
flutter pub get
```

Then add dependencies (versions resolve against your SDK, so use the CLI rather
than hand-editing `pubspec.yaml`):

```bash
# Game loop and rendering
flutter pub add flame

# State and storage
flutter pub add flutter_riverpod isar isar_flutter_libs path_provider
flutter pub add --dev isar_generator build_runner

# Audio — soundpool-style low latency matters, cats react to onset
flutter pub add just_audio audio_session

# Capture
flutter pub add camera permission_handler

# Human surface only — see the boundary rule below
flutter pub add google_mobile_ads purchases_flutter
```

Run:

```bash
flutter run -d <device>
flutter test        # includes the architecture boundary test
flutter analyze
```

## The boundary rule

`lib/` splits by *who is looking at the screen*:

```
lib/cat/       a cat, alone, unsupervised   -> no ads, no purchases, no exits
lib/human/     the owner, deliberately      -> ads, purchases, stats, settings
lib/core/      shared infrastructure
lib/data/      models and persistence
lib/capture/   rolling video buffer
lib/shared/    widgets used by both
```

`test/architecture_test.dart` enforces it. The reason is not tidiness: a cat
tapping ads produces invalid traffic, and Google suspends AdMob accounts for it
rather than warning them. The cat surface has to be structurally unable to show
an ad.

## Where the interesting code is

| File | Why it matters |
|---|---|
| `lib/cat/engine/paw_input.dart` | Tiered forgiving hit detection. Cat paws conduct poorly; strict hit testing produces zero-score sessions and one-star reviews. |
| `lib/capture/highlight_detector.dart` | Decides when to save a clip from the rolling buffer, using tap rate rather than any ML. |
| `lib/capture/rolling_buffer.dart` | Dashcam-style discarding buffer. Continuous recording is the obvious approach and the wrong one. |
| `lib/core/kiosk/kiosk_mode.dart` | Keeps the cat inside the app. Android can enforce it; iOS needs Guided Access onboarding. |

## Docs

- `CLAUDE.md` — working agreement for Claude Code, and the shortest version of the rules
- `docs/ARCHITECTURE.md` — layering and data flow
- `docs/CAT_UX.md` — the domain constraints that drive the design
- `docs/ROADMAP.md` — build order
- `docs/NEXT_STEPS.md` — what to run first, and what to verify before building more

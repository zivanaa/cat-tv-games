# Architecture

## The organising idea

Two users, opposite needs. The cat plays and cannot be trusted with a single tap.
The owner pays and needs to be shown something worth paying for. Almost every
decision here is downstream of keeping those two apart.

```
                    ┌────────────────────┐
                    │   HUMAN SURFACE    │  lib/human/
                    │  home · profiles   │
                    │  stats · gallery   │  ads, IAP, navigation,
                    │  store · settings  │  dialogs — all fine here
                    └─────────┬──────────┘
                              │ launches a session
                              ▼
                    ┌────────────────────┐
                    │    CAT SURFACE     │  lib/cat/
                    │  games · TV mode   │
                    │                    │  no ads, no IAP, no exits,
                    │  exit: hold 2s     │  no dialogs, no back gesture
                    └─────────┬──────────┘
                              │ contacts
                              ▼
        ┌──────────────┬──────────────┬──────────────┐
        │  PawInput    │ SessionRec.  │ Highlight    │
        │  resolves    │ accumulates  │ Detector     │
        │  hit tier    │ stats        │ triggers     │
        └──────────────┴───────┬──────┴───────┬──────┘
                               │              │
                               ▼              ▼
                        lib/data/       lib/capture/
                        Isar            RollingBuffer
```

## Layers

**Rules are plain Dart.** `PawInput`, `HighlightDetector`, `SessionRecorder` and
each `CatGame` implementation have no Flame or Flutter dependency beyond
`dart:ui` geometry. They are unit tested directly. Flame components render and
forward events; they do not own logic.

**Repositories return domain models.** `lib/data/repositories/` maps Isar
collections to the plain classes in `lib/data/models/`. Nothing above the data
layer knows Isar exists, which keeps the models testable and the database
replaceable.

**Platform capability is behind an interface.** `RollingBuffer` and `KioskMode`
both have a Dart-side contract and a no-op default, so the app runs end to end
before either platform channel exists. Swapping the real implementation in
touches only the DI wiring.

## Input path

1. Flame's `onTapDown` fires — pointer *down*, not a completed tap, because a
   paw swipe rarely produces a clean tap.
2. The game passes the point and its current targets to `PawInput.resolve`.
3. `PawInput` returns a `PawHit` with a tier: direct, assisted, generous, or miss.
4. `SessionRecorder` records it and weights the score by tier.
5. `HighlightDetector` sees the contact and may return a trigger.
6. A trigger flushes `RollingBuffer` to a file, which is attached to the session.

Steps 2–5 are pure functions of their inputs plus an injected `DateTime`, so the
whole path is testable without a device.

## Difficulty

Per cat, persisted on `CatProfile`, adjusted within a session by
`SessionRecorder.suggestedDifficulty`. It moves down faster than it moves up.
A cat that is missing needs help immediately; a cat that is winning can stay
winning for a while longer.

# Cat UX

Constraints that come from the animal, not from taste. Read before touching
`lib/cat/`.

## Touch

Cat paw pads are drier and less conductive than human fingertips, and claws do
not register on a capacitive screen at all. A bat at the screen is a fast
glancing contact, not a press. Consequences:

- Hit test on **pointer down**. Waiting for tap-up loses most contacts.
- Minimum effective target radius ~64 logical px regardless of drawn size.
- Assist radius ~2.5x that, and a generous tier beyond it. See `paw_input.dart`.
- Debounce ~80ms — one bat can fire several pointer events.
- Multi-touch is common and is the strongest signal of full engagement. Track it.

The failure mode to design against: a cat plays enthusiastically for five
minutes, the score reads 0, and the owner concludes the app is broken.

## Attention

- Movement holds attention; static images do not. Nothing on the cat surface
  should be still for more than a couple of seconds.
- Targets must be **trackable**. Slow, predictable paths with occasional darts.
  Fast random motion reads as noise and cats disengage.
- Never wrap a target from one screen edge to the other. Bounce. Teleporting
  breaks the cat's tracking and it stops looking.
- Contrast and motion matter more than colour. Cats are dichromatic — blues and
  yellows read strongly, reds do not. Do not build a theme around red.

## Sound

Underrated and probably the single biggest engagement lever. Many cats ignore the
screen entirely until they hear something. High-frequency chirps, squeaks,
rustling. Onset latency matters, so preload samples. Ship no mode without audio.

## Sessions

- Cats do not self-regulate; the app must. Hard cap at 15 minutes for games,
  30 for TV mode.
- End with a wind-down: targets slow and fade. Cutting to black abruptly leaves a
  cat staring at a dead screen and teaches it that the app stops being fun.
- Cap the frame rate at 40 and keep effects cheap. Thirty minutes of full-screen
  animation on a device lying on a rug will thermally throttle, and throttling
  ends the session more reliably than boredom.

## The device

- Screens get scratched. Say so during onboarding and recommend a protector —
  it is better coming from the app than from a review.
- Keep the screen awake for the whole session, and restore normal timeout after.
- Cats will leave the app if allowed. See `kiosk_mode.dart`.

# The corner bear

`bear-01.png` is the canonical ChinGo mascot — deep berry body, warm cream belly, muzzle,
ears and paws. It is already wired into the app as the icon and the splash.

What is still missing is the corner pose: the bear leaning in from the bottom corner, happy,
like it is peeking into the screen.

## How to run it

**Attach `bear-01.png` to the message.** Do not paste this prompt on its own — a fresh
generation produces a *different* bear, and the whole point is that this is the same
character in a new pose. Attaching the image is what keeps the identity.

Run it twice: once as written (lower-left), then again swapping every "left" to "right".
Save the results as `corner-left.png` and `corner-right.png` in this folder.

## The prompt

```
Using the attached bear as the exact character reference, redraw the same bear in a new pose. Keep its identity completely unchanged: the same deep berry body colour, the same warm cream belly, muzzle, inner ears and paw pads, the same simple black eyes with a single small highlight, the same tiny curved smile, the same flat vector treatment with thick soft rounded edges and no outlines.

New pose: the bear is leaning in from the lower-left corner of the square, peeking into frame — happy and pleased to see you, with a slightly wider smile than the reference. Show its head, one shoulder and one paw resting on the bottom edge as if it is propping itself up to look over. The body is cropped by the left and bottom edges of the square; the head and both ears stay fully visible and are never cut off.

Composition: the bear occupies the lower-left and fills roughly 60 percent of the square, leaving clear empty background across the upper-right so the corner reads as somewhere it is emerging from. Do not centre it.

Background: one flat, solid, gently muted warm cream, filling every part of the square the bear does not occupy. No gradient, texture, vignette or shadow on the background.

Constraints: no text, no watermark, no border or frame, one character only, no scenery or props, no outlines, no photorealistic material, no glossy highlights beyond the single eye dot, no cast shadow.
```

## After it lands

Tell me and I will cut the background out, add it to the asset catalogue, and use it for the
empty album state and the onboarding screens — the places where the app should feel like it
is talking to you rather than showing you a map.

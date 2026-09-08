# Side engine: the NFC sticker

Matthew's idea, captured so it does not get lost: sell a custom ChinGo NFC sticker. Tapping it
levels you up, and it lives on the back of a phone as an object people can see.

## Why it is a good fit rather than merchandise

The app's whole premise is that the interesting thing happened in person. An NFC tap is the only
input a phone has that **cannot be faked remotely** — you were physically there, holding your
phone against a thing. That is the same claim a catch makes, which means the sticker is not a
bolt-on: it is a second way of proving the one thing this app cares about.

It also fits the free-with-paid-extras model already recorded: the sticker is an optional
purchase and the core loop never gates on it.

## What it would take

- **Reading**: Core NFC, `NFCNDEFReaderSession`. Background tag reading works on iPhone XS and
  later with no app open at all, which is the good version — you tap, the app opens.
- **Writing**: the stickers get written once, at production, with a URL that deep-links into the
  app. `CFBundleURLTypes` is already declared in `project.yml`.
- **The anti-abuse problem is the whole design.** A sticker that levels you up on every tap is a
  clicker. Options: one grant per sticker per day, or per location, or the sticker identifies a
  *place* and the reward is for visiting places. The third is the most interesting and the most
  in keeping — it turns stickers into something a venue puts on a wall.
- Signed payloads, or somebody with an NFC writer clones one in a minute.

## Open question

Whether a sticker is bound to a person (yours, on your phone, others tap it to add you — which
makes it a physical handle) or to a place (on a wall, tapping it proves you were there). Those
are different products. The second is closer to challenges, which Matthew has also mentioned
wanting to run.

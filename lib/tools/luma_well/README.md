# Luma Well

Luma Well is an endless, calm planet-growth game.

This document is the working gameplay specification for the playable game.

## Core Loop

1. Matter orbs spawn continuously around a small central planet.
2. Orbs drift slowly across the full playfield.
3. The player touches and holds a point to create a capture ring.
4. The ring selects nearby orbs whose visible values span no more than one.
5. Holding a valid group for roughly 1.5 seconds combines it.
6. The combined mass travels into the planet and grows it.
7. Reaching the stage mass target grows the planet into the next stage.

An early release cancels the capture. The orbs remain in the field.

## Stages

The planet starts small. Each stage raises the mass target for the next one.

Stages add one new matter value, up to four values (`1` through `4`) total.
Existing values remain in the field. A capture succeeds only if its highest and lowest values differ
by no more than one: 1 and 2 work, while 1 and 3 fail.

Every completed stage grants one power-up charge and increases the orb spawn
rate slightly.

Rare gold star power orbs are wildcards. They can join any valid value range,
but a capture containing one still needs at least two normal orbs. Capturing a
power orb awards one additional power-up charge.

## Challenge

There is no abrupt game-over condition. The challenge is efficiency under
gradual orbital saturation:

- More matter arrives over time.
- More matter kinds divide the field into smaller compatible groups.
- Orbs drift, so useful groups form and separate naturally.
- Small groups are safe but provide little growth.
- Waiting for a large group gives better growth, but the field gets denser.
- Large amounts of loose matter can make compatible groups difficult to find.

The score measures efficient planet growth. Stages are the primary long-term
goal; a run continues indefinitely after all planned visual planet stages.

## Power-Ups

Power-ups consume one earned charge.

| Power | Effect |
| --- | --- |
| Pulse | Pushes loose matter outward to make room near the planet. |
| Stabilize | Slows drifting matter for a short period. |
| Focus field | Makes the next three capture rings smaller. |

## Current Game

Implemented:

- Full rectangular starfield play area.
- A small growing central planet.
- Slow continuously spawned, free-floating orbs.
- Touch-and-hold capture ring.
- Visible-number range validation inside the ring.
- Timed group absorption, stage thresholds, scores, and power-up charges.
- A merge-flight animation and center score popup.
- Run persistence and inactive-app simulation pause.

## Future Refinement

- The visual identity of each planet stage.
- Whether loose matter needs soft cleanup mechanics at high density.

## Iteration Rules

- Keep interaction to one finger: touch, hold, release.
- Keep the playfield full-screen and unclipped.
- Prefer gentle pressure over fail-fast punishment.
- Pause simulation while the app is inactive; background time must never add
  matter, advance a capture, or change the field.
- Do not use the referenced game's name, artwork, text, or exact systems.

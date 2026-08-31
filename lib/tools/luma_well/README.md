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

The visible ring is the exact capture boundary. An orb is selected only when
its center is inside the displayed ring; merely touching the ring edge does not
count. Ring size and hold time lock when the touch begins, so a special orb can
only modify later captures.

The ring always renders as a complete circle. Its animated arc shows hold
progress only and must never be the only visible boundary.

## Stages

The planet starts small. Each stage raises the mass target for the next one.
Its visible radius is capped at 34% of the field half-width, so endless runs
continue to leave room for drifting matter and capture rings.

Stages unlock new visible matter values. Existing values remain in the field.
A capture succeeds only if its highest and lowest values differ by no more than
one: 1 and 2 work, while 1 and 3 fail.

| Reached stage | Values released into the field |
| --- | --- |
| 1 | 1 and 2 |
| 2 | 3 |
| 3 | 4 |
| 4 | 5 |
| 5 | 6 |

Values do not go above 6. Higher values give more planet mass and score, but
their narrower compatible range makes them harder to group safely.

Every completed stage grants one power-up charge and increases the orb spawn
rate slightly.

## Rewards

Visible orb values (`1` through `6`) determine growth and score. Each orb adds
its hidden mass multiplied by its visible value to the planet. A completed
group is then multiplied by its orb count and a further squared group-size
bonus. High-value, large groups are therefore much more rewarding than small
low-value captures.

Rare star power orbs are wildcards. They can join any valid value range, but a
capture containing one still needs at least two normal orbs. Gold stars award a
power-up charge immediately. Cyan stars activate three expanded, slower capture
rings. Violet stars activate three focused, faster capture rings.

## Challenge

There is no abrupt game-over condition. The challenge is efficiency under
gradual orbital saturation:

- More matter arrives over time.
- More matter kinds divide the field into smaller compatible groups.
- Orbs drift, so useful groups form and separate naturally.
- Small groups are safe but provide little growth.
- Waiting for a large group gives better growth, but the field gets denser.
- Large amounts of loose matter can make compatible groups difficult to find.
- Spawning slows as the field exceeds 48 orbs, giving crowded runs breathing room.

The score measures efficient planet growth. Stages are the primary long-term
goal; after stage 5, all six values remain active and the run continues
indefinitely for score and planet growth.

## Power-Ups

Power-ups consume one earned charge.

The Settings sheet offers an optional Unlimited power-ups mode. It is a relaxed
play setting: power-ups remain available without consuming earned charges.

| Power | Effect |
| --- | --- |
| Pulse | Pushes loose matter outward to make room near the planet. |
| Stabilize | Slows drifting matter for a short period. |
| Expand field | Makes the next three capture rings wider and 0.5 seconds slower. |
| Focus field | Makes the next three capture rings smaller and 0.35 seconds faster. |
| Thin field | Removes the outermost 25% of loose orbs. |

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

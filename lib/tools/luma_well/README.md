# Luma Well

Luma Well is an endless, calm planet-growth game.

This document is the working gameplay specification. The implementation is a
prototype and may change as the game is tested.

## Core Loop

1. Matter orbs spawn continuously around a small central planet.
2. Orbs drift slowly across the full playfield.
3. The player touches and holds a point to create a capture ring.
4. The ring selects nearby orbs of one compatible kind.
5. Holding a valid group for roughly 2.5 seconds combines it.
6. The combined mass travels into the planet and grows it.
7. Reaching the stage mass target grows the planet into the next stage.

An early release cancels the capture. The orbs remain in the field.

## Stages

The planet starts small. Each stage raises the mass target for the next one.

Stages add one new matter kind, up to four kinds total. Existing kinds remain
in the field. Only orbs of the same kind can be captured together, so later
stages need more intentional grouping.

Every completed stage grants one power-up charge and increases the orb spawn
rate slightly.

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

| Power | Prototype effect |
| --- | --- |
| Pulse | Pushes loose matter outward to make room near the planet. |
| Stabilize | Slows drifting matter for a short period. |
| Feed the planet | Absorbs nearby small matter immediately. |

## Current Prototype

Implemented:

- Full rectangular starfield play area.
- A small growing central planet.
- Slow continuously spawned, free-floating orbs.
- Touch-and-hold capture ring.
- Compatible-kind selection inside the ring.
- Timed group absorption, stage thresholds, scores, and power-up charges.

Still to validate:

- Whether captured orbs should visibly travel to a temporary merged cluster
  before reaching the planet.
- The best ring radius, hold duration, and spawn pace.
- How kinds should be distinguished without making the field noisy.
- The visual identity of each planet stage.
- Whether loose matter needs soft cleanup mechanics at high density.

## Iteration Rules

- Keep interaction to one finger: touch, hold, release.
- Keep the playfield full-screen and unclipped.
- Prefer gentle pressure over fail-fast punishment.
- Do not use the referenced game's name, artwork, text, or exact systems.
- Prototype the interaction first; polish visuals and effects after the loop
  feels good.

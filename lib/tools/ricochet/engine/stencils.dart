import 'tile.dart';

/// Hand-drawn board layouts, one row of the 13-column grid per string.
///
/// `#` is a plain brick (which then rolls for a common bonus), `.` is empty,
/// and the remaining characters hand-place an accent — the invader's orb eyes,
/// the castle's pierce towers. `B` (bomb) has no hand-placed entry on purpose:
/// bombs come from the per-tile roll so they are spread across every layout
/// rather than concentrated in one.
///
/// Layouts are auto-centered on the grid and randomly mirrored, so a stencil
/// narrower than 13 columns still reads as deliberate art.
const List<List<String>> stencils = [
  // Heart — an ×2 tucked into the tip.
  [
    '.###.....###.',
    '#############',
    '#############',
    '.###########.',
    '..#########..',
    '...#######...',
    '....#####....',
    '.....#M#.....',
  ],
  // Invader — orb-bumper eyes.
  [
    '..#.......#..',
    '...#.....#...',
    '..#########..',
    '.##..O.O..##.',
    '#############',
    '#.#########.#',
    '#.#.......#.#',
    '....##.##....',
  ],
  // Gem — a gift core.
  [
    '......#......',
    '.....###.....',
    '....#####....',
    '...#######...',
    '..#########..',
    '.###########.',
    '######G######',
    '.###########.',
    '..#########..',
  ],
  // Castle — pierce towers, blast-tile flanks.
  [
    'P.P..#.#..P.P',
    '#############',
    '###...#...###',
    '###...#...###',
    '##XX#####XX##',
  ],
  // Funnel — ramps steering balls into waiting orbs.
  [
    r'\.........../',
    r'.\........./.',
    r'..\......./..',
    r'...\...../...',
    r'....\.../....',
    r'.....\O/.....',
    r'......O......',
  ],
  // Butterfly — blast-tile head.
  [
    '###.......###',
    '####..X..####',
    '###.#.#.#.###',
    '.###########.',
    '..#########..',
  ],
  // Diamond — the classic rhombus.
  [
    '......#......',
    '.....###.....',
    '....#####....',
    '...#######...',
    '..#########..',
    '.###########.',
    '..#########..',
    '...#######...',
    '....#####....',
  ],
  // Star — ×2 multiplier core.
  [
    '......#......',
    '.....###.....',
    '#####...#####',
    '.###########.',
    '..####M####..',
    '..##.....##..',
    '##.........##',
  ],
  // Cross — blast tiles on the arms.
  [
    '.....###.....',
    '.....###.....',
    '#####X#X#####',
    '.....###.....',
    '.....###.....',
  ],
  // Flower — orb-bumper heart.
  [
    '...##...##...',
    '..####.####..',
    '###..###..###',
    '####..O..####',
    '###..###..###',
    '..####.####..',
    '...##...##...',
  ],
  // Crown — gift jewel in the band.
  [
    '#..#.....#..#',
    '##.##...##.##',
    '#############',
    '######G######',
    '.###########.',
  ],
  // Skull — blast-tile nose.
  [
    '..#########..',
    '.###########.',
    '###..###..###',
    '###..###..###',
    '####..X..####',
    '.##..###..##.',
    '...#######...',
  ],
  // Ghost — gift between the eyes, tattered skirt.
  [
    '...#######...',
    '..#########..',
    '##..#####..##',
    '##..##G##..##',
    '.###########.',
    '..#.#.#.#.#..',
  ],
  // UFO — blast dome, orb tractor-lights.
  [
    '.....#X#.....',
    '....#####....',
    '..#########..',
    '#############',
    '#..O.....O..#',
  ],
  // Rocket — blast boosters, ×2 porthole.
  [
    '......#......',
    '.....###.....',
    '....#####....',
    '####X###X####',
    '####..M..####',
    '.####...####.',
  ],
  // Anchor — pierce-tile flukes.
  [
    '.....###.....',
    '.....#.#.....',
    '......#......',
    '#############',
    '......#......',
    'P.....#.....P',
    '##....#....##',
  ],
  // Lightning bolt.
  [
    '....######...',
    '...###.......',
    '..#######....',
    '......####...',
    '.....###.....',
    '....##.......',
    '...##........',
  ],
  // Question mark.
  [
    '...######....',
    '..##....###..',
    '........###..',
    '.......###...',
    '......###....',
    '......###....',
    '.............',
    '......###....',
  ],
  // Spider — orb eye in the body.
  [
    '#..#.....#..#',
    '.#..#...#..#.',
    '..##.#.#.##..',
    '.#####O#####.',
    '..#########..',
    '.#..#.#.#..#.',
    '#...#...#...#',
  ],
];

/// Stencil character to tile kind. `#` and `.` are handled by the generator
/// itself — `#` rolls for a bonus and `.` places nothing.
const Map<String, TileType> stencilChars = {
  'B': TileType.bomb,
  'G': TileType.gift,
  'M': TileType.mult,
  'P': TileType.pierce,
  'X': TileType.blast,
  'O': TileType.orb,
  '/': TileType.rampA,
  r'\': TileType.rampB,
};

/// Stencil art alone leaves the exotic kinds far too rare — ramps live in a
/// single stencil, pierce tiles in two — so every board also seeds them
/// directly. A kind unlocks at [from], rolls [chance] once per board, and is
/// skipped when the drawn art already supplies [cap] of it.
class RareSeed {
  final TileType type;
  final int from;
  final double chance;
  final int lo;
  final int hi;
  final int cap;

  const RareSeed({
    required this.type,
    required this.from,
    required this.chance,
    required this.lo,
    required this.hi,
    required this.cap,
  });
}

const List<RareSeed> rareMix = [
  RareSeed(type: TileType.blast, from: 3, chance: 0.55, lo: 1, hi: 2, cap: 2),
  RareSeed(type: TileType.pierce, from: 5, chance: 0.5, lo: 1, hi: 2, cap: 2),
  RareSeed(type: TileType.orb, from: 7, chance: 0.5, lo: 1, hi: 3, cap: 3),
  // rampA stands in for both ramp variants; each converted tile picks a side.
  RareSeed(type: TileType.rampA, from: 10, chance: 0.45, lo: 2, hi: 4, cap: 4),
];

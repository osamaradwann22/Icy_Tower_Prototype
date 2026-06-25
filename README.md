# Sugar Tower Prototype

A small Godot 4.6.2 web-ready prototype inspired by the core Icy Tower loop, now themed as a candy/donut vertical climber.

## Open

1. Open Godot 4.6.2.
2. Choose **Import**.
3. Select `project.godot` from this folder.
4. Run the project.

## Controls

- Move left: `A` or left arrow
- Move right: `D` or right arrow
- Start / restart: `Space`
- Mobile: hold the large left/right zones; jumping is automatic

## Current Prototype Features

- Candy bakery background and warm donut-shop palette
- High-contrast outlined platforms for readability
- Mobile-first start screen and game-over restart flow
- Reachable platform placement based on the previous floor position
- One-way platforms so the player can jump through from below
- No side wrapping; the player is clamped inside the screen edges
- Camera follows the highest point reached
- Camera auto-scrolls upward after a short grace period, so standing still becomes dangerous
- Portrait/mobile-first viewport
- Large mobile left/right touch zones and mobile restart button
- Built-in sugar-runner/baker character
- Score, floor, best score, and combo UI
- Auto-jump gameplay: the mascot bounces automatically on landing
- Small-number scoring tuned for readability
- Momentum-based jump height
- Tile-chain combo: landing on 5 new tiles activates combo
- Landing on the same tile or waiting too long resets the chain
- Acrobatic flip jumps once the tile-chain combo is active
- Camera moves faster while the player waits on a tile
- Combo timeout and small combo bonuses based on chained tile jumps
- Landing feedback popups
- Sprinkle burst effects and boost screen shake
- Difficulty scaling as the player climbs
- Platform types:
  - Plain wafer bars
  - Boost donuts that launch the player higher
  - Sprinkle bonus donuts
  - Glazed slippery floors
  - Crumbly donuts that break after landing
- Web export preset targeting `build/web/index.html`

## Web Export

Open **Project > Export**, choose the **Web** preset, and export. If Godot asks for export templates, install the matching 4.6.2 templates from the editor prompt first.

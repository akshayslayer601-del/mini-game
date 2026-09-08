# WARZONE: LAST STAND

A self-contained WarioWare-style rapid-fire war-game collection built in Godot 4 using GDScript.

## Included

- 5 interactive war-games
- 10 rounds per run
- Mouse, touch and keyboard controls
- Increasing difficulty
- Score and best-streak system
- Original winner and death screens
- Procedural visuals drawn by the game itself
- No plugins, backend, API keys, npm or external runtime dependencies
- Netlify-ready Web export configuration

## Minigames

1. Smash It — click the target.
2. Dodge — move left/right and avoid falling hazards.
3. Color Panic — select the requested color.
4. Target Tap — hit the target three times.
5. Safe Button — find the correct button.

## Godot version

Designed for Godot 4.7.x, with Godot 4.7.2 as the current stable target.

## Run locally

1. Open the folder in Godot 4.7.2.
2. Open `project.godot`.
3. Press F6 or F5.
4. Press Enter/Space or click START MAYHEM.

## Web / Netlify

Export the project for Web into a folder named `web` at the project root. The included `netlify.toml` publishes that folder and sets MIME types for WebAssembly and PCK files.

Recommended Web export setting: Thread Support OFF for the simplest Netlify deployment.

## Controls

- Mouse / touch: click or drag as instructed.
- Dodge: A/D or Left/Right arrows.
- Color Panic: R, B, G, Y.
- Target Tap: Space/Enter also works.
- Safe Button: click a button.
- Restart: Enter/Space/R on the result screen.

## Assets

The current build intentionally uses procedural drawing so it runs without external asset files. You can replace/add your own original art, sounds and fonts later.

## AI disclosure

If this project is submitted to a competition with an AI-use requirement, describe AI assistance honestly. Do not claim a specific amount of human coding time or a particular AI-usage level unless it is true.

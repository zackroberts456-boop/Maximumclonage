# Maximum Clonage — Current Development State

## Active Build Direction

Persistent Godot 4.7.1 Android master project. Do not restart from scratch. The canonical runtime archive remains `MaximumClonage_Runtime_Project.zip`; production changes are layered through `runtime_overrides/` and validated by the Android CI workflow.

## Current Gameplay Systems

- 240x160 internal viewport with integer nearest-neighbor scaling.
- Six selectable playable characters.
- Standardized collision / jump geometry across the roster.
- Keyboard, gamepad, and fixed mobile D-pad + Fire / Jump / Special controls.
- 8-way directional aiming, hold-to-fire, aim-lock/strafe behavior.
- 12 HP Normal rules, lives, checkpoints, death/restart, score/combo.
- Default weapon and Spread pickup foundation.
- Stage 1 authored traversal with ten encounter rooms and two checkpoints.
- Three progression-lock combat gates so major encounters cannot be skipped by sprinting past them.
- Moving vertical/horizontal platforms and instant-death toxic transfer gaps.
- Clone grunt patrol/chase/retreat/strafe/shoot AI with ledge awareness, procedural gait/recoil feedback and elite variant support.
- Pixel-safe camera look-ahead that exposes upcoming threats without fractional-pixel shimmer.
- Android debug APK CI build, verification, and artifact upload.

## Current Asset / Animation Work

- Player production atlases remain preserved; no source sprites are redrawn.
- Nada's broken firing frame range (old frames 34-39) is bypassed because it crosses source-pose boundaries and contains clipped neighboring pixels. Stage runtime currently uses clean full-body ready-fire frames until the dedicated production firing strip is wired into the repository.
- Player sprites are displayed slightly larger on the 240x160 viewport so more authored detail remains legible on phones while retaining the standardized gameplay hitbox.
- Clone grunt production art is shown closer to native resolution. Full enemy sheet normalization into true walk/fire/hit/death frame strips remains a priority.

## Stage 1 Current Flow

Stage 1 is the vertical-slice quality bar. Current authored flow:

1. Safe movement / firing runway.
2. First readable pit with optional high route.
3. Crossfire lockdown: two staggered-height enemies must be cleared to open the sector gate.
4. First checkpoint and recovery jump.
5. Vertical-priority chamber with a timed lift rather than static staircase spam.
6. Toxic transfer line with two lethal gaps and a moving bridge route.
7. Second checkpoint and pressure-lock arena.
8. Wide toxic trench with moving platform and upper skill route.
9. Final mobile-enemy gauntlet without pit pressure.
10. Elite kill-floor clearance; exit remains sealed until the elite enemy is defeated.

## Known Issues / Next Priorities

1. Normalize full enemy production sprite sheets into transparent, consistently anchored walk/fire/hit/death animation strips.
2. Wire the dedicated clean Nada firing strip into the persistent repository asset pipeline.
3. Replace foundation environment placeholders with production tiles / props assembled from the clean source asset library.
4. Add Acid Spitter as the second true enemy archetype with arc projectiles / puddle hazard behavior.
5. Add the dedicated Killing Floor Rotor Stage 1 boss with three readable phases and boss HUD.
6. Implement ladder traversal using the supplied ladder artwork.
7. Add enemy respawn rules / checkpoint reset behavior matching the master rules.
8. Continue mobile HUD/control polish based on device testing.
9. Build repeatable visual regression / gameplay capture tests before declaring any stage production-ready.
10. Add soundtrack later; audio system remains soundtrack-agnostic until the MIDI Maximum Clonage arrangements are ready.

## Quality Rule

A successful APK export is not the quality bar. A feature is considered production-ready only after it works in-engine, survives CI, is playable on the target Android device, and has been visually/gameplay tested at the real 240x160 presentation scale.

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
- Clone grunt patrol/chase/retreat/strafe/shoot AI with edge awareness.
- Android debug APK CI build, verification, and artifact upload.

## Current Asset / Animation Work

- Player production atlases remain preserved; no source sprites are redrawn.
- Nada's broken firing frame range (old frames 34-39) is temporarily bypassed because it crosses source-pose boundaries and contains clipped neighboring pixels. Stage runtime now uses clean full-body ready-fire frames until the dedicated production firing strip is normalized.
- Clone grunt production art is shown closer to native resolution. Full enemy sheet normalization into true walk/fire/hit/death frame strips remains a priority.

## Current Level Design Goals

Stage 1 is being treated as the vertical-slice quality bar. Current authored flow:

1. Safe movement / firing runway.
2. First readable pit with optional high route.
3. Crossfire bay with staggered elevations.
4. First checkpoint and bridge-choice jump.
5. Staircase chamber teaching vertical target priority.
6. Two short transfer gaps with recovery platforms.
7. Second checkpoint and pressure arena.
8. Moving crossfire plus commitment jump.
9. Pre-exit enemy gauntlet without pit pressure.
10. Decompression / exit approach.

## Known Issues / Next Priorities

1. Normalize full enemy production sprite sheets into transparent, consistently anchored animation frames.
2. Normalize dedicated player firing/aiming strips, starting with Nada, without clipping or pose-boundary contamination.
3. Replace foundation environment placeholders with production tiles / props assembled from the clean source asset library.
4. Add more enemy archetypes and encounter behaviors so Stage 1 is not clone-grunt-only.
5. Add the Stage 1 miniboss/boss and boss arena.
6. Implement ladder traversal using the supplied ladder artwork.
7. Continue mobile HUD/control polish based on device testing.
8. Build repeatable visual regression / gameplay capture tests before declaring any stage production-ready.
9. Add soundtrack later; audio system remains intentionally soundtrack-agnostic until the MIDI Maximum Clonage arrangements are ready.

## Quality Rule

A successful APK export is not the quality bar. A feature is considered production-ready only after it works in-engine, survives CI, is playable on the target Android device, and has been visually/gameplay tested at the real 240x160 presentation scale.

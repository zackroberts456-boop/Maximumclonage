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
- Stage 1 expanded to twelve authored rooms with three checkpoints.
- Three progression-lock combat gates so major encounters cannot be skipped by sprinting past them.
- Multiple platforming patterns: recovery-brace jump, maintenance staircase, lift-shaft timing, low/high toxic-sluice routes, multi-jump trench, descending maintenance stacks, and pre-boss traversal.
- Moving vertical/horizontal platforms with visible travel rails and instant-death toxic transfer gaps.
- True ladder traversal is integrated into Stage 1 using the existing production climb frames. Players mount with vertical D-pad input, climb smoothly, pause on rungs, automatically step onto top/bottom surfaces, and can jump-dismount. Weapon fire is disabled while climbing so the state stays readable.
- Ladder collision/routes are placed beside platform edges rather than through solid platforms, preventing top-rung collision traps.
- Elevated geometry receives visual supports so collision/platform art reads as connected architecture rather than floating blocks.
- Enemy spawn helpers align character feet to the actual collision surface, and ladder landing zones are kept clear of unavoidable enemy-body collisions.
- Clone grunt patrol/chase/retreat/strafe/shoot AI with ledge awareness, procedural gait/recoil feedback and elite variant support.
- Acid Spitter is now a second true enemy archetype: slower positional AI, readable green windup, high arcing glob projectile, 2 HP direct hit, and a short-lived acid puddle that damages players who remain in it. Its attacks are intended to alter movement decisions rather than function as another straight-line gunner.
- Pixel-safe camera look-ahead exposes upcoming threats without fractional-pixel shimmer.
- Dedicated Stage 1 boss: Killing Floor Rotor, with three health-driven attack phases, telegraphed windups, boss HUD, boss checkpoint reset behavior, and sealed arena progression.
- Android debug APK CI build, verification, and artifact upload.

## Current Visual / Asset Work

- Player production atlases remain preserved; no source sprites are redrawn.
- Nada's broken firing frame range (old frames 34-39) is bypassed because it crosses source-pose boundaries and contains clipped neighboring pixels. Stage runtime currently uses clean full-body ready-fire frames until the dedicated production firing strip is wired into the repository.
- Player sprites are displayed slightly larger on the 240x160 viewport so more authored detail remains legible on phones while retaining the standardized gameplay hitbox.
- Clone grunt now uses the high-detail 224x224 production source image at a controlled gameplay scale. Its collider/AI are unchanged from the proven build, so this is a visual fidelity upgrade rather than a balance regression.
- Acid Spitter uses its own high-detail 224x224 production artwork and a distinct silhouette/attack language.
- The production Killing Floor Rotor sprite is in the persistent runtime asset tree and is used by the real boss encounter.
- Stage 1 v0.7 replaces the old repeated-wall presentation with a 240x976 authored laboratory atlas containing six distinct 240x160 environment themes. Two adjacent rooms share each theme so spaces feel connected while the campaign still changes visually as the player advances.
- Stage collision now renders with a dedicated 128x16 production foreground tile strip (eight 16x16 tile variants). Collision dimensions remain identical to the proven platforming build.
- Climb routes retain low-intensity route beacons so ladders read clearly on a phone without turning the stage into UI signage.
- Mobile controls use a lighter glass/translucent presentation. Touch hit areas remain unchanged while the visible D-pad/buttons occupy less of the playfield.
- CI smoke tests now validate the production image resources and their exact expected dimensions so asset corruption/truncation is caught before an APK is published.

## Stage 1 Current Flow

Stage 1 remains the vertical-slice quality bar. Current authored flow:

1. Safe movement / firing runway; one familiar Clone Grunt establishes baseline combat.
2. First toxic-jump section with optional high route and the first Acid Spitter introduction on safe ground, teaching the visible arc and puddle behavior without combining it immediately with a lockdown.
3. Crossfire lockdown with staggered Clone Grunt target heights.
4. Checkpoint + maintenance climb with real ladder access between vertical tiers and no pit pressure.
5. Lift-shaft timing jump with moving platform; an elevated Acid Spitter makes the player react to arcs while changing height.
6. Toxic sluice with distinct low island route and ladder-connected high route.
7. Second checkpoint + pressure lockdown.
8. Long toxic trench with moving low route and ladder-connected fixed upper route; a high Acid Spitter creates a readable area-denial problem rather than a landing-zone body trap.
9. Descending maintenance-stack platform sequence over a long trench with a safe ladder entry from the left floor edge.
10. Three-enemy Clone Grunt lockdown gauntlet with multiple firing elevations.
11. Pre-boss two-gap traversal, vertical maintenance route, final Acid Spitter pattern check, and final checkpoint.
12. Killing Floor Rotor boss arena; no pits, pattern-learning focus, optional tactical high-ground ladders, exit opens only after the boss dies.

## Known Issues / Next Priorities

1. Normalize the full Clone Grunt production sheet into consistently anchored walk/fire/hit/death animation strips and replace the temporary procedural single-pose motion.
2. Normalize Acid Spitter's supplied idle/attack strips and wire them into the new AI so its high-detail production pose becomes fully animated rather than procedurally pulsed.
3. Wire the dedicated clean Nada firing strip into the persistent repository asset pipeline and eliminate the final temporary ready-fire workaround.
4. Continue foreground/environment composition so each Stage 1 room uses props and foreground silhouettes that correspond to its actual gameplay geometry, not just its background theme.
5. Expand Rotor boss visual feedback with a fully animated production strip rather than a single production pose.
6. Add enemy respawn rules / checkpoint reset behavior matching the master rules.
7. Continue mobile HUD/control polish based on device testing.
8. Add ladder-specific top/bottom transition poses and direction-aware hand cadence after the base traversal is proven on-device.
9. Build repeatable visual regression / gameplay capture tests before declaring the Stage 1 slice production-ready.
10. Add soundtrack later; audio remains soundtrack-agnostic until the MIDI Maximum Clonage arrangements are ready.

## Quality Rule

A successful APK export is not the quality bar. A feature is considered production-ready only after it works in-engine, survives CI, is playable on the target Android device, and has been visually/gameplay tested at the real 240x160 presentation scale.

# GDD-04 GitHub candidates (approved actions, results pending)

Approved GDD-04 decisions: FORMATION-001 B, TURN-001 C, TARGET-001 C, AUTO-BATTLE-001 C, BATTLE-VIS-001 C. This file is a research shortlist. Owner approved GH-017/018/019 TEST and GH-020/021/022 STUDY on 2026-11-22. TEST means isolated Lunex proof of concept; STUDY means read-only inspection. No integration permitted.

| ID | Repository | Proposed action | Value and caveats |
|---|---|---|---|
| GH-017 | https://github.com/derdrache/Turn-Based-System-Plugin | TEST | Godot 4 plugin with classic/value/dynamic turn orders, targeting, command menu and turn order UI; 2D/3D. Test 9v9, AP/initiative combination and extensibility. Verify LICENSE and dependencies before reuse. |
| GH-018 | https://github.com/sion-rgb/tactical-slash | TEST | Godot 4.7 3D tactics demo with animated models, class-aware AI, healing, touch gestures and Android APK. 10x10 movement grid differs from fixed 3x3 formation; test only relevant mechanics. Code MIT claimed; separately audit third-party assets. |
| GH-019 | https://github.com/BennyTheHeal/godot-turn-based-battle-kit | TEST | Godot 4.5+ MIT kit with speed order, skills, statuses, enemy AI and tests. Dependency on included Inventory Kit. Inspect suitability for team-phase AP, deterministic headless combat and 9v9. New/small project, not proven production framework. |
| GH-020 | https://github.com/edicervantes/cervantes-tactics-godot | STUDY | 3D diorama scene, data-driven units, attack/heal/defend, AI, scene transitions and smoke tests. Code MIT; original art/audio restricted and story CC BY-NC-ND. Study architecture only, do not copy protected content. |
| GH-021 | https://github.com/a-magno/godot-turn-based-framework | STUDY | CombatActor, turn and command queues, skills, statuses; undo/redo command queue described as WIP. Check license, deterministic turn transitions and architecture. |
| GH-022 | https://github.com/michaltomczykowski/godot-ai-animation-toolkit | STUDY | Native Godot animation clips, AnimationTree, rigs, retargeting and editor workflows, relevant to Meshy 3D battle models. Requires Godot AI 4.4.2+ and Godot 4.7.2; known Linux editor issue. Study dependencies/license before any isolated test. |

## Technical recommendation (not implementation)
1. Use server-authoritative battle state: formation slots, combatants, stats, initiative/AP, queued commands, targeting and event log. Clients submit intent; server validates and resolves.
2. Each team uses up to 9 logical slots (3 rows x 3 columns). Party progression unlocks additional usable slots; exact thresholds are a future GDD-05 decision.
3. Hybrid team turns with initiative and AP need explicit rules for action order, costs, timeout, status effects and interrupt/resume. No third-party kit currently proves that full ruleset.
4. Tactical AI and auto-battle should use the same legal-action evaluator as manual commands, with configurable priorities, healing thresholds and target scoring. Protect against endless loops and invalid actions.
5. Dedicated 3D arena loads reusable environment elements based on location metadata; Godot editor PackedScenes and exported properties control cameras, slots, VFX and UI. Server event log drives animation timelines; animation does not control damage.
6. Mobile: test 9v9 actor counts, draw calls, VFX limits, touch targets, Android memory and headless server tests. Original/commercially licensed art only.

## Research evidence
README reviewed via GitHub connector for GH-017 through GH-022. No candidate cloned, run, installed or integrated in AtlanticAOnline. Candidate licenses and asset-specific rights must be checked before use. Prior GH-001 and GH-005..014 retain their documented incomplete checks.

## Owner approval (2026-11-22)
- GH-017 TEST; GH-018 TEST; GH-019 TEST: run only in isolated Lunex test directories.
- GH-020 STUDY; GH-021 STUDY; GH-022 STUDY: read-only source/license review only.
- No candidate integration, no changes to the game, and no promotion of prior pending test statuses.

## Isolated Lunex results (2026-11-22)
Environment: Godot 4.7.2 Linux, temporary `/var/tmp/atlantica-gdd04.WszPnL`. Source game repository untouched. Import was headless editor mode; launch was 15 frames in headless mode, not visual playtesting.

| ID | Commit tested | Import | Startup | Further evidence / limitations |
|---|---|---|---|---|
| GH-017 | `92dc7d936a2129099889923a5c659ccacb06079c` | exit 0 | exit 0 | No detected Godot errors in startup/import logs. MIT LICENSE. Not tested: 9v9, team initiative/AP, targeting UI, Android. |
| GH-018 | `8bf8d835cb7afa7cb3f4d893b0966c6b4e9b7727` | exit 0 | exit 0 | Bundled headless core test runner exit 0, reported PASS for damage, range, LOS, healing, AI priorities, touch input, GLB animation mapping, asset license records and other assertions. MIT code LICENSE. Still not proof of 3x3 formation, 9v9 or device FPS. |
| GH-019 | `d8814a0be782de48061d03d57ec3e6286f930b2d` | exit 0 | exit 0 | Bundled battle kit tests: **27 passed, 0 failed**, exit 0. MIT LICENSE. Still not proof of server authority, team initiative/AP, 9v9 or Android performance. |

All test clones isolated. No code or assets integrated. GH-017's turn UI/9v9 is not functionally verified by startup. Further tests require only the previously approved isolated TEST scope; integration needs new approval.

## Read-only studies (2026-11-22)
- **GH-020:** Reviewed `CONTENT_LICENSE.md`: MIT code; narrative/worldbuilding CC BY-NC-ND 4.0; original artwork/UI/audio explicitly restricted to Cervantes Tactics. Do not reuse protected content in commercial AtlanticA. Useful architectural reference: editable diorama arena, data-driven units, battle transitions.
- **GH-021:** Reviewed README: `CombatActor`, turn and command queue, skill/status primitives. Command queue undo/redo marked WIP. Root `LICENSE` request returned 404; do not assume commercial reuse rights. Read-only study only.
- **GH-022:** Reviewed README and root `LICENSE`: toolkit MIT, requires Godot AI 4.4.2+ and Godot 4.7.2; documented intermittent Linux editor crash. Promising for editable animation clips/AnimationTree/rigs but dependency and stability review required. No installation or runtime test authorized.

Prior GH-001 and GH-005..014 statuses remain unchanged; none of their open checks were claimed completed.

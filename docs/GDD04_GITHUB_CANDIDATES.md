# GDD-04 GitHub candidates (proposed, not approved)

Approved GDD-04 decisions: FORMATION-001 B, TURN-001 C, TARGET-001 C, AUTO-BATTLE-001 C, BATTLE-VIS-001 C. This file is a research shortlist. All candidates below require separate owner approval. TEST means isolated Lunex proof of concept; STUDY means read-only inspection. No integration permitted.

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

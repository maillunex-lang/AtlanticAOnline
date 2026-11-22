# GDD-06 GitHub candidates - approved evaluation (2026-11-22)

Approved: CLASS-001 C, ROLE-001 C, STATS-001 B, LEVEL-001 B, PROGRESSION-001 C. Research shortlist only: Owner approved GH-029/030/031 TEST and GH-032/033/034 STUDY on 2026-11-22. Isolated tests and read-only studies only; no integration authorized.

| ID | Repo | Recommendation | Evidence, fit and cautions |
|---|---|---|---|
| GH-029 | https://github.com/CodingQuests/godot-stats-leveling | TEST | Godot 4.7+, stat components, flat/percent source-tagged modifiers, XP curves, multiple level-ups and stat points; compatibility renderer; claims tested on 4.7.2 Windows. Test Linux Godot 4.7.2 and modifier ordering/150 cap. MIT LICENSE verified. Client-side demo cannot be server authority. |
| GH-030 | https://github.com/BennyTheHeal/godot-skill-tree-kit | TEST | Godot 4.5+ talent ranks, prerequisites, row gates, reset, bonuses and UI; bundled headless tests. Depends on Inventory Kit bundled in repo. Test prerequisite integrity, respec and export. MIT LICENSE verified; bundled placeholder art vs optional external art requires asset audit. |
| GH-031 | https://github.com/NicolasIRAGNE/GodotAgnosticSkillTree | TEST | Data-driven talent graph, editable Inspector fields, runtime SkillTreeView, export/import of unlock state, 28-skill demo; README claims Godot 4.7.2 testing. Excellent fit for user requirement of Godot desktop editor customization. MIT LICENSE verified. Server must validate costs/prerequisites. |
| GH-032 | https://github.com/LiGameAcademy/godot_ability_system | STUDY | Godot 4.5+ resource-driven gameplay ability, attribute, status and effect components. Architectural candidate for class definitions and hybrid role branches, but does not itself implement our class creation/specialization policy. MIT LICENSE verified; evaluate dependency and client/server boundary. |
| GH-033 | https://github.com/siwanetzu/rpg_stats-addon-for-Godot-4 | STUDY | Lightweight classless Godot 4 stat module with STR/DEX/VIT/INT/MAG/AGI, derived stats, flat/percent modifiers and JSON persistence. MIT LICENSE verified. One-commit project; local JSON unsuitable for MMO authority, formulas need audit. |
| GH-034 | https://github.com/NarkoPraxis/VisualSkillTreeEditor | STUDY | Godot 4 visual talent editor, dependency arrows, rank-up chains, custom effects, JSON import/export and purchase simulation. MIT LICENSE verified. Editor is a content authoring tool, not a secure runtime talent system. |

## Technical design recommendation (not implementation)
- **Class catalog**: server-versioned class and specialization IDs, allowed equipment/skill tags, role tags and skill unlock rules. Do not choose exact classes, class counts or unlock thresholds before owner approval.
- **Stats**: server owns primary and derived values; deterministic modifier pipeline with explicit flat, additive %, multiplicative %, rounding, caps and snapshot checks. Exact formulas remain undecided.
- **Leveling**: authoritative XP events and level cap 150, server validates rewards and multi-level XP grants; future cap expansion uses schema/content versioning.
- **Talents**: versioned directed acyclic graph, prerequisite and rank checks, server-validated point spending/refunds, audit log and rollback-safe mutations. No client-trusted talent changes.
- **Saved builds**: save class/specialization, talent allocation, equipment/skill layout and optional preferred party preset as stable IDs; validate switching restrictions and conflict resolution on server. Build count and respec costs undecided.
- **Godot visual editing**: class selection, character sheet, talent tree and build preset views as editable scenes and resources. Runtime UI displays server-approved definitions; Android touch, 6 GB RAM floor and landscape layout tested separately.
- **Acceptance matrix**: modifier stacking, level 150 cap, XP boundaries, prerequisite cycles, invalid talent grants, class-specific skill rules, specialization unlock, saved-build conflict, reconnect, concurrent device updates, Android performance.

## Evidence and boundaries
Public GitHub README research and connector fetch of root LICENSE for all six repositories. All six LICENSE files state MIT. Repository documentation is not a substitute for running the demos, auditing dependencies or confirming asset rights. No GH-029..034 actions beyond research approved; no source copied into the game. All earlier GH-001 and GH-005..025 incomplete checks preserved unchanged.

## Owner-approved scope (2026-11-22)
- GH-029, GH-030, GH-031: isolated TEST on VPS Lunex, no integration.
- GH-032, GH-033, GH-034: read-only STUDY, no installation in main game.
- All incomplete previous candidate checks remain open.

## Isolated Lunex test results (2026-11-22)
Environment: Godot 4.7.2 Linux, isolated disposable clone directory `/var/tmp/atlantica-gdd06.kfs6mw`. Editor headless import and 15-frame headless startup are smoke tests, not gameplay or Android validation.

| ID | Tested commit | Import | Startup | Additional result |
|---|---|---|---|---|
| GH-029 | `2a34ffac88ce4d7d20dea758bc570c573272810c` | exit 0 | exit 0 | No ERROR/SCRIPT ERROR lines in import/startup logs. Stat math, level 150 and UI unverified. |
| GH-030 | `ad47763d73f6c4f0e71caa2c6bd40c5e33a8c3a2` | exit 0 | exit 0 | Bundled skill-tree tests **19 passed, 0 failed** (exit 0). Server-validated respec, Android and editor UI unverified. |
| GH-031 | `5652825461a6fad3a65d707097ee515031641b1f` | exit 0 | exit 0 | No ERROR/SCRIPT ERROR lines in import/startup logs. Visual editor interactions, prerequisites and mobile UI unverified. |

All three have root MIT LICENSE files. No production code touched, no integration performed. Headless engine logs include a root/superuser warning, not a gameplay error.

## STUDY outcomes (read-only)
- GH-032: README describes Godot 4.5+ data-driven ability, attribute, status and vital-attribute components, behavior-tree ability logic, resource-defined effects, costs and cooldowns. Useful for hybrid classes and buffs; client-side components do not replace Go server authority. MIT verified in prior research.
- GH-033: README describes lightweight classless STR/DEX/VIT/INT/MAG/AGI, flat/percent-add/percent-multiply stat stages and JSON player persistence. Formula reference only; client JSON is not trusted MMO persistence. MIT verified.
- GH-034: README describes Godot 4 visual editor with dependency arrows, rank-up links, configurable node properties, JSON import/export and purchase simulation. Good authoring reference; generated JSON requires server-side validation. MIT verified.

## Remaining checks
Class specialization, 150-level XP cap, stat stacking, talent prerequisites, build save/restore, multi-device conflicts, visual editor workflow, Android 6GB performance and server-authoritative security remain pending. Earlier GH-001, GH-005..014, GH-017..019 and GH-023..025 incomplete tests remain unchanged. No third-party code integrated.

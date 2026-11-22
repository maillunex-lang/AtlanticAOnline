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

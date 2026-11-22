# GDD-05 GitHub research candidates (awaiting separate approval)

Owner approved SLOTS-001 B, FORMATION-002 B, MERCENARY-001 C, PRESET-001 C, CONTROL-001 C on 2026-11-22. This is research only. TEST = disposable isolated test on Lunex; STUDY = read-only code/license review. Neither allows integration.

| ID | Repository | Proposed | Fit and limitations |
|---|---|---|---|
| GH-023 | https://github.com/GabrielOlivierDEV/PartyManagerFramework | TEST | Godot 4.4.x party management, character IDs, add/remove/reorder, control switching and follower positions. MIT LICENSE verified. It manages a leader with up to 4 followers in exploration, **not** 3x3 turn-based formation or server-authoritative 9v9; study/test only reusable roster APIs. |
| GH-024 | https://github.com/CodingQuests/godot-inventory-system | TEST | Godot 4.7+ GDScript slot UI, drag-and-drop/swap, separate data and UI, serialization. MIT LICENSE verified. Designed for inventory items, **not** unique mercenary instances. Test UI interaction and 3x3 slot adaptation only in isolation. |
| GH-025 | https://github.com/CodingQuests/godot-save-system | TEST | Godot 4.7+ versioned JSON save slots, atomic writes and migration. MIT LICENSE verified. Good reference for preset schema/migrations, but **local JSON is not trusted MMORPG persistence**; authoritative presets must live on server/PostgreSQL. |
| GH-026 | https://github.com/vogitcode/Tactical-RPG | STUDY | Godot 4.6 layered Core/Facade/Adapter/Visual architecture, grid occupant data, turn control, legal-action boundaries. Root LICENSE not found (404), so code reuse rights not established. 2D tactical map differs from fixed 3x3 formations. |
| GH-027 | https://github.com/sanskarIN/RuneGrid-Tactics | STUDY | Godot 4 C# deterministic tactical roster, JSON content and replay/audit systems. MIT LICENSE verified. Requires .NET build and its core is an offline roguelite, not a Go authoritative MMO; architectural reference only. |
| GH-028 | https://github.com/expressobits/inventory-system | STUDY | Godot 4 multiplayer-compatible inventory with resources, specialized slot categories and separate UI; MIT LICENSE verified. C++/GDExtension dependency and item-centric architecture make it a heavier candidate for 3x3 party UI. |

## Evaluation and implementation boundaries
- **Party model:** stable hero/mercenary *instance IDs*, collection roster, unlocked slots, and presets. Exactly one hero required in active party, up to eight mercenaries, no duplicate instances, positions represented as 0..8 or (row,col).
- **Progression:** three initial active slots; later unlocks to nine. Unlock levels, preset count, collection capacity and per-class restrictions are *not yet specified*. Avoid inventing them.
- **Formations:** editing outside battle; in battle only authorized position-changing skills. Each preset stores nine optional slot references, control mode per mercenary, and version. Server checks ownership, unlocks, uniqueness and battle restrictions atomically.
- **Control:** per-unit AUTO/MANUAL state, plus whole-party toggle; auto uses same server-side legal-action engine as manual commands, not independent client authority.
- **Persistence:** PostgreSQL/Go authoritative source of truth; local cache and client UI are non-authoritative. Versioned data migrations and reconnect consistency tests needed.
- **Editor:** Godot scene-based formation screen, mercenary collection, preset selector, battle control widgets; touch drag/drop and fallback tap-to-select; customizable in desktop editor.
- **Test matrix:** initial 3 slots, unlock to 9, drag/drop swap, invalid locked cell, duplicates, dead/injured units, preset switching while combat active, reconnect, multi-device edits, per-unit AI toggles, Android 6GB performance.

## Research evidence
README and root LICENSE checked via GitHub connector for all six repos. Root LICENSE was missing for GH-026; others returned MIT. Source documentation does not establish actual compatibility with our 9v9, MMO authoritative Go server or Android performance. No repository cloned, tested or integrated during this GDD-05 research. Existing GH-001, GH-005..014 and GH-017..019 incomplete checks remain untouched.

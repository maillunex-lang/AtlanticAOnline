# ROADMAP

Status legend: PLANNED / APPROVED / IMPLEMENTED / TESTED.

| Stage | Scope | Status |
|---|---|---|
| GDD-01 | MMORPG foundations, world scope, combat direction, visuals, engine | APPROVED |
| GH-01 | GH-001 TEST; GH-002/003/004 STUDY approved; documentation review done; isolated GH-001 runtime test pending | APPROVED / IN PROGRESS |
| GDD-02 | World map, continents, cities and zones | APPROVED |
| GDD-03 | Exploration, travel and camera | IN DESIGN / AWAITING OWNER CHOICES |
| GDD-04 | Turn-based combat | PLANNED |
| GDD-05 | Formation and party control | PLANNED |
| GDD-06 | Hero classes and stats | PLANNED |
| GDD-07 | Mercenaries | PLANNED |
| GDD-08 | Skills and effects | PLANNED |
| GDD-09 | Equipment | PLANNED |
| GDD-10 | Quests and narrative | PLANNED |
| GDD-11 | PvE, bosses, dungeons | PLANNED |
| GDD-12 | Economy and crafting | PLANNED |
| GDD-13 | Guilds and city control | PLANNED |
| GDD-14 | PvP | PLANNED |
| GDD-15 | Social systems | PLANNED |
| GDD-16 | Android UI and performance | PLANNED |
| GDD-17 | Server, persistence, security | PLANNED |
| GDD-18 | Admin tools and editors | PLANNED |
| GDD-19 | Monetization and RuStore | PLANNED |
| GDD-20 | MVP, testing and release | PLANNED |

No third-party candidate has been integrated.

## Cross-cutting editor requirements (requested 2026-11-22)
- UI-EDITOR-001: all UI screens must be visually editable as Godot 4 scenes; acceptance criteria in `docs/EDITOR_ARCHITECTURE.md`. Status: REQUIREMENT RECORDED, NOT IMPLEMENTED.
- MAP-EDITOR-001: all locations and reusable objects must be visually editable in Godot 4; stable server IDs and export validation required. Status: REQUIREMENT RECORDED, NOT IMPLEMENTED.
- Verify in GDD-02, GDD-16 and GDD-18 and during each implementation milestone.

No external code integrated; no production deployment. GH-001 isolated runtime verification remains pending.

## GDD-02 follow-up (2026-11-22)
- Approved MAP-001 A, LOCATION-001 C, CITY-001 A, TRAVEL-001 C, EDITOR-001 C in `docs/GDD_DECISIONS.md`.
- GH-005/006/007/008: TEST approved, execution pending (Godot unavailable in current isolated runtime); GH-009/010: STUDY approved, README review completed; see `docs/GDD02_GITHUB_CANDIDATES.md`.
- GH-001: TEST approved, standalone runtime test PENDING. Do not claim completed.
- No candidate has been integrated into main game.

## Test evidence note (2026-11-22)
- No Godot binary or GitHub HTTPS access in current isolated container. No runtime TEST marked passed.
- GH-001 remains pending standalone execution. GH-005 through GH-008 remain pending standalone execution.
- No integration to game source authorized or performed.

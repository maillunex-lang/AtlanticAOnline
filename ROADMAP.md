# ROADMAP

Status legend: PLANNED / APPROVED / IMPLEMENTED / TESTED.

| Stage | Scope | Status |
|---|---|---|
| GDD-01 | MMORPG foundations, world scope, combat direction, visuals, engine | APPROVED |
| GH-01 | GH-001 TEST; GH-002/003/004 STUDY approved; isolated GH-001 gateway/server smoke passed; full client session and Android pending | APPROVED / IN PROGRESS |
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

No external code integrated; no production deployment.

## GDD-02 follow-up (2026-11-22)
- Approved MAP-001 A, LOCATION-001 C, CITY-001 A, TRAVEL-001 C, EDITOR-001 C in `docs/GDD_DECISIONS.md`.
- GH-005/006/007/008: isolated Linux tests run on Lunex with scoped passes and remaining checks; GH-009/010: read-only source studies completed. See `docs/GDD02_GITHUB_CANDIDATES.md`.
- GH-001: gateway, master and world registration, guest login, character creation/listing and admission endpoint exercised successfully. Full client session remains open.
- No candidate has been integrated into main game.

## Isolated test evidence (2026-11-22)

- Godot 4.7.2 confirmed on Lunex. Desktop and headless smoke results are documented in `docs/GDD02_GITHUB_CANDIDATES.md` and `docs/GITHUB_CANDIDATES.md`.
- Open: hands-on editor operations, full Road Tool demo and terrain integration, Android export and real-device performance.

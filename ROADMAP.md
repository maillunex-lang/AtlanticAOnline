# ROADMAP

Status legend: PLANNED / APPROVED / IMPLEMENTED / TESTED.

| Stage | Scope | Status |
|---|---|---|
| GDD-01 | MMORPG foundations, world scope, combat direction, visuals, engine | APPROVED |
| GH-01 | GH-001 TEST; GH-002/003/004 STUDY approved; isolated GH-001 smoke passed through client authentication and player spawn; gameplay and Android checks pending | APPROVED / IN PROGRESS |
| GDD-02 | World map, continents, cities and zones | APPROVED |
| GDD-03 | Exploration, travel and camera | APPROVED |
| GDD-04 | Turn-based combat | APPROVED |
| GDD-05 | Formation and party control | APPROVED |
| GDD-06 | Hero classes and stats | IN DESIGN / AWAITING OWNER CHOICES |
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
- GH-001: gateway, master and world registration, guest login, character creation/listing and admission endpoint exercised successfully. The Godot client authenticated over WebSocket and spawned a local player. Movement, map transfers, persistence after a restart and Android remain open.
- No candidate has been integrated into main game.

## Isolated test evidence (2026-11-22)

- Godot 4.7.2 confirmed on Lunex. Desktop and headless smoke results are documented in `docs/GDD02_GITHUB_CANDIDATES.md` and `docs/GITHUB_CANDIDATES.md`.
- Open: hands-on editor operations, full Road Tool demo and terrain integration, Android export and real-device performance.

## GDD-03 follow-up (2026-11-22)
- Approved MOVE-001 C, CAMERA-001 C, AUTO-001 C, EXPLORE-001 C, TRAVEL-MODE-001 C; recorded in `docs/GDD_DECISIONS.md`.
- GH-011/012/013/014 TEST approved: isolated Godot 4.7.2 import/startup smoke tests passed; interactive behavior, editor and Android tests pending. GH-015/016 STUDY approved: license/documentation review completed, including GDQuest noncommercial demo art restriction. See `docs/GDD03_GITHUB_CANDIDATES.md`. No integration authorized.
- Core recommendation: Godot built-in NavigationAgent3D/NavigationServer3D for zone navigation and separate world travel graph for intercity routes; server-authoritative movement.
- GH-001 and GH-005..GH-008 remain in their previously recorded partial test states; no status inflated.

## GDD-04 follow-up (2026-11-22)
- Approved FORMATION-001 B, TURN-001 C, TARGET-001 C, AUTO-BATTLE-001 C, BATTLE-VIS-001 C in `docs/GDD_DECISIONS.md`.
- GH-017/018/019 TEST approved: isolated Godot 4.7.2 import/startup passed. GH-018 bundled core test runner PASS; GH-019 bundled suite 27 passed/0 failed. GH-020/021/022 STUDY approved and completed at README/license-review level. 9v9, AP/initiative, editor and Android tests remain pending. See `docs/GDD04_GITHUB_CANDIDATES.md`. No integration authorized.
- Battle architecture recommendation: authoritative server-side 3x3 slot state, hybrid team turns with initiative/AP, common legal-action evaluator for manual/AI, and location-themed 3D arena driven by battle event log.
- Prior isolated test findings GH-001 and GH-005..014 remain unchanged and incomplete where previously documented.

## GDD-05 follow-up (2026-11-22)
- Approved SLOTS-001 B, FORMATION-002 B, MERCENARY-001 C, PRESET-001 C, CONTROL-001 C; recorded in `docs/GDD_DECISIONS.md`.
- Research shortlist `docs/GDD05_GITHUB_CANDIDATES.md`: GH-023/024/025 TEST and GH-026/027/028 STUDY approved by owner; isolated tests and read-only studies underway. No integration authorized.
- Authoritative server owns roster, 3x3 unlocked positions, formation presets and per-mercenary manual/auto flags; editable Godot scenes only render/submit intents.
- Prior GH-001, GH-005..014 and GH-017..019 test limitations unchanged; no third-party code integrated.

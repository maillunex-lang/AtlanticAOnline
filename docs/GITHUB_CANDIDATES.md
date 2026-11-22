# GitHub Candidates - GDD-01

Owner approved 2026-11-22: GH-001 TEST; GH-002 STUDY; GH-003 STUDY; GH-004 STUDY. No integration authorized. STUDY = review only; TEST = isolated proof-of-concept, no main-game integration.

| ID | Repository | Approved action | Notes |
|---|---|---|---|
| GH-001 | https://github.com/SlayHorizon/godot-tiny-mmo | TEST | MIT, experimental Godot 4 MMO architecture, gateway/world servers; validate scalability and Android |
| GH-002 | https://github.com/MeshLabDev/Grid-Tactics-Foundation | STUDY | MIT 2D tactics grid; does not implement Atlantica combat or 3D |
| GH-003 | https://github.com/boku-ilen/geodot-plugin | STUDY | GPL-3.0 geospatial GDExtension; license and Android compatibility need review |
| GH-004 | https://github.com/tessera-godot/tessera-net | STUDY | Alpha open-world replication, not production-ready; check license |

Review criteria before integration: license, latest maintenance, Godot compatibility, Android build, server trust boundaries, tests, performance, and scope of adaptation.

## Review findings (2026-11-22)
- GH-001: README states Godot 4.6+, unified client/gateway/master/world servers, WebSocketMultiplayerPeer, SQLite, AOI. Server-side anti-cheat and interpolation remain unchecked. TEST is limited to isolated evaluation; no game integration, no production deployment.
- GH-002: Godot 4.6 2D grid core with A* and headless tests; explicitly no combat, turn order or AI in free Lite. STUDY only.
- GH-003: Godot 4.x C++ GDAL GDExtension; requires geodata and builds. STUDY only, especially GPL/Android concerns.
- GH-004: alpha standalone C++ networking and Godot GDExtension, no production readiness; STUDY only.

TEST execution status GH-001: pending isolated runnable environment and validation; repository documentation reviewed, no test claimed completed.

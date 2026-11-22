# GitHub Candidates - GDD-02

Status: OWNER-APPROVED ACTIONS (2026-11-22). TEST means isolated execution only, STUDY means documentation/code review. No third-party integration authorized.

| ID | Repository | Approved action | Purpose / caveat |
|---|---|---|---|
| GH-005 | https://github.com/TokisanGames/Terrain3D | TEST | MIT terrain editor, sculpt, texture paint, LOD; mobile support experimental, validate Godot version and Android performance |
| GH-006 | https://github.com/fabian-becker/simple-asset-placer | TEST | 3D editor asset dock, placement, transforms, undo; license and version verification pending |
| GH-007 | https://github.com/The-Vector/scatterBox | TEST | Scatter props and PackedScenes on terrain; material limitations; license/performance verification pending |
| GH-008 | https://github.com/Nathan-Mrx/GodotRoadTool | TEST | Procedural roads and intersections; MIT; terrain deformation depends on Terrain3D; version/build checks |
| GH-009 | https://github.com/RodZill4/godot-openstreetmap | STUDY | OSM-to-3D demo unstable and older shaders broken; license and data attribution review |
| GH-010 | https://github.com/sanjaymeherdev/Grid-City-Maker | STUDY | Free city-grid generator, some tooling is paid; license and asset rights review |

Validation gates: exact license files, recent commits, release tags, Godot 4 compatibility, Android export, memory and FPS on weak devices, Godot editor workflow, testable standalone PoC, legal rights for geodata. OpenStreetMap attribution and share-alike obligations need legal review before using derived datasets.

## Prior candidate GH-001
Approved TEST from GDD-01; runtime PoC remains PENDING. Do not mark tested until independently launched, exercised and results recorded. No integration into main game.

## Approved candidate actions (2026-11-22)
GH-005 TEST; GH-006 TEST; GH-007 TEST; GH-008 TEST; GH-009 STUDY; GH-010 STUDY.

## Execution evidence
- Repository READMEs were inspected for all six candidates in the prior review. This is documentation-based study, not executable verification.
- GH-005 Terrain3D: GDExtension C++, terrain sculpting, texture painting, LOD; Android compatibility/performance unverified.
- GH-006 Simple Asset Placer: Godot editor dock, drag/drop, transform, undo; license and exact version still to verify.
- GH-007 ScatterBox: mesh/scene scatter, rotation and scale, erase; limitations with multi-material meshes; license still to verify.
- GH-008 Godot Road Tool: spline roads/intersections, terrain shaping depends on Terrain3D; Android build and compatibility unverified.
- GH-009 Godot OpenStreetMap: README reports unstable basic demo and obsolete shaders; STUDY only, no execution.
- GH-010 Grid City Maker: README describes free grid generator and paid advanced tooling; STUDY only, license and historical suitability unverified.
- GH-001 from GDD-01: TEST approved but still pending runtime verification.

## Runtime test blocker
The current isolated working container has no Godot executable and cannot reach GitHub over HTTPS; therefore no independent engine run, Android export or performance benchmark has been performed. All TEST actions remain PENDING EXECUTION, not PASSED. No source code imported into the main project.

## Isolated test acceptance checklist
1. Fetch pinned commit and verify LICENSE and dependencies.
2. Launch standalone sample with matching Godot 4 version; record logs and screenshots.
3. Test editor add/move/remove/undo and save/reopen (GH-005 through GH-008).
4. Check GH-005 and GH-008 interoperation, terrain seams, collisions and road edits.
5. Measure Android memory, FPS, draw calls and build/export compatibility on low-end device.
6. GH-001: independently launch gateway/master/world/client, verify login, movement, map transfers, persistence and server-side validation.
7. Write reproducible pass/fail evidence before requesting main-game integration.

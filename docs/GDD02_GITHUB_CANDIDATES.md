# GitHub Candidates - GDD-02

Status: PROPOSED; no owner approval yet. No third-party integration authorized.

| ID | Repository | Suggested action | Purpose / caveat |
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

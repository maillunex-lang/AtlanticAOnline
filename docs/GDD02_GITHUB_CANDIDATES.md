# GitHub Candidates - GDD-02

Status: OWNER-APPROVED ACTIONS (2026-11-22). TEST means isolated execution only, STUDY means documentation/code review. No third-party integration authorized.

| ID | Repository | Approved action | Purpose / caveat |
|---|---|---|---|
| GH-005 | https://github.com/TokisanGames/Terrain3D | TEST | MIT terrain editor, sculpt, texture paint, LOD; mobile support experimental, validate Godot version and Android performance |
| GH-006 | https://github.com/fabian-becker/simple-asset-placer | TEST | 3D editor asset dock, placement, transforms, undo; MIT confirmed in LICENSE; tested with Godot 4.7.2 |
| GH-007 | https://github.com/The-Vector/scatterBox | TEST | Scatter props and PackedScenes on terrain; material limitations; MIT confirmed in LICENSE.md; performance unverified |
| GH-008 | https://github.com/Nathan-Mrx/GodotRoadTool | TEST | Procedural roads and intersections; README declares MIT; standalone RoadTool license file absent in tested commit; terrain deformation depends on Terrain3D; version/build checks |
| GH-009 | https://github.com/RodZill4/godot-openstreetmap | STUDY | OSM-to-3D demo unstable and older shaders broken; license and data attribution review |
| GH-010 | https://github.com/sanjaymeherdev/Grid-City-Maker | STUDY | Free city-grid generator, some tooling is paid; license and asset rights review |

Validation gates: exact license files, recent commits, release tags, Godot 4 compatibility, Android export, memory and FPS on weak devices, Godot editor workflow, testable standalone PoC, legal rights for geodata. OpenStreetMap attribution and share-alike obligations need legal review before using derived datasets.

## Isolated checks on Lunex (2026-11-22)

Godot 4.7.2 Linux, disposable copies, separate writable directories and network namespace. Graphical editor startup used Xvfb and software OpenGL. Android arm64 export, device performance and manual editing remain open.

| ID | Tested revision | Observed result | Remaining |
|---|---|---|---|
| GH-005 | Terrain3D v1.0.2-stable release package | Demo starts headlessly (0); API persisted a height change and reloaded it (0). Editor plugin logged a DoubleSlider Nil-to-int error, and the graphical editor run timed out. Release contains Android ARM libraries. | Desktop editing workflow, Android export and profiling. |
| GH-006 | c3eca11dcf699abed89cabf1151036889000041c | Headless demo and graphical editor startup exit 0. Blender import was disabled in the test copy after the first import could not locate Blender. | Placement, transforms, undo and scene reopen in the editor. |
| GH-007 | bc0fdae3c939785a08b35bc34f0a19eb36aa0874 | Demo and graphical editor startup exit 0. Import warned about missing deadTree.mtl and tree1.mtl materials. | Brush placement and erase, scene reopen and Android performance. |
| GH-008 | a38c54b0e243c6c35fcaef47c8d4724223f5d0dc | Linux native extension built with a scoped godot-cpp profile. A minimal Curve3D test generated a road mesh (0). Upstream demo exited 1 with missing HDR and ExitDivider resources. | Full demo, terrain deformation, intersections, collisions, license file and Android binary/export. |

## Read-only source studies

- GH-009 (a3a9ca5c46ddcc956a7d4798ee835d749d711e42): MIT code license confirmed. The demo's tile loader can request bounding boxes over HTTP from the OSM API. Suitable as a reference for an offline import pipeline. OSM data is separately subject to ODbL. Do not adopt the demo runtime.
- GH-010 (53e29d2a7f40f8b488b41dea401871353ddad260): the grid generator groups roads, buildings and decorations, and serializes the scene via PackedScene/ResourceSaver. Study the editable-scene workflow. Modern street props and grid layouts are a poor fit for historic districts. The README permits commercial use of CityMaker.gd, while the repository did not provide a standalone license for all bundled assets. No execution or copying.

GH-001 server/HTTP smoke results are tracked in [GITHUB_CANDIDATES.md](GITHUB_CANDIDATES.md). Termalin job IDs: qw6nvg3cco (terrain persistence), asao4dufqn (asset demo), ynbf0eoac6 (graphical editor startup), n7md5amv9b (road build and upstream demo), fnjtgmxwjh (road geometry).

Integration status: no third-party code or assets added to the game.

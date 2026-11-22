# GDD-03 GitHub candidates (approved actions)

Owner approved GDD-03 design on 2026-11-22. Owner separately approved GH-011 TEST, GH-012 TEST, GH-013 TEST, GH-014 TEST, GH-015 STUDY, GH-016 STUDY on 2026-11-22. TEST = standalone evaluation on Lunex; STUDY = read-only analysis. Neither authorizes integration.

| ID | Repository | Proposed | Why and constraints |
|---|---|---|---|
| GH-011 | https://github.com/Wesley-Source/versatile-mobile-joystick | TEST | Configurable fixed/dynamic touch joystick, CanvasLayer and Input Map, MIT declared in README. Test Godot 4.7.2, Android multitouch, input-zone collision with camera gestures, UI editor resizing. |
| GH-012 | https://github.com/DoctorArta/godot-adaptive-camera-rig | TEST | Godot 4.6+ MIT camera rig, smooth orbit/zoom and SpringArm3D collision. Features target third-person action rather than fixed-angle MMORPG; test an isometric-style preset and touch gestures. |
| GH-013 | https://github.com/MacdonaldRobinson/Godot4-3D-Navigation | TEST | Minimal point-and-click 3D NavigationAgent/Region/Obstacle example. Check license before reuse, Godot 4.7.2, target changes, navmesh path and obstacles; standalone reference only. |
| GH-014 | https://github.com/mujtaba-io/godot-3d-minimap | TEST | Top-down SubViewport/Camera3D minimap without duplicate scene. Test renderer/memory costs on Android, fog/secret marker filtering, and server-authorized points of interest. License pending. |
| GH-015 | https://github.com/gdquest-demos/godot-4-3d-third-person-controller | STUDY | Reference for camera-relative character movement and camera controller; file-level web source exists, but GitHub README fetch returned 404. Verify repository and license before any reuse. |
| GH-016 | https://github.com/godotengine/godot-demo-projects | STUDY | Official Godot 3D navigation example; use as reference for built-in NavigationAgent3D, NavigationRegion3D and links, not an integration. Check individual example assets/licenses. |

## Architecture recommendation
- Use built-in Godot 4 NavigationServer3D/NavigationAgent3D as primary pathfinding; no third-party dependency required. Server remains authoritative for movement and zone transitions.
- World-wide automatic routes require a separate world graph of cities, portals, sea passages, transport schedules and access rules. Local 3D navmeshes alone cannot route across the planet.
- Global Earth overview stays visible; hidden points of interest are filtered by server-saved discovery state. Do not equate minimap visuals with security.
- Test scripts should exercise joystick/tap conflict, camera touch gestures, route cancellation, scene boundaries, camera collision, minimap cost and Godot editor persistence.
- Isolated Godot 4.7.2 Linux import/startup smoke tests have been run for GH-011..014; behavioral/editor and Android tests are still pending. Prior GH-001 and GH-005..008 tests remain separately tracked.

## Review limitations
Candidate feature descriptions are based on GitHub READMEs and Godot documentation. No candidate license is considered verified unless explicitly checked against a LICENSE file. GitHub code, art, icons and shaders may have different rights. No candidate was copied into AtlanticAOnline.

## Approval record
- 2026-11-22: GH-011/012/013/014 TEST, GH-015/016 STUDY. All testing restricted to isolated disposable copies on Lunex, no changes to game source.

## Lunex isolated smoke results (2026-11-22)

Environment: Godot 4.7.2 Linux headless, separate temporary directory `/var/tmp/atlantica-gdd03.3qJRvo`, no source copied to AtlanticAOnline. Tests executed import in editor mode and a 12-frame headless scene startup, not interactive control behavior.

| Candidate | Tested Git commit | Result | Open checks |
|---|---|---|---|
| GH-011 | bea520bbebfbc8ef22c42ca68feecfeeaf298721 | Import exit 0; headless startup exit 0; no ERROR lines in startup log. MIT LICENSE present. | Actual multitouch, touch zones, joystick drag, Android UI. |
| GH-012 | 84f6ec82257cee801a4a270f1839b0584722f68f | Created minimal project.godot **in disposable repository copy only** pointing to bundled demo; import 0, headless startup 0, no ERROR lines. MIT LICENSE present. | Touch orbit/pinch, isometric preset, camera collision, editor behavior. |
| GH-013 | c203e5d8980b5e57a3de3928e4c92f0657d999fc | Import 0, headless startup 0, no ERROR lines. No root LICENSE found; verify rights before reuse. | Click-to-move target, navmesh obstacles, rerouting, scene changes. |
| GH-014 | 06e82872fb76b05dd39e18c15e6387bce36bab88 | Import 0, headless startup 0, no ERROR lines. MIT LICENSE present. | Camera/SubViewport render validation, FPS and memory, hidden POI filtering. |

The final diagnostic shell wrapper exited 1 because `grep -c` returns status 1 for zero matches; individual Godot import and run commands all returned 0. No runtime functionality beyond startup was claimed tested.

## Read-only STUDY results
- GH-015 GDQuest 3D third-person controller: repository exists. Its LICENSE separates MIT-licensed source code and Godot resources from **CC-BY-NC-SA 4.0 art assets**. Noncommercial art cannot be included in this planned commercial game; do not import demo assets. Study only camera-relative movement architecture.
- GH-016 godotengine/godot-demo-projects: README says demo code is MIT and branches correspond to engine versions. Prefer version-matched Godot 4.7 demos when studying 3D navigation; verify any individual asset license before reuse. Study only.

All six actions remain isolated; no integration authorized or performed. Further functionality and Android validation need separate execution within existing TEST permission; adoption still requires separate approval.

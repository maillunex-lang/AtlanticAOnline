# GDD-03 GitHub candidates (proposed, not approved)

Owner approved GDD-03 design on 2026-11-22. These candidates require SEPARATE approval. TEST = standalone evaluation on Lunex; STUDY = read-only analysis. Neither authorizes integration.

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
- No standalone tests of GH-011..016 have been run. Prior GH-001 and GH-005..008 tests remain separately tracked.

## Review limitations
Candidate feature descriptions are based on GitHub READMEs and Godot documentation. No candidate license is considered verified unless explicitly checked against a LICENSE file. GitHub code, art, icons and shaders may have different rights. No candidate was copied into AtlanticAOnline.

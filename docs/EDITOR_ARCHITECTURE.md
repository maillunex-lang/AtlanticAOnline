# Editor-first architecture requirements

Status: USER-REQUESTED REQUIREMENTS, implementation pending. Applies to all future GDD stages.

## UI-EDITOR-001: Editable screens
- Every game screen is a standalone Godot 4 `.tscn` scene or reusable component, visually editable in desktop Godot Editor.
- Layout uses Control nodes, containers, anchors, theme resources and reusable UI components; avoid hard-coded coordinates where responsive layout is needed.
- Keep presentation separate from gameplay/network logic; screen rearrangement must not break interactions.
- Expose appropriate designer properties in Inspector; support Android landscape resolutions and safe areas.
- Keep scene assets and changes version-controlled.

## MAP-EDITOR-001: Editable locations
- Every location is a Godot 4 3D scene or composable scene chunks, editable in the desktop editor.
- Provide reusable PackedScenes for props, buildings, NPC markers, monster spawn markers, portals, loot and interactive objects.
- Support visual placement, rotation, scaling, terrain, materials and lighting; use exported properties and editor tooling where helpful.
- Give gameplay-relevant entities stable IDs; validate exports to server-authoritative world data. Editing local scenes must not grant authority over live server state.
- Plan for chunk streaming, LOD and Android optimization.

## Acceptance criteria
1. A designer can open any screen and move/resize/style its components without changing gameplay scripts.
2. A designer can open a location and add/move/delete reusable objects without modifying core code.
3. Gameplay markers export or validate IDs and server-side definitions.
4. Scene changes remain diffable/version-controlled and pass Android checks.

No editor tooling or code is implemented yet. No third-party libraries are approved for integration.

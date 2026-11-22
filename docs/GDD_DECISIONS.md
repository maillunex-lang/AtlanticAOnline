# GDD Decisions

## GDD-01 - Approved (2026-11-22)

- WORLD-001 A: Entire Earth world map, continents and major cities; content developed incrementally.
- GAME-001 B: Full MMORPG with multiple world channels.
- BATTLE-001 C: Classic 3x3 tactical turn-based combat with extended automatic battle mode.
- VIS-001 A: Classic Atlantica-like 3D visual direction with updated original graphics.
- TECH-001 A: Godot 4 Android client.

## Constraints
Do not integrate third-party code without separate owner approval. All artwork, narrative, brand and UI must be original or properly licensed. World-wide scope is a design target, not a claim of implemented content.

## GDD-02 - Approved (2026-11-22)
- MAP-001 A: Earth map closest in feel to classic Atlantica, recognizable continents, cities and travel routes at game scale.
- LOCATION-001 C: hybrid large open 3D zones with separate cities, buildings and dungeons.
- CITY-001 A: historical cities with markets, NPCs, trade and city functions.
- TRAVEL-001 C: mobile-friendly manual movement, autopathing, teleportation and quest navigation.
- EDITOR-001 C: hybrid Godot editor workflow with manual scene editing, reusable object library, environment generation and stable server-side entity IDs.

Design requirements: world overview and streamable playable zones are separate layers; no whole-continent Android loading; editor scene data and authoritative server state must be separated. No third-party implementation authorized.

## GDD-03 - Approved (2026-11-22)
- MOVE-001 C: hybrid tap-to-move and virtual joystick, switchable in settings; input separated from movement logic.
- CAMERA-001 C: classic angled/isometric-style camera by default, optional orbit and pinch zoom, editable Godot camera rig.
- AUTO-001 C: automatic routes to quests, NPCs, cities and marked map positions; player may interrupt manually.
- EXPLORE-001 C: open global world map with discoverable hidden points of interest and secrets; no mandatory global fog of war.
- TRAVEL-MODE-001 C: walking, transport, ships, teleports and automatic intercity routes.

Implementation boundaries (not yet authorized): world route graph + per-zone NavigationServer3D/NavigationAgent3D; server validates movement speed, reachable destinations, zone transfers and travel permissions. Client scene nodes and UI controls must be editable in Godot; Android performance and mobile touch controls to be validated. Do not implement or integrate any candidate before separate approval.

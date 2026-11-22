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

## GDD-04 - Approved (2026-11-22)
- FORMATION-001 B: player hero plus up to eight mercenaries on each side of a 3x3 formation; available unit count increases with player progression. Exact unlock thresholds deferred to GDD-05.
- TURN-001 C: hybrid team turns with initiative and action points. Specific turn timing, costs and simultaneous action rules deferred to battle balance design.
- TARGET-001 C: front rows normally protect rear rows; skills/classes can bypass the protection by explicitly defined rules.
- AUTO-BATTLE-001 C: configurable auto-battle priorities for skills, healing, defense, target selection and tactics, with manual override.
- BATTLE-VIS-001 C: dedicated 3D combat arena assembled from the current location's environment, with smooth transitions. Arena, formations, camera, animation and battle HUD must be visually editable in desktop Godot.

Engineering constraints: server-authoritative battle state and deterministic action validation; logical 3x3 formation slots are separate from rendered Node3D coordinates; battle animations are presentation of resolved events and cannot decide outcomes. Android landscape HUD and performance require validation. No third-party code integration authorized.

## GDD-05 - Approved (2026-11-22)
- SLOTS-001 B: initial party has three usable combat slots; progression unlocks up to nine total combatants (hero + up to eight mercenaries). Exact unlock levels remain to be designed; do not invent them.
- FORMATION-002 B: free rearrangement of active units among unlocked 3x3 slots outside combat; position changes during combat only through explicitly defined skills, subject to server validation.
- MERCENARY-001 C: large collectible roster of mercenaries; only up to nine combatants active including the player hero. Exact roster capacity, acquisition and progression deferred to GDD-07.
- PRESET-001 C: multiple customizable and persistent formation presets for PvE, PvP, bosses and other situations; number and unlock rules deferred to later balancing.
- CONTROL-001 C: hybrid manual control, full auto-battle, or per-unit automatic control; legal actions and tactics are validated by authoritative battle server.

Design constraints: formation slot state, ownership, unlocked slots, preset switching and active roster must be server-authoritative. No duplicate mercenary instance in one formation. Preserve consistent behavior on disconnect and across devices. All formation, collection and battle-control interfaces visually editable as Godot 4 scenes on desktop; mobile touch and drag/drop require testing. No third-party integration authorized.

## GDD-06 - Approved (2026-11-22)
- CLASS-001 C: main character selects a class at creation; class specializations unlock later. Exact class roster, specialization level, class-change rules and costs remain undecided.
- ROLE-001 C: base classes have hybrid combat roles and additional development branches. Specific roles, class counts and balance remain for subsequent decisions.
- STATS-001 B: primary stats plus accuracy, evasion, critical chance, defense, speed and resistances. Final names, formulas, caps, damage types and rounding are pending balancing.
- LEVEL-001 B: hero level cap 150 at initial design; cap may increase with later content updates. XP curves and mercenary progression not yet decided.
- PROGRESSION-001 C: levels, equipment, talent tree, specializations and saved character builds. Respec cost, number of builds and restrictions deferred.

Architecture boundaries: Go authoritative server computes class eligibility, XP, stats, equipment modifiers, talent prerequisites and build changes; Godot 4 presents editable scenes for class choice, character sheet, talents and loadouts. Data-driven definitions can be edited in Godot but must be validated/published to server. Preserve existing GDD-04 team turn initiative/AP and GDD-05 per-unit control. No third-party candidate integration authorized.

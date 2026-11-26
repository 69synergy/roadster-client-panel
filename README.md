# Roadster Client Panel

A self-contained client panel for Tesla Roadster Chase (place `122379697375766`). Initial implementation based on observed client object names and attributes, not the game's source code. Private development repository; no game assets or screenshots included.

## Features

- **Vehicle:** automatically matches `Cars/Roadster_*` by the local player's `Owner` attribute. Reads speed, gear, engine, acceleration/grip attributes, boost attributes and flight state. Reacquires the car after despawn/respawn.
- **Controls:** local chase/overhead cameras, camera FOV, camera reset, panel visibility and unload. Restores the previous camera on reset/unload; cleans up the previous panel when rerun.
- **Police:** nearest streamed `Police_*` models, distances, and optional occluded labels (up to 12). This does not establish which police are pursuing you.
- **Missions:** nearest objects under `MissionLocal` and `MissionSpots`, optional labels (up to 8), and a raw read-only view of `RaceState` attributes/direct ValueBase children. Mission progress/completion semantics are not yet known.
- Dark panel with pink accents, four tabs, scrollable content and touch-friendly buttons. Independent UI, not a verified reproduction of the linked reference library.

## Strict client boundary

The source reads already-replicated client objects. It creates only its own GUI and local BindableEvent and changes only the local camera. It does not access server containers, call or listen to game remotes, execute game modules, download dependencies at runtime, write vehicle attributes, change physical parts, simulate game input, or trigger prompts.

Vehicle tuning, flying, teleporting/flipping cars, auto-driving, collecting rewards, joining races and accepting/completing missions are intentionally outside this version: those can affect authoritative game state even when initiated on the client. Use the game's controls for those actions.

## Run

The deliverable is `src/main.client.luau`, a single client script with no external library dependency. Run its full source in your existing client scripting environment. For a Studio test fixture, place it in a LocalScript under StarterPlayerScripts and reproduce the fixture below. A server Script will not work.

No executor-specific APIs are required by the panel itself. Compatibility with your client environment has not been verified. Since this repository is private, unauthenticated raw-GitHub loaders will not work; do not embed a GitHub token in a loader.

- **Right Control:** hide/show panel.
- **End:** unload, remove markers and disconnect listeners.
- **Controls tab:** camera mode, FOV and reset. FOV applies only in panel camera modes. A game's own camera controller might conflict with these modes; reset returns control to the game.

Speed is shown in **studs/second** and distances in **studs**. No unverified conversion to the game's displayed mph/km/h is applied. `BoostSeconds` is labeled as an attribute, not assumed to be a live countdown. Missing/streamed-out data shows as unavailable, rather than being fabricated.

## Development checks

Requires Node.js and npm. Run `npm ci` then `npm test`.

Tests parse the entire source and enforce a strict call/service/property-write allowlist. This is a regression check for this self-contained source, not a sandbox or proof against arbitrary malicious rewrites. GitHub Actions runs the same tests. Lua 5.3 parsing is used for the deliberately Lua-compatible subset of Luau in this file.

**Validation status:** syntax and static boundary checks only. No live Roblox runtime or visual validation has been performed.

## Manual runtime checklist

1. With no car, launch the script: all tabs remain usable and vehicle data is unavailable.
2. Add/spawn a matching Roadster and an unrelated player's Roadster: only the matching `Owner` is selected. Delete and recreate the matching car: the panel reacquires it within one second.
3. Change velocity, gear and boost through normal gameplay; compare the panel against the attribute view. Check gear `-1`, false booleans and absent attributes.
4. Toggle police/mission labels, then remove their objects. Labels disappear without stale references. Check occlusion and the marker caps.
5. Switch cameras, respawn and replace CurrentCamera. Reset/unload restores the camera and removes all panel instances. Confirm rerunning leaves one panel and no old connections.
6. Test all four tabs at a narrow viewport and with long object names. Confirm scroll and touch buttons work.
7. Observe RaceState during a normal race and inspect mission data during a normal mission before implementing progress labels.

### Studio fixture

Create `Workspace/Cars/Roadster_<your UserId>` as a Model with a BasePart named `Chassis` as PrimaryPart, and an `Owner` number attribute equal to the test player's UserId. Optionally add `Gear`, `Engine`, `Accel`, `GripScale`, `BoostActive`, `BoostSeconds`, `Flying` and `Driver` attributes. Add a `Police_1` Model containing a BasePart under Cars. Add a part under `Workspace/MissionSpots`. Add `ReplicatedStorage/RaceState` as a Folder with a StringValue or attributes. No remotes or server scripts are needed for the fixture.

## Next evidence needed

An in-game panel screenshot/error log, observed mission state changes, and the game's speed units. The current source does not infer reward protocols or mission actions from remote names.

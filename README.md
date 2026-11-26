# Roadster Hub — Rayfield Gen2

Version 0.3 for Tesla Roadster Chase (place `122379697375766`). Uses the official [Rayfield Gen2 stable loader](https://docs.sirius.menu/rayfield-gen2/getting-started), with a rose theme and sidebar tabs.

## Run

Copy the **entire contents of `src/main.client.luau`** into your client executor and execute it. This is the generated, standalone bundle; do not run `core.luau` or `runtime.luau` separately. The environment must support `loadstring` and `game:HttpGet`. Rayfield is fetched from `https://sirius.menu/gen2` at startup. This executor build does not run as an ordinary Studio LocalScript without replacing that loader.

The GitHub repository is private, so unauthenticated raw-GitHub loaders cannot fetch it. No GitHub token is needed when pasting the bundle.

Enter your own Roadster's driver seat, open **Tuning**, set the target speed and acceleration, then enable **Speed assist**. All modifications start disabled and do not auto-load saved state.

- **Right Control:** hide/show Rayfield.
- **End:** unload, remove markers/lift force, restore camera and attribute overrides, and disconnect our listeners.
- **Disable all features:** stop tuning/flight and restore overrides while leaving the hub open.

## Implemented controls

| Tab | Features |
| --- | --- |
| Vehicle | Speed/gear/engine/attribute telemetry, brake, recover upright, disable all |
| Tuning | Throttle-based speed assist, target speed, acceleration, boost multiplier, sideways grip damping |
| Tuning / experimental | Reversible `Accel`, `GripScale`, `BoostScale`, and `RideHeight` overrides |
| Flight | Vehicle flight/hover, speed, keyboard or seat throttle/steering, vertical dropdown |
| Farm | Automatic movement to nearby visible coins, travel-speed slider, stall timeout and stop control |
| Camera | Game/chase/overhead modes, FOV, distance, reset |
| Police | Nearest streamed police vehicles, distances, optional markers |
| Missions | Nearby mission objects, optional markers, raw client-visible RaceState |
| Settings | Marker range, through-wall labels, Rayfield theme, disable/unload |

Speed assist adjusts forward/reverse velocity toward your selected target while throttle is held; releasing throttle leaves normal coasting, capped to the selected longitudinal target. Grip assistance dampens sideways motion. Normal driving preserves vertical velocity. Speed units are **studs/second**, not an assumed mph/km/h conversion. The boost multiplier applies to speed assist and flight; it does not unlock the game's boost upgrade.

Flight takes priority over speed/grip assistance. WASD moves relative to the camera, Space rises, Left Ctrl descends, and neutral input hovers using a local gravity-compensating force. On touch/controller, seat throttle and steering plus the vertical dropdown provide input if the game's seat exposes those values. Normal gravity resumes on disable. Existing vehicle controllers may interfere with this behavior.

## Coin quest collection

Enter your own Roadster with an active coin objective, then open **Farm → Auto collect visible coins**. The collector flies directly toward the closest rendered `LocalCoins/Coin`, slows near it, and lets the game's existing CoinController handle proximity collection. It ignores `CoinSparkle`, handles pooled coin visuals changing locations, skips stalled/unconfirmed targets for 30 seconds, pauses outside the game's Driving mode, and removes its lift when disabled or you leave the driver seat. Enabling it disables manual speed/grip/boost/flight controls; selecting manual flight disables collection.

The inspected progression config defines coin quests with **5 / 20 / 60** targets and **1,000 / 4,000 / 10,000** base cash rewards. Rewards are scaled/rounded using `Config.MoneyScale`; these are not verified final payouts. Coin visibility is gated by incomplete eligible coin objectives, including career progression after starter gating. Quest renewal is configured for 7,200 seconds after claiming, so this is not an unlimited cash loop.

**Claim rewards manually in the game's quest menu.** No claim protocol has been established. The collector does not invoke game modules, send remotes, grant cash or spoof quest progress. Its disappearance counter is a local observation, not server confirmation.

Only the nearby rendered pool is available (configured draw range 450 studs, pool size 12 desktop / 8 phone). There is no obstacle routing, teleportation or full-map exploration. While enabled with no visible targets it holds position; disable it to resume normal movement and find another area. Physical collisions and server movement corrections can block the route. Actual coin payouts and live collection are unverified.

## Scope and limits

Version 0.1 was display-only. Version 0.2 deliberately changes your owned vehicle's physics while you occupy its driver seat. These changes **may replicate when the client owns the vehicle's physics**. This is no longer a strictly local-effects panel, and it does not grant server authority or guarantee bypassing game limits.

Controls check the `Owner` attribute, actual seat occupant, the character's SeatPart, character health, and an unanchored chassis on every physics step. Exiting the driver seat pauses modifications and restores experimental attributes. Re-entering resumes enabled modes. Reacquisition handles a despawned/replaced car. Turning off features does not rewind your position or momentum.

The game may overwrite velocity/attributes or correct movement. Attribute names were observed in screenshots, but their effects on the game's controller are unverified. Original values are restored unless the game has supplied a newer value. Server modules, remote arguments, mission acceptance/completion and payout protocols remain unknown: there are no guessed remote calls, reward claims, or advertised upgrade unlocks. Police lists show proximity, not confirmed chase assignment.

Our code downloads only the official Rayfield endpoint and does not execute game modules or call game remotes. Rayfield is a live third-party dependency; our tests do not audit or constrain its internals. No game assets, private tokens or user screenshots are included in this repo.

## Development

- `src/core.luau`: control calculations, owner/driver gate, reversible attribute tracking.
- `src/runtime.luau`: Roblox integration and Rayfield Gen2 controls.
- `src/main.client.luau`: generated bundle used by the executor.
- `scripts/build.cjs`: deterministic single-file bundling.

Run `npm ci`, then `npm run build` after source edits, followed by `npm test`. Tests reject a stale generated bundle. GitHub Actions runs the same tests.

**Validation:** 15 tests cover syntax, source boundaries, acceleration/reverse/frame-time handling, grip damping, ownership/seat checks, attribute restoration, coin targeting/pooling/timeouts, and simulated runtime cleanup. The Lua VM fixture is a small Roblox/Rayfield behavioral double, not a physics engine or renderer. Actual Roblox execution, Rayfield rendering and server compatibility have not been verified.

## In-game test sequence

1. Launch with every toggle off. Confirm Vehicle identifies your Roadster and reports speed/gear.
2. Enter its driver seat. Enable Speed assist at a modest target and drive forward/reverse. Check steering direction, acceleration and camera alignment against the game.
3. Enable/disable grip and boost individually. Confirm the effective velocity changes and note any server corrections.
4. Enable flight at low speed, test vertical controls and hover, then disable it. Exit the seat and verify the lift effect stops.
5. Record attributes before enabling experimental overrides. Disable them and verify restoration; repeat after changing vehicles.
6. Test police/mission markers, camera reset, disable-all, End, rerun, and Rayfield's own unload action. Check that one hub remains and no controls continue after unload.
7. Send a screenshot/error log and which controls work. Mission progression still needs observed state changes before it can be mapped accurately.
8. With an active coin quest, enable collection near visible coins. Compare game quest progress to local disappearance observations, test stalled targets and stop, and claim a completed reward manually. Do not treat the local counter as money earned.

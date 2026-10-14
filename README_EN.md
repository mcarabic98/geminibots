# GeminiBots — smarter bots for Garry's Mod

This addon replaces the static behavior of stock bots (`bot`) with a full AI: bots roam the map, hear, fight, pick up weapons, chat and follow gamemode rules. Version 1.0.0.

## Features

- **Movement**: navmesh, jumps, crouching under low openings, breaking glass, opening doors, bunny-hop.
- **Combat**: smoothed aiming, target leading, spread, strafes, range-based weapon picks, arched grenades, glass wallbangs.
- **Senses**: vision cone, footstep/gunfire hearing, memory of targets behind cover.
- **Chat**: kill/death lines, smart context (K/D, streaks, ping), greetings and duels with players.
- **Weapons**: Arsenal window scanning installed packs (HL2, M9K, TFA, ArcCW, CW2.0, SWCS, FA:S), ground-weapon pickup.
- **Gamemodes**: SWCS (tactics, flashes, molotovs, C4), Murder, HL2 deathmatch, NPCs and PvE.
- **Menu**: standalone window with dark/light theme, RU/EN (auto from game language), ESP with boxes and skeletons.
- **Custom FSM states**: drop-in files in `data/`, no addon edits needed.

Details (in Russian for now): `docs/` — see [README.md](README.md) for the index.

## Requirements

- Garry's Mod, a map **with a navmesh** (bots stand still without one).
- Optional: ULX (`!bringbots` commands), SWCS, VJ Base / DrGBase, weapon packs.

## Install

1. Copy `geminibots` to `GarrysMod/garrysmod/addons/` (developers: `deploy_to_gmod.bat` mirrors the project via `robocopy /MIR`).
2. Start a map. No navmesh — an admin gets a generate offer 10 seconds after load (`nav_generate` by hand works too; the server freezes for minutes).
3. Console (`~`):
   ```console
   geminibots_add
   ```

## Quick start

| Command | What it does |
|---|---|
| `geminibots_add` | Add one bot |
| `geminibots_menu` | Open settings (`bind p geminibots_menu`) |
| `geminibots_weapons_menu` | Open the Arsenal |
| `geminibots_esp` | Toggle ESP (admins) |
| `geminibots_spawn_max` | Fill the server with bots |
| `geminibots_kick_all` | Remove all bots |

Menu and console settings persist in `data/geminibots/convars.json`. Server and client Lua apply only after a map change.

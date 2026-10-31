# warsync_smuggling — WarSync / Operation Warsim

Contraband smuggling system for the Civilians / Press faction. ESX + ox_inventory + NUI.

## Installation

1. Copy the `warsync_smuggling` folder into your `resources` folder.
2. Open `install/ox_items.lua` and paste every entry into `ox_inventory/data/items.lua`
   (inside the returned table). Optionally add item images to `ox_inventory/web/images/`.
3. In `server.cfg`, start it **after** its dependencies:
   ```
   ensure es_extended
   ensure ox_inventory
   ensure warsync_smuggling
   ```
4. In `config.lua`, set `Config.CivilianJobs` to your Civilians / Press job name(s) and
   `Config.AdminGroups` to your admin groups.
5. Restart the server. No SQL is needed (ox_inventory reads items from its Lua file; tables are saved to `data/tables.json`).

## Crafting tables

Admins stand where the bench should be and run:

| Command | Effect |
| --- | --- |
| `/smuggletable add` | Places a bench at your position (saved to `data/tables.json`) |
| `/smuggletable remove` | Removes the nearest bench (within 4 m) |
| `/smuggletable list` | Lists benches in the F8 / server console |

Fixed benches can also be added in `Config.Table.staticLocations`.
Only civilian jobs see the bench prompt and blip. Crafting needs no materials, takes `Config.CraftTime`
(default 120 s), and is cancelled (progress lost) with **X**, by dying or by walking away.

## Items

| Item | Use |
| --- | --- |
| Cluster Rocket Launcher + Cluster Rocket Pack | Use the launcher → long preload (eats 1 rocket pack) → aim and fire a cluster volley. Use it again to re-equip / preload. Homing: `Config.Launcher.homing.enabled` |
| Thermal Binoculars | Use to raise them. Mouse to look, wheel to zoom, Backspace to lower |
| Thermal Goggles | Use to toggle on/off, hands free |
| Mine / EMP Mine / Proximity Sensor | Use → preview → **E** to plant. Sensors can be disabled by others / picked up by the owner with **E** |
| Motion Tablet | Use to show/hide. Hold **LEFT ALT** (rebindable in Settings → Key Bindings → FiveM) to get a cursor and click POWER. 60 s of active time, then it breaks |
| Alcohol / 3 drugs | Use to consume. Durations and strength in `Config.Effects` |

There are no prices or shops: players agree on a price and hand the money over in RP.

## Security notes

- Crafting, preloading, firing, device placement, triggers, sensor disabling, tablet time and every
  item removal are validated server side (job, item counts, server-side positions, elapsed time).
- Heavy vehicle damage (launcher / mine) is decided by the server and applied by each vehicle's network owner.
- Explosions use the networked `AddExplosion` from the client the server chooses; as with every FiveM
  explosion, pair this with your anti-cheat explosion filter (allow types 3, 4 and 5 from this resource).

## Notes / tuning

- All balance values are in `config.lua`; weights are in `install/ox_items.lua`.
- The launcher uses `WEAPON_RPG` as a held model with native firing blocked. If your server's ox_inventory
  weapon anti-cheat strips weapons not in the inventory, set `Config.Launcher.weapon` to an addon weapon
  or whitelist it.
- The goggles helmet prop ids depend on your clothing pack (`Config.Goggles.prop`).
- Placed devices are kept in memory (they disappear on server restart).

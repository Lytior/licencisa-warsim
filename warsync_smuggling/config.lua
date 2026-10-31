--[[
    WarSync - Operation Warsim | Contraband Smuggling
    -------------------------------------------------
    Every balance value (damage, durations, radius, weights, craft time) lives here.
    Item WEIGHTS live in install/ox_items.lua (ox_inventory reads them from its own items file).
]]

Config = {}

Config.Debug = false

-- Jobs allowed to CRAFT contraband (the existing Civilians / Press job name(s) of your server).
Config.CivilianJobs = {
    ['civilian'] = true,
    -- ['press'] = true,
}

-- ESX groups allowed to place / remove crafting tables.
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true,
}

-- Key used to cancel any progress bar (73 = X). Control ids: https://docs.fivem.net/docs/game-references/controls/
Config.CancelKey = 73

---------------------------------------------------------------------------
-- CRAFTING TABLE
---------------------------------------------------------------------------
Config.Table = {
    model = 'prop_tool_bench02',
    interactDistance = 2.0,  -- distance to open the menu
    cancelDistance = 3.5,    -- walking further than this from the table cancels the craft
    saveFile = 'data/tables.json', -- tables placed with /smuggletable are saved here
    command = 'smuggletable',      -- /smuggletable add | remove | list
    blip = { enabled = true, sprite = 566, colour = 47, scale = 0.7, label = 'Contraband workbench' }, -- only civilians see it
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    -- Optional fixed tables (in addition to the ones saved by admins):
    staticLocations = {
        -- vector4(1273.9, -1710.4, 54.77, 120.0),
    },
}

-- Craftable items (order = order in the menu). time is in seconds. No ingredients: crafting only takes time.
-- tier is purely visual in the menu (common / rare / epic / legendary).
Config.CraftTime = 120
Config.Items = {
    { name = 'contraband_launcher',   tier = 'legendary', time = Config.CraftTime },
    { name = 'contraband_rocket',     tier = 'epic',      time = Config.CraftTime },
    { name = 'thermal_goggles',       tier = 'epic',      time = Config.CraftTime },
    { name = 'thermal_binoculars',    tier = 'rare',      time = Config.CraftTime },
    { name = 'contraband_mine',       tier = 'rare',      time = Config.CraftTime },
    { name = 'contraband_emp_mine',   tier = 'epic',      time = Config.CraftTime },
    { name = 'proximity_sensor',      tier = 'rare',      time = Config.CraftTime },
    { name = 'motion_tablet',         tier = 'rare',      time = Config.CraftTime },
    { name = 'contraband_alcohol',    tier = 'common',    time = Config.CraftTime },
    { name = 'drug_recreational',     tier = 'common',    time = Config.CraftTime },
    { name = 'drug_stamina',          tier = 'rare',      time = Config.CraftTime },
    { name = 'drug_health',           tier = 'rare',      time = Config.CraftTime },
}

---------------------------------------------------------------------------
-- 1. CLUSTER ROCKET LAUNCHER
---------------------------------------------------------------------------
Config.Launcher = {
    item = 'contraband_launcher',
    ammoItem = 'contraband_rocket',  -- 1 ammo item = 1 cluster volley
    weapon = 'WEAPON_RPG',           -- base weapon model used while holding it (native firing is blocked)
    preloadTime = 25,                -- seconds to preload a volley (drawback)
    rocketsPerVolley = 5,
    staggerMs = 120,                 -- delay between each rocket of the volley
    spread = 5.0,                    -- spread radius (m) of the cluster around the aim point
    range = 350.0,
    rocketSpeed = 120.0,             -- m/s, used to time impacts
    explosion = { type = 5, damageScale = 3.0, shake = 1.0 }, -- 5 = TANKSHELL (much stronger than a normal RPG)
    vehicleDamage = 1800.0,          -- extra engine/body damage per rocket to vehicles in vehicleRadius (ignores armor)
    vehicleRadius = 6.0,
    fire = { enabled = true, duration = 12, points = 5, radius = 3.0, refresh = 4 }, -- burning area at each impact
    homing = { enabled = false, radius = 25.0 }, -- optional auto homing to the nearest target near the aim point
    anim = { dict = 'anim@heists@narcotics@funding@gang_idle', clip = 'gang_chatting_idle01' },
}

---------------------------------------------------------------------------
-- 2/3. THERMAL OPTICS
---------------------------------------------------------------------------
Config.Binoculars = {
    item = 'thermal_binoculars',
    fovMin = 5.0, fovMax = 50.0, zoomSpeed = 4.0, lookSpeed = 6.0,
    exitKey = 177, -- BACKSPACE / right mouse
}

Config.Goggles = {
    item = 'thermal_goggles',
    -- Worn like a vest: use the item to put them on / take them off.
    duration = 60 * 60,      -- 1 REAL hour of life. Counts down while they are worn; then they break.
    saveInterval = 60,       -- seconds between saves of the remaining time (item metadata)
    toggleKey = 'L',         -- turns thermal vision on/off while wearing them (rebindable in Key Bindings)
    -- Helmet prop shown while worn (adjust to your clothing pack). Set to false to disable the prop.
    prop = {
        male   = { component = 0, drawable = 116, texture = 0 },
        female = { component = 0, drawable = 115, texture = 0 },
    },
}

---------------------------------------------------------------------------
-- 4/5/6. PLACEABLE DEVICES
---------------------------------------------------------------------------
Config.MaxDevicesPerPlayer = 6
Config.PlaceTime = 3 -- seconds of planting animation

Config.Devices = {
    contraband_mine = {
        kind = 'mine', label = 'Mine',
        model = 'w_ex_apmine',
        radius = 2.0,
        armTime = 5,             -- seconds before it becomes active
        explosion = { type = 4, damageScale = 2.5 }, -- 4 = ROCKET
        vehicleDamage = 1500.0, vehicleRadius = 5.0,
    },
    contraband_emp_mine = {
        kind = 'emp', label = 'EMP mine',
        model = 'prop_bomb_01_s',
        radius = 2.5,
        armTime = 5,
        disableTime = 10,        -- seconds the vehicle stays disabled
    },
    proximity_sensor = {
        kind = 'sensor', label = 'Proximity sensor',
        model = 'prop_ld_alarm_01',
        radius = 15.0,
        armTime = 3,
        cooldown = 8,            -- seconds between two alarms of the same sensor
        hearDistance = 45.0,     -- everyone in this range hears the beep
        disableTime = 6,         -- seconds to disable/destroy it (non owners) or pick it up (owner)
        ignoreOwner = true,
    },
}

---------------------------------------------------------------------------
-- 7. MOTION DETECTOR TABLET
---------------------------------------------------------------------------
Config.Tablet = {
    item = 'motion_tablet',
    duration = 60,         -- seconds of active time, then it breaks and is removed
    radius = 60.0,         -- detection radius
    minSpeed = 0.6,        -- m/s, targets slower than this are not "moving"
    scanInterval = 1000,   -- ms
    interactKey = 'LMENU', -- hold to get a cursor (game keeps moving, but fire/melee/camera are blocked)
    -- who counts as an enemy: 'differentJob' (other faction job) or 'everyone'
    enemyMode = 'differentJob',
}

---------------------------------------------------------------------------
-- 8/9. CONSUMABLES (only visual / movement effects)
---------------------------------------------------------------------------
Config.Effects = {
    contraband_alcohol = {
        duration = 180, strength = 1.0,
        clipset = 'move_m@drunk@verydrunk', timecycle = 'Drunk', shake = 'DRUNK_SHAKE',
    },
    drug_recreational = {
        duration = 150, strength = 1.0,
        clipset = 'move_m@drunk@slightlydrunk', timecycle = 'spectator5', shake = 'FAMILY5_DRUG_TRIP_SHAKE',
        stumbleChance = 0.04, -- chance per 5s to trip over (clumsy walking). 0 to disable
    },
    drug_stamina = {
        duration = 120,
        sprintMultiplier = 1.15, -- max 1.49
        restorePerSecond = 0.35, -- portion of stamina restored each second (0-1)
    },
    drug_health = {
        duration = 180,
        bonusHealth = 50,        -- extra max health (and heal) while active
    },
}

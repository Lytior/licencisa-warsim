--[[
    Paste these entries inside the table returned by ox_inventory/data/items.lua
    Weights are in grams. consume = 0 -> ox_inventory never removes them by itself;
    warsync_smuggling validates and removes them server side.
    Images: put PNGs with the same names in ox_inventory/web/images/ (e.g. contraband_launcher.png).
]]

['contraband_launcher'] = {
    label = 'Cluster Rocket Launcher',
    weight = 25000, stack = false, close = true, consume = 0,
    description = 'Captured, half-broken cluster launcher. Fires a volley of heavy rockets that rip through armor and leave the area burning. Extremely heavy, slow to preload. Needs cluster rockets.',
    server = { export = 'warsync_smuggling.useItem' },
},

['contraband_rocket'] = {
    label = 'Cluster Rocket Pack',
    weight = 8000, stack = true, close = true, consume = 0,
    description = 'One full cluster volley for the contraband launcher. Very heavy.',
    server = { export = 'warsync_smuggling.useItem' },
},

['thermal_binoculars'] = {
    label = 'Thermal Binoculars',
    weight = 1200, stack = false, close = true, consume = 0,
    description = 'Hold them up to your eyes to see heat signatures. Hands busy while in use.',
    server = { export = 'warsync_smuggling.useItem' },
},

['thermal_goggles'] = {
    label = 'Thermal Goggles',
    weight = 1500, stack = false, close = true, consume = 0,
    description = 'Premium head-mounted thermal vision. Hands stay free. Far more valuable than binoculars.',
    server = { export = 'warsync_smuggling.useItem' },
},

['contraband_mine'] = {
    label = 'Contraband Mine',
    weight = 4000, stack = true, close = true, consume = 0,
    description = 'Pressure mine. Detonates with missile-grade force against infantry and vehicles.',
    server = { export = 'warsync_smuggling.useItem' },
},

['contraband_emp_mine'] = {
    label = 'EMP Mine',
    weight = 4500, stack = true, close = true, consume = 0,
    description = 'Fries the electronics of any vehicle driving over it for a few seconds without destroying it. Pricier than a standard mine.',
    server = { export = 'warsync_smuggling.useItem' },
},

['proximity_sensor'] = {
    label = 'Proximity Sensor',
    weight = 1000, stack = true, close = true, consume = 0,
    description = 'Ground sensor. Beeps loudly and alerts you when someone gets close. Can be found and disabled.',
    server = { export = 'warsync_smuggling.useItem' },
},

['motion_tablet'] = {
    label = 'Motion Detector Tablet',
    weight = 800, stack = false, close = true, consume = 0,
    description = 'Shows moving enemies on a radar. Burns out after one minute of use.',
    server = { export = 'warsync_smuggling.useItem' },
},

['contraband_alcohol'] = {
    label = 'Bootleg Liquor',
    weight = 700, stack = true, close = true, consume = 0,
    description = 'Smuggled bottle. Strong. Very strong.',
    server = { export = 'warsync_smuggling.useItem' },
},

['drug_recreational'] = {
    label = '"Haze" Pills',
    weight = 50, stack = true, close = true, consume = 0,
    description = 'Recreational. Blurry vision and wobbly legs. Just for fun.',
    server = { export = 'warsync_smuggling.useItem' },
},

['drug_stamina'] = {
    label = '"Overdrive" Stim',
    weight = 50, stack = true, close = true, consume = 0,
    description = 'Run longer and recover stamina much faster for a while.',
    server = { export = 'warsync_smuggling.useItem' },
},

['drug_health'] = {
    label = '"Bulwark" Serum',
    weight = 80, stack = true, close = true, consume = 0,
    description = 'Temporarily raises your maximum health.',
    server = { export = 'warsync_smuggling.useItem' },
},

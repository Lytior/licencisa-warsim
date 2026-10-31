-- Mines, EMP mines and proximity sensors. The server is the single source of truth:
-- it owns the device list, validates every placement/trigger/disable and decides the outcome.
local Devices = {}     -- [id] = { id, type, coords, heading, owner, armedAt, lastAlarm }
local Disabling = {}   -- [src] = { id, startedAt }
local nextId = 1

local function now() return GetGameTimer() end

local function publicData(d)
    return { id = d.id, type = d.type, coords = d.coords, heading = d.heading, owner = d.owner,
             armIn = math.max(0, d.armedAt - now()) }
end

local function countOwned(src)
    local n = 0
    for _, d in pairs(Devices) do if d.owner == src then n = n + 1 end end
    return n
end

local function removeDevice(id)
    Devices[id] = nil
    TriggerClientEvent('wsm:device:remove', -1, id)
end

ESX.RegisterServerCallback('wsm:devices:get', function(src, cb)
    local list = {}
    for id, d in pairs(Devices) do list[id] = publicData(d) end
    cb(list)
end)

-- Item use -> client shows a placement preview.
for itemName, cfg in pairs(Config.Devices) do
    WSM.UseHandlers[itemName] = function(src)
        if countOwned(src) >= Config.MaxDevicesPerPlayer then
            return WSM.Notify(src, ('You already have %d devices placed.'):format(Config.MaxDevicesPerPlayer), 'error')
        end
        TriggerClientEvent('wsm:place:start', src, itemName)
    end
end

RegisterNetEvent('wsm:place:confirm', function(dtype, coords, heading)
    local src = source
    local cfg = Config.Devices[dtype]
    coords = WSM.ToVec(coords)
    local ped = WSM.Coords(src)
    if not cfg or not coords or not ped then return end
    if #(ped - coords) > 4.0 then return end
    if countOwned(src) >= Config.MaxDevicesPerPlayer then return end
    if not WSM.Remove(src, dtype, 1) then return end

    local id = nextId
    nextId = nextId + 1
    Devices[id] = {
        id = id, type = dtype, coords = coords, heading = tonumber(heading) or 0.0, owner = src,
        armedAt = now() + cfg.armTime * 1000, lastAlarm = 0,
    }
    TriggerClientEvent('wsm:device:add', -1, publicData(Devices[id]))
    WSM.Notify(src, ('%s armed in %ds.'):format(cfg.label, cfg.armTime), 'success', cfg.label)
end)

-- A client reports that its own ped / vehicle entered a device radius.
RegisterNetEvent('wsm:device:trigger', function(id, vehNet)
    local src = source
    local d = Devices[tonumber(id)]
    if not d then return end
    local cfg = Config.Devices[d.type]
    if now() < d.armedAt then return end

    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then pos = GetEntityCoords(veh) end
    -- tolerance for big vehicles / latency
    if #(pos - d.coords) > cfg.radius + 4.0 then return end

    if cfg.kind == 'mine' then
        removeDevice(d.id)
        TriggerClientEvent('wsm:fx:explosion', src, d.coords, cfg.explosion.type, cfg.explosion.damageScale)
        WSM.DamageVehiclesNear(d.coords, cfg.vehicleRadius, cfg.vehicleDamage)

    elseif cfg.kind == 'emp' then
        if veh == 0 then return end -- EMP only reacts to vehicles
        removeDevice(d.id)
        local owner = NetworkGetEntityOwner(veh)
        TriggerClientEvent('wsm:emp:hit', owner, NetworkGetNetworkIdFromEntity(veh), cfg.disableTime)
        if owner ~= src then TriggerClientEvent('wsm:emp:hit', src, NetworkGetNetworkIdFromEntity(veh), cfg.disableTime) end
        TriggerClientEvent('wsm:fx:emp', -1, d.coords)

    elseif cfg.kind == 'sensor' then
        if cfg.ignoreOwner and src == d.owner then return end
        if now() - d.lastAlarm < cfg.cooldown * 1000 then return end
        d.lastAlarm = now()
        TriggerClientEvent('wsm:fx:beep', -1, d.coords, cfg.hearDistance)
        if GetPlayerPing(d.owner) > 0 then
            WSM.Notify(d.owner, 'Movement detected near your proximity sensor!', 'warning', 'Proximity sensor')
            TriggerClientEvent('wsm:sensor:alert', d.owner, d.coords)
        end
    end
end)

-- Disable / destroy a sensor (anyone) or pick it up (owner gets the item back).
RegisterNetEvent('wsm:device:disableStart', function(id)
    local src = source
    local d = Devices[tonumber(id)]
    local pos = WSM.Coords(src)
    if not d or not pos or Config.Devices[d.type].kind ~= 'sensor' then return end
    if #(pos - d.coords) > 3.0 then return end
    Disabling[src] = { id = d.id, startedAt = os.time() }
end)

RegisterNetEvent('wsm:device:disableFinish', function()
    local src = source
    local job = Disabling[src]
    Disabling[src] = nil
    if not job then return end
    local d = Devices[job.id]
    local pos = WSM.Coords(src)
    if not d or not pos then return end
    local cfg = Config.Devices[d.type]
    if os.time() - job.startedAt < cfg.disableTime - 1 or #(pos - d.coords) > 3.0 then return end

    removeDevice(d.id)
    if d.owner == src then
        WSM.Add(src, d.type, 1)
        WSM.Notify(src, 'Sensor picked up.', 'success', cfg.label)
    else
        WSM.Notify(src, 'Sensor destroyed.', 'success', cfg.label)
        if GetPlayerPing(d.owner) > 0 then WSM.Notify(d.owner, 'One of your proximity sensors went offline.', 'error', cfg.label) end
    end
end)

RegisterNetEvent('wsm:device:disableCancel', function() Disabling[source] = nil end)

AddEventHandler('playerDropped', function()
    Disabling[source] = nil
    -- devices stay in the world after the owner leaves (they keep working)
end)

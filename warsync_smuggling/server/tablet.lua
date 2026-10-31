-- Motion detector tablet. The server scans players (authoritative positions/velocities)
-- and counts down the active time. When it reaches 0 the tablet breaks and is removed.
local Tablets = {} -- [src] = { remaining = ms, activeSince = gameTimer|nil }
local cfg = Config.Tablet

local function remainingOf(t)
    if t.activeSince then return t.remaining - (GetGameTimer() - t.activeSince) end
    return t.remaining
end

local function breakTablet(src)
    Tablets[src] = nil
    WSM.Remove(src, cfg.item, 1)
    TriggerClientEvent('wsm:tablet:broken', src)
end

WSM.UseHandlers[cfg.item] = function(src)
    TriggerClientEvent('wsm:tablet:use', src)
end

-- Turn ON / OFF. Turning off pauses the remaining time.
ESX.RegisterServerCallback('wsm:tablet:toggle', function(src, cb, on)
    if WSM.Count(src, cfg.item) < 1 then return cb(false) end
    local t = Tablets[src] or { remaining = cfg.duration * 1000 }
    Tablets[src] = t
    if on and not t.activeSince then
        t.activeSince = GetGameTimer()
    elseif not on and t.activeSince then
        t.remaining = remainingOf(t)
        t.activeSince = nil
    end
    cb(true, math.max(0, remainingOf(t)), cfg.duration * 1000)
end)

local function isEnemy(myJob, src, other)
    if cfg.enemyMode == 'everyone' then return true end
    return WSM.GetJob(other) ~= myJob
end

ESX.RegisterServerCallback('wsm:tablet:scan', function(src, cb)
    local t = Tablets[src]
    if not t or not t.activeSince then return cb(nil) end
    local rem = remainingOf(t)
    if rem <= 0 then breakTablet(src) return cb(nil) end

    local myPos = WSM.Coords(src)
    local myJob = WSM.GetJob(src)
    local blips = {}
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other ~= src then
            local ped = GetPlayerPed(other)
            if ped ~= 0 then
                local pos = GetEntityCoords(ped)
                local dx, dy = pos.x - myPos.x, pos.y - myPos.y
                if dx * dx + dy * dy <= cfg.radius * cfg.radius then
                    local veh = GetVehiclePedIsIn(ped, false)
                    local vel = GetEntityVelocity(veh ~= 0 and veh or ped)
                    if #vel >= cfg.minSpeed and isEnemy(myJob, src, other) then
                        blips[#blips + 1] = { dx = dx, dy = dy, veh = veh ~= 0 }
                    end
                end
            end
        end
    end
    cb(blips, rem)
end)

-- Safety net: break tablets even if the client stops polling.
CreateThread(function()
    while true do
        Wait(5000)
        for src, t in pairs(Tablets) do
            if t.activeSince and remainingOf(t) <= 0 then breakTablet(src) end
        end
    end
end)

AddEventHandler('playerDropped', function() Tablets[source] = nil end)

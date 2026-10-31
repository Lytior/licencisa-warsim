-- Cluster rocket launcher: preload (consumes 1 ammo item), fire, impact damage validation.
local cfg = Config.Launcher
local State = {} -- [src] = { loaded, preloadStart, volley = { at, impacts, origin } }

local function st(src)
    State[src] = State[src] or { loaded = false }
    return State[src]
end

WSM.UseHandlers[cfg.item] = function(src)
    local s = st(src)
    if s.loaded then return TriggerClientEvent('wsm:launcher:equip', src) end
    if WSM.Count(src, cfg.ammoItem) < 1 then
        return WSM.Notify(src, 'You have no cluster rockets to load.', 'error', 'Launcher')
    end
    TriggerClientEvent('wsm:launcher:preload', src)
end

WSM.UseHandlers[cfg.ammoItem] = function(src)
    WSM.Notify(src, 'Use the cluster launcher to load these rockets.', 'info', 'Launcher')
end

ESX.RegisterServerCallback('wsm:launcher:preloadStart', function(src, cb)
    local s = st(src)
    if s.loaded or WSM.Count(src, cfg.item) < 1 or WSM.Count(src, cfg.ammoItem) < 1 then return cb(false) end
    s.preloadStart = os.time()
    cb(true)
end)

ESX.RegisterServerCallback('wsm:launcher:preloadFinish', function(src, cb)
    local s = st(src)
    local started = s.preloadStart
    s.preloadStart = nil
    if not started or os.time() - started < cfg.preloadTime - 2 then return cb(false) end
    if WSM.Count(src, cfg.item) < 1 or not WSM.Remove(src, cfg.ammoItem, 1) then return cb(false) end
    s.loaded = true
    cb(true)
end)

RegisterNetEvent('wsm:launcher:preloadCancel', function() st(source).preloadStart = nil end)

ESX.RegisterServerCallback('wsm:launcher:fire', function(src, cb)
    local s = st(src)
    if WSM.Count(src, cfg.item) < 1 then
        s.loaded = false
        return cb(false, 'nolauncher')
    end
    if not s.loaded then return cb(false, 'empty') end
    s.loaded = false
    s.volley = { at = os.time(), impacts = 0, origin = WSM.Coords(src) }
    cb(true, cfg.rocketsPerVolley)
end)

-- Each rocket impact asks the server to apply the heavy vehicle damage. Only accepted for an
-- active volley, at most rocketsPerVolley times and within the launcher range.
RegisterNetEvent('wsm:launcher:impact', function(coords)
    local src = source
    local s = State[src]
    coords = WSM.ToVec(coords)
    if not s or not s.volley or not coords then return end
    local v = s.volley
    if os.time() - v.at > 20 or v.impacts >= cfg.rocketsPerVolley then return end
    if #(coords - v.origin) > cfg.range + 60.0 then return end
    v.impacts = v.impacts + 1
    WSM.DamageVehiclesNear(coords, cfg.vehicleRadius, cfg.vehicleDamage)
end)

AddEventHandler('playerDropped', function() State[source] = nil end)

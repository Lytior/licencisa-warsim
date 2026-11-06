if not ESX then
    ESX = exports['es_extended']:getSharedObject()
end

-- Estado autoritativo minimo: quien rapelea, su anclaje y la ultima altura.
local active = {}

ESX.RegisterUsableItem(Config.Item, function(src)
    if active[src] then return end
    TriggerClientEvent('warsim_rappel:tryStart', src)
end)

ESX.RegisterServerCallback('warsim_rappel:consume', function(src, cb, data)
    if active[src] then return cb(false) end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb(false) end
    local item = xPlayer.getInventoryItem(Config.Item)
    if not item or (item.count or 0) < 1 then return cb(false) end
    if not Validation.start(src, data) then return cb(false) end

    xPlayer.removeInventoryItem(Config.Item, 1)
    active[src] = { data = data, s = RState.ANCHORING, z = data.z0, v = 0.0 }
    TriggerClientEvent('warsim_rappel:remoteStart', -1, src, data)
    cb(true)
end)

local function sendNearby(src, anchor, ...)
    if not Validation.oneSync then
        TriggerClientEvent('warsim_rappel:remoteUpdate', -1, src, ...)
        return
    end
    local range = Config.Net.Range
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        if id ~= src then
            local ped = GetPlayerPed(id)
            if ped ~= 0 and #(GetEntityCoords(ped) - anchor) <= range then
                TriggerClientEvent('warsim_rappel:remoteUpdate', id, src, ...)
            end
        end
    end
end

RegisterNetEvent('warsim_rappel:update', function(s, z, v)
    local src = source
    local a = active[src]
    if not a or not Validation.rate(src) or not Validation.update(a, s, z, v) then return end
    a.s, a.z, a.v = s, z, v
    sendNearby(src, a.data.anchor, s, z, v)
end)

local function stop(src)
    if not active[src] then return end
    active[src] = nil
    Validation.clear(src)
    TriggerClientEvent('warsim_rappel:remoteStop', -1, src)
end

RegisterNetEvent('warsim_rappel:stop', function() stop(source) end)
AddEventHandler('playerDropped', function() stop(source) end)

RegisterNetEvent('warsim_rappel:requestActive', function()
    local src = source
    local list = {}
    for id, a in pairs(active) do
        if id ~= src then list[id] = { data = a.data, s = a.s, z = a.z, v = a.v } end
    end
    TriggerClientEvent('warsim_rappel:activeList', src, list)
end)

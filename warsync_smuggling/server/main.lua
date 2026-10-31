-- Core server helpers shared by every server file of the resource.
ESX = exports['es_extended']:getSharedObject()
local ox = exports.ox_inventory

WSM = {
    UseHandlers = {}, -- [itemName] = function(src, slot)
}

function WSM.Log(...)
    if Config.Debug then print('^3[warsync_smuggling]^7', ...) end
end

function WSM.Notify(src, text, ntype, title)
    TriggerClientEvent('wsm:notify', src, { text = text, type = ntype or 'info', title = title })
end

function WSM.IsCivilian(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer ~= nil and Config.CivilianJobs[xPlayer.job.name] == true
end

function WSM.GetJob(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.job.name or nil
end

function WSM.IsAdmin(src)
    if src == 0 then return true end -- server console
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer ~= nil and Config.AdminGroups[xPlayer.getGroup()] == true
end

-- Authoritative position of a player (never trust coords sent by the client).
function WSM.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function WSM.Count(src, item)
    return ox:GetItemCount(src, item) or 0
end

function WSM.Remove(src, item, count)
    return ox:RemoveItem(src, item, count or 1)
end

function WSM.Add(src, item, count)
    if not ox:CanCarryItem(src, item, count or 1) then return false end
    return ox:AddItem(src, item, count or 1)
end

-- Validates a vector3 coming from a client.
function WSM.ToVec(v)
    if type(v) ~= 'vector3' and type(v) ~= 'table' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

-- Sends extra damage to every vehicle near coords. The damage is applied by the
-- client that owns each vehicle (only the network owner can change its health).
function WSM.DamageVehiclesNear(coords, radius, amount)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local dist = #(GetEntityCoords(veh) - coords)
            if dist <= radius then
                local owner = NetworkGetEntityOwner(veh)
                if owner and owner > 0 then
                    local falloff = 1.0 - (dist / radius) * 0.5
                    TriggerClientEvent('wsm:vehicle:damage', owner, NetworkGetNetworkIdFromEntity(veh), amount * falloff)
                end
            end
        end
    end
end

--[[
    ox_inventory entry point. Every contraband item is defined with
        server = { export = 'warsync_smuggling.useItem' }, consume = 0
    so ox never removes anything by itself: each handler validates and removes items server side.
]]
exports('useItem', function(event, item, inventory, slot, data)
    if event ~= 'usingItem' then return end
    local src = inventory.id
    local handler = WSM.UseHandlers[item.name]
    if handler and type(src) == 'number' then
        handler(src, slot)
    end
end)

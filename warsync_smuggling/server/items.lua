-- Thermal optics + consumables (alcohol & drugs).

-- Optics are not consumed: they just toggle on the client.
WSM.UseHandlers[Config.Binoculars.item] = function(src)
    TriggerClientEvent('wsm:binoculars:toggle', src)
end

---------------------------------------------------------------------------
-- Thermal goggles: equippable (like a vest) with 8 real hours of life stored in the
-- item metadata (metadata.timeLeft in seconds, metadata.durability 0-100 for the ox bar).
---------------------------------------------------------------------------
local ox = exports.ox_inventory
local G = Config.Goggles
local Worn = {} -- [src] = { serial, timeLeft, since }

local function findGoggles(src, serial)
    for _, it in pairs(ox:Search(src, 'slots', G.item) or {}) do
        if it.metadata and it.metadata.serial == serial then return it end
    end
end

local function saveWorn(src, finished)
    local w = Worn[src]
    if not w then return end
    local left = w.timeLeft - (os.time() - w.since)
    local item = findGoggles(src, w.serial)
    if not item then -- dropped / given away: take them off
        Worn[src] = nil
        return TriggerClientEvent('wsm:goggles:unequip', src)
    end
    if left <= 0 then
        Worn[src] = nil
        ox:RemoveItem(src, G.item, 1, nil, item.slot)
        TriggerClientEvent('wsm:goggles:unequip', src)
        return WSM.Notify(src, 'Your thermal goggles have run out of battery and broke.', 'error', 'Thermal goggles')
    end
    local md = item.metadata
    md.timeLeft = left
    md.durability = math.floor(left / G.duration * 100)
    ox:SetMetadata(src, item.slot, md)
    if finished then Worn[src] = nil else w.timeLeft, w.since = left, os.time() end
end

WSM.UseHandlers[G.item] = function(src, slot)
    if Worn[src] then -- take them off
        saveWorn(src, true)
        TriggerClientEvent('wsm:goggles:unequip', src)
        return WSM.Notify(src, 'Thermal goggles removed.', 'info', 'Thermal goggles')
    end
    local item = ox:GetSlot(src, slot)
    if not item or item.name ~= G.item then return end
    local md = item.metadata or {}
    if not md.serial then md.serial = ('%d%d'):format(os.time(), math.random(1000, 9999)) end
    md.timeLeft = md.timeLeft or G.duration
    md.durability = math.floor(md.timeLeft / G.duration * 100)
    ox:SetMetadata(src, slot, md)
    Worn[src] = { serial = md.serial, timeLeft = md.timeLeft, since = os.time() }
    TriggerClientEvent('wsm:goggles:equip', src, md.timeLeft)
end

CreateThread(function()
    while true do
        Wait(G.saveInterval * 1000)
        for src in pairs(Worn) do saveWorn(src) end
    end
end)

AddEventHandler('playerDropped', function() saveWorn(source, true) end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for src in pairs(Worn) do saveWorn(src, true) end end
end)

-- Consumables: removed server side first, then the client applies the effect.
local active = {} -- [src] = { [item] = expiresAt(os.time) }

for itemName, eff in pairs(Config.Effects) do
    WSM.UseHandlers[itemName] = function(src)
        active[src] = active[src] or {}
        local exp = active[src][itemName]
        if exp and exp > os.time() then
            return WSM.Notify(src, 'You are still under the effect of this.', 'error')
        end
        if not WSM.Remove(src, itemName, 1) then return end
        active[src][itemName] = os.time() + eff.duration
        TriggerClientEvent('wsm:effect:apply', src, itemName)
    end
end

AddEventHandler('playerDropped', function() active[source] = nil end)

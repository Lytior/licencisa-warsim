-- Thermal optics + consumables (alcohol & drugs).

-- Optics are not consumed: they just toggle on the client.
WSM.UseHandlers[Config.Binoculars.item] = function(src)
    TriggerClientEvent('wsm:binoculars:toggle', src)
end

WSM.UseHandlers[Config.Goggles.item] = function(src)
    TriggerClientEvent('wsm:goggles:toggle', src)
end

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

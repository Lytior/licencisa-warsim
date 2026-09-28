-- Lado servidor: registra el objeto usable, consume la cuerda solo cuando el cliente confirma
-- una superficie válida y reparte el estado de la cuerda al resto de jugadores.
-- La compra y el reparto del objeto los gestiona la tienda de objetos existente.

local pending = {} -- [src] = os.time() en que se usó el objeto
local active = {}  -- [src] = anchor (vector3) de los jugadores en rappel

ESX.RegisterUsableItem(Config.ItemName, function(source)
    local src = source
    if active[src] then return end
    pending[src] = os.time()
    TriggerClientEvent('warsim_rappel:tryStart', src)
end)

-- Superficie no válida (o el jugador no puede ahora): no se consume nada.
RegisterNetEvent('warsim_rappel:cancel', function()
    pending[source] = nil
end)

RegisterNetEvent('warsim_rappel:confirm', function(anchor)
    local src = source
    local usedAt = pending[src]
    pending[src] = nil

    -- Solo se acepta si el objeto se acaba de usar (evita disparar el evento a mano).
    if not usedAt or os.time() - usedAt > Config.ConfirmTimeout or type(anchor) ~= 'vector3' then
        TriggerClientEvent('warsim_rappel:begin', src, false)
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    local item = xPlayer and xPlayer.getInventoryItem(Config.ItemName)
    if not item or (item.count or 0) < 1 then
        TriggerClientEvent('warsim_rappel:begin', src, false)
        return
    end

    xPlayer.removeInventoryItem(Config.ItemName, 1)
    active[src] = anchor
    TriggerClientEvent('warsim_rappel:begin', src, true)
    TriggerClientEvent('warsim_rappel:ropeStart', -1, src, anchor)
end)

local function stop(src)
    pending[src] = nil
    if active[src] then
        active[src] = nil
        TriggerClientEvent('warsim_rappel:ropeStop', -1, src)
    end
end

RegisterNetEvent('warsim_rappel:stop', function()
    stop(source)
end)

AddEventHandler('playerDropped', function()
    stop(source)
end)

-- Los jugadores que se conectan a mitad de un rappel ajeno también ven la cuerda.
AddEventHandler('esx:playerLoaded', function(playerId)
    for src, anchor in pairs(active) do
        TriggerClientEvent('warsim_rappel:ropeStart', playerId, src, anchor)
    end
end)

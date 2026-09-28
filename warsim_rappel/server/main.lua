-- Lado servidor: registra el objeto usable, consume la cuerda solo cuando el cliente confirma
-- una superficie válida y reparte el estado de la cuerda al resto de jugadores.
-- La compra y el reparto del objeto los gestiona la tienda de objetos existente.

local pending = {} -- [src] = os.time() en que se usó el objeto
local active = {}  -- [src] = anchor (vector3) de los jugadores en rappel

local useOx = GetResourceState('ox_inventory') ~= 'missing'

local function debug(...)
    if Config.Debug then print('[warsim_rappel]', ...) end
end

local function onUse(src)
    debug(('jugador %s ha usado %s'):format(src, Config.ItemName))
    if active[src] then
        debug('  ya está en rappel, se ignora')
        return
    end
    -- Con ox_inventory pueden llegar a la vez el export y el usable de ESX: solo uno cuenta.
    if pending[src] and os.time() - pending[src] <= Config.ConfirmTimeout then
        debug('  uso duplicado mientras se procesa el anterior, se ignora')
        return
    end
    pending[src] = os.time()
    TriggerClientEvent('warsim_rappel:tryStart', src)
end

-- Inventario por defecto de ESX (y ox_inventory si reenvía los usables de ESX).
ESX.RegisterUsableItem(Config.ItemName, function(source)
    onUse(source)
end)

-- ox_inventory: el ítem se configura con server = { export = 'warsim_rappel.cuerda_arnes' }.
-- Se devuelve false para que ox no lo gaste: se gasta solo si la superficie es válida.
exports(Config.ItemName, function(event, item, inventory)
    if event == 'usingItem' then
        onUse(inventory.id)
        return false
    end
end)

local function getCount(src)
    if useOx then
        return exports.ox_inventory:GetItemCount(src, Config.ItemName) or 0
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    local item = xPlayer and xPlayer.getInventoryItem(Config.ItemName)
    return item and item.count or 0
end

local function removeOne(src)
    if useOx then
        return exports.ox_inventory:RemoveItem(src, Config.ItemName, 1)
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.removeInventoryItem(Config.ItemName, 1)
    return true
end

-- Superficie no válida (o el jugador no puede ahora): no se consume nada.
RegisterNetEvent('warsim_rappel:cancel', function(reason)
    debug(('jugador %s: cancelado en el cliente (%s), no se gasta la cuerda'):format(source, tostring(reason)))
    pending[source] = nil
end)

RegisterNetEvent('warsim_rappel:confirm', function(anchor)
    local src = source
    local usedAt = pending[src]
    pending[src] = nil

    -- Solo se acepta si el objeto se acaba de usar (evita disparar el evento a mano).
    if not usedAt or os.time() - usedAt > Config.ConfirmTimeout or type(anchor) ~= 'vector3' then
        debug(('jugador %s: confirmación rechazada (sin uso reciente o datos inválidos)'):format(src))
        TriggerClientEvent('warsim_rappel:begin', src, false)
        return
    end

    local count = getCount(src)
    if count < 1 or not removeOne(src) then
        debug(('jugador %s: no tiene la cuerda o no se pudo quitar (cantidad %s)'):format(src, count))
        TriggerClientEvent('warsim_rappel:begin', src, false)
        return
    end

    debug(('jugador %s: cuerda gastada, empieza el rappel'):format(src))
    active[src] = anchor
    TriggerClientEvent('warsim_rappel:begin', src, true)
    TriggerClientEvent('warsim_rappel:ropeStart', -1, src, anchor)
end)

local function stop(src)
    pending[src] = nil
    if active[src] then
        debug(('jugador %s: fin del rappel'):format(src))
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

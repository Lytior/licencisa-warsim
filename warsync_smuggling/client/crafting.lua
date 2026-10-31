-- Crafting tables (local props) + crafting menu + crafting progress.
local Tables, Objects, Blips = {}, {}, {}
local menuOpen = false

local function clear()
    for _, o in pairs(Objects) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for _, b in pairs(Blips) do RemoveBlip(b) end
    Objects, Blips = {}, {}
end

local function spawnAll()
    clear()
    local hash = WSM.LoadModel(Config.Table.model)
    for id, t in pairs(Tables) do
        if hash then
            local obj = CreateObject(hash, t.x, t.y, t.z, false, false, false)
            SetEntityHeading(obj, t.h)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            Objects[id] = obj
        end
        if Config.Table.blip.enabled and WSM.IsCivilian() then
            local b = AddBlipForCoord(t.x, t.y, t.z)
            SetBlipSprite(b, Config.Table.blip.sprite)
            SetBlipColour(b, Config.Table.blip.colour)
            SetBlipScale(b, Config.Table.blip.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(Config.Table.blip.label)
            EndTextCommandSetBlipName(b)
            Blips[id] = b
        end
    end
    if hash then SetModelAsNoLongerNeeded(hash) end
end

RegisterNetEvent('wsm:tables:sync', function(list)
    Tables = {}
    for k, t in pairs(list) do Tables[tonumber(k)] = t end
    spawnAll()
end)
RegisterNetEvent('esx:setJob', function() SetTimeout(500, spawnAll) end) -- refresh blips
CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    TriggerServerEvent('wsm:tables:request')
end)

local function tableCoords(id)
    local t = Tables[id]
    return t and vector3(t.x, t.y, t.z) or nil
end

-- Menu -------------------------------------------------------------------
local function openMenu(tableId)
    local items = {}
    for _, it in ipairs(Config.Items) do
        local data = exports.ox_inventory:Items(it.name) or {}
        items[#items + 1] = {
            name = it.name, tier = it.tier, time = it.time,
            label = data.label or it.name, description = data.description or '',
            weight = data.weight or 0,
        }
    end
    menuOpen = tableId
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'craft:open', items = items })
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'craft:close' })
end

RegisterNUICallback('craft:close', function(_, cb) closeMenu() cb('ok') end)

RegisterNUICallback('craft:select', function(data, cb)
    cb('ok')
    local tableId = menuOpen
    closeMenu()
    if not tableId or WSM.busy then return end
    ESX.TriggerServerCallback('wsm:craft:start', function(ok, seconds)
        if not ok then return WSM.Notify('You cannot craft this right now.', 'error', 'Workbench') end
        CreateThread(function()
            local tc = tableCoords(tableId)
            local done = WSM.Progress({
                label = ('Crafting %s'):format(WSM.ItemLabel(data.name)),
                duration = seconds * 1000,
                anim = Config.Table.anim,
                check = function()
                    return tc and #(GetEntityCoords(PlayerPedId()) - tc) <= Config.Table.cancelDistance
                end,
            })
            if not done then
                TriggerServerEvent('wsm:craft:cancel')
                return WSM.Notify('Crafting cancelled. All progress was lost.', 'error', 'Workbench')
            end
            ESX.TriggerServerCallback('wsm:craft:finish', function(success, item)
                if success then WSM.Notify(('%s crafted.'):format(WSM.ItemLabel(item)), 'success', 'Workbench') end
            end)
        end)
    end, tableId, data.name)
end)

-- Interaction loop (sleeps when far from every table) ----------------------
CreateThread(function()
    while true do
        local sleep = 1500
        if WSM.IsCivilian() and not menuOpen and not WSM.busy then
            local pc = GetEntityCoords(PlayerPedId())
            for id, t in pairs(Tables) do
                local d = #(pc - vector3(t.x, t.y, t.z))
                if d < 20.0 then sleep = 500 end
                if d <= Config.Table.interactDistance then
                    sleep = 0
                    WSM.Help('~INPUT_CONTEXT~ Open contraband workbench')
                    if IsControlJustPressed(0, 38) then openMenu(id) end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() if menuOpen then SetNuiFocus(false, false) end end
end)

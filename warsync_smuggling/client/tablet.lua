--[[
    Motion detector tablet.
    - Shown as a small overlay WITHOUT NUI focus: the player can move, aim and shoot normally.
    - Hold the interact key (default LEFT ALT) to get a cursor. While held, NUI focus keeps game
      input (you can still walk) but attack, melee, aim and camera controls are disabled, so
      clicking the ON/OFF button never fires, punches or moves the camera.
]]
local cfg = Config.Tablet
local open, on, cursor = false, false, false

local function setCursor(state)
    if state == cursor or (state and not open) then return end
    cursor = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(state)
    SendNUIMessage({ action = 'tablet:cursor', state = state })
    if state then
        CreateThread(function()
            while cursor do
                -- attack / aim / melee / camera / weapon wheel / pause
                for _, c in ipairs({ 1, 2, 24, 25, 37, 44, 45, 68, 69, 70, 91, 92, 106, 114, 140, 141, 142, 143, 257, 263, 264, 199, 200 }) do
                    DisableControlAction(0, c, true)
                end
                DisablePlayerFiring(PlayerId(), true)
                Wait(0)
            end
        end)
    end
end

local function close()
    if on then ESX.TriggerServerCallback('wsm:tablet:toggle', function() end, false) end
    on = false
    setCursor(false)
    open = false
    SendNUIMessage({ action = 'tablet:hide' })
end

RegisterCommand('+wsm_tablet', function() setCursor(true) end, false)
RegisterCommand('-wsm_tablet', function() setCursor(false) end, false)
RegisterKeyMapping('+wsm_tablet', 'Motion tablet: use cursor (hold)', 'keyboard', cfg.interactKey)

RegisterNUICallback('tablet:release', function(_, cb) setCursor(false) cb('ok') end)
RegisterNUICallback('tablet:close', function(_, cb) close() cb('ok') end)

local function scanLoop()
    CreateThread(function()
        while on do
            ESX.TriggerServerCallback('wsm:tablet:scan', function(blips, remaining)
                if not on or not blips then return end
                -- rotate world offsets into camera space (up = where the player looks)
                local h = math.rad(GetGameplayCamRot(2).z)
                local fx, fy = -math.sin(h), math.cos(h)
                local rx, ry = math.cos(h), math.sin(h)
                local out = {}
                for i, b in ipairs(blips) do
                    out[i] = { x = (b.dx * rx + b.dy * ry) / cfg.radius, y = (b.dx * fx + b.dy * fy) / cfg.radius, veh = b.veh }
                end
                SendNUIMessage({ action = 'tablet:blips', blips = out, remaining = remaining })
            end)
            Wait(cfg.scanInterval)
        end
    end)
end

RegisterNUICallback('tablet:toggle', function(_, cb)
    cb('ok')
    ESX.TriggerServerCallback('wsm:tablet:toggle', function(ok, remaining, total)
        if not ok then return close() end
        on = not on
        SendNUIMessage({ action = 'tablet:state', on = on, remaining = remaining, total = total })
        if on then scanLoop() end
    end, not on)
end)

RegisterNetEvent('wsm:tablet:use', function()
    if open then return close() end
    open = true
    SendNUIMessage({ action = 'tablet:show', radius = cfg.radius, total = cfg.duration * 1000, key = cfg.interactKey })
end)

RegisterNetEvent('wsm:tablet:broken', function()
    on = false
    setCursor(false)
    SendNUIMessage({ action = 'tablet:broken' })
    PlaySoundFrontend(-1, 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', false)
    WSM.Notify('The motion tablet overheated and broke.', 'error', 'Motion tablet')
    SetTimeout(2500, function() open = false SendNUIMessage({ action = 'tablet:hide' }) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and cursor then SetNuiFocus(false, false) SetNuiFocusKeepInput(false) end
end)

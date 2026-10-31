-- Client core: ESX data, NUI bridge, notifications, generic progress bar and small helpers.
ESX = exports['es_extended']:getSharedObject()

WSM = { busy = false, job = nil }

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    WSM.job = ESX.GetPlayerData().job and ESX.GetPlayerData().job.name
end)
RegisterNetEvent('esx:playerLoaded', function(data) WSM.job = data.job and data.job.name end)
RegisterNetEvent('esx:setJob', function(job) WSM.job = job.name end)

function WSM.IsCivilian() return WSM.job ~= nil and Config.CivilianJobs[WSM.job] == true end

-- Notifications ------------------------------------------------------------
function WSM.Notify(text, ntype, title)
    SendNUIMessage({ action = 'notify', text = text, type = ntype or 'info', title = title })
end
RegisterNetEvent('wsm:notify', function(d) WSM.Notify(d.text, d.type, d.title) end)

-- Helpers ------------------------------------------------------------------
function WSM.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

function WSM.LoadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

function WSM.Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function WSM.ItemLabel(name)
    local it = exports.ox_inventory:Items(name)
    return it and it.label or name
end

function WSM.HasItem(name)
    return (exports.ox_inventory:Search('count', name) or 0) > 0
end

--[[
    Generic progress bar (blocking, call from a thread).
    opts = { label, duration (ms), anim = {dict, clip} | scenario, check = function() -> bool (false cancels),
             freeze = true (blocks combat while working) }
    Returns true when completed, false when cancelled (cancel key, death, check failed).
]]
function WSM.Progress(opts)
    if WSM.busy then return false end
    WSM.busy = true
    local ped = PlayerPedId()

    if opts.anim and WSM.LoadDict(opts.anim.dict) then
        TaskPlayAnim(ped, opts.anim.dict, opts.anim.clip, 3.0, 3.0, -1, opts.anim.flag or 1, 0, false, false, false)
    end

    SendNUIMessage({ action = 'progress', label = opts.label, duration = opts.duration, cancelKey = 'X' })
    local endAt = GetGameTimer() + opts.duration
    local ok = true
    while GetGameTimer() < endAt do
        Wait(0)
        DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true); DisableControlAction(0, 141, true); DisableControlAction(0, 142, true)
        if IsControlJustPressed(0, Config.CancelKey) or IsDisabledControlJustPressed(0, Config.CancelKey)
            or IsEntityDead(ped) or (opts.check and not opts.check()) then
            ok = false
            break
        end
    end

    if opts.anim then StopAnimTask(ped, opts.anim.dict, opts.anim.clip, 1.0) end
    SendNUIMessage({ action = 'progressEnd', success = ok })
    WSM.busy = false
    return ok
end

-- Vehicle damage requested by the server (we are the network owner of that vehicle).
RegisterNetEvent('wsm:vehicle:damage', function(netId, amount)
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) or not NetworkHasControlOfEntity(veh) then return end
    amount = tonumber(amount) or 0
    SetVehicleEngineHealth(veh, math.max(-4000.0, GetVehicleEngineHealth(veh) - amount))
    SetVehicleBodyHealth(veh, math.max(0.0, GetVehicleBodyHealth(veh) - amount))
    SetVehiclePetrolTankHealth(veh, math.max(-999.0, GetVehiclePetrolTankHealth(veh) - amount * 0.6))
    if GetVehicleEngineHealth(veh) <= -3000.0 then NetworkExplodeVehicle(veh, true, false, false) end
end)

-- Explosion requested by the server (mine). AddExplosion is networked.
RegisterNetEvent('wsm:fx:explosion', function(coords, expType, scale)
    AddExplosion(coords.x, coords.y, coords.z, expType, scale + 0.0, true, false, 1.0)
end)

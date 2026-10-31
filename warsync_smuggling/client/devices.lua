-- Placement preview, local device props, trigger detection, sensor disable, EMP effect.
local Devices, Objects = {}, {}
local reported = {}   -- [id] = gameTimer of last report (debounce)
local placing = false
local myId = GetPlayerServerId(PlayerId())

local function spawnDevice(d)
    local cfg = Config.Devices[d.type]
    local hash = cfg and WSM.LoadModel(cfg.model)
    if not hash then return end
    local obj = CreateObject(hash, d.coords.x, d.coords.y, d.coords.z, false, false, false)
    SetEntityHeading(obj, d.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    Objects[d.id] = obj
    SetModelAsNoLongerNeeded(hash)
end

local function addDevice(d)
    d.armedAt = GetGameTimer() + (d.armIn or 0)
    Devices[d.id] = d
    spawnDevice(d)
end

local function removeDevice(id)
    Devices[id] = nil
    reported[id] = nil
    if Objects[id] and DoesEntityExist(Objects[id]) then DeleteEntity(Objects[id]) end
    Objects[id] = nil
end

RegisterNetEvent('wsm:device:add', addDevice)
RegisterNetEvent('wsm:device:remove', removeDevice)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    myId = GetPlayerServerId(PlayerId())
    ESX.TriggerServerCallback('wsm:devices:get', function(list)
        for _, d in pairs(list) do addDevice(d) end
    end)
end)

---------------------------------------------------------------------------
-- Placement preview
---------------------------------------------------------------------------
RegisterNetEvent('wsm:place:start', function(dtype)
    local cfg = Config.Devices[dtype]
    if placing or WSM.busy or not cfg then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return WSM.Notify('Get out of the vehicle first.', 'error') end
    local hash = WSM.LoadModel(cfg.model)
    if not hash then return end
    placing = true

    CreateThread(function()
        local ghost = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
        SetEntityAlpha(ghost, 160, false)
        SetEntityCollision(ghost, false, false)
        FreezeEntityPosition(ghost, true)
        local confirmed = false

        while placing do
            Wait(0)
            ped = PlayerPedId()
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.2, 0.0)
            SetEntityCoords(ghost, pos.x, pos.y, pos.z, false, false, false, false)
            SetEntityHeading(ghost, GetEntityHeading(ped))
            PlaceObjectOnGroundProperly(ghost)
            WSM.Help(('~INPUT_CONTEXT~ Place %s~n~~INPUT_FRONTEND_RRIGHT~ Cancel'):format(cfg.label))
            local c = GetEntityCoords(ghost) -- trigger radius preview
            DrawMarker(1, c.x, c.y, c.z - 0.05, 0, 0, 0, 0, 0, 0, cfg.radius * 2, cfg.radius * 2, 0.15,
                255, 170, 40, 60, false, false, 2, false, nil, nil, false)
            if IsControlJustPressed(0, 38) then confirmed = true break end
            if IsControlJustPressed(0, 177) or IsEntityDead(ped) then break end
        end

        local coords, heading = GetEntityCoords(ghost), GetEntityHeading(ghost)
        DeleteEntity(ghost)
        SetModelAsNoLongerNeeded(hash)
        placing = false
        if not confirmed then return end

        local ok = WSM.Progress({
            label = ('Planting %s'):format(cfg.label),
            duration = Config.PlaceTime * 1000,
            anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 },
        })
        if ok then TriggerServerEvent('wsm:place:confirm', dtype, coords, heading) end
    end)
end)

---------------------------------------------------------------------------
-- Trigger detection + sensor interaction (adaptive sleep, no work when far)
---------------------------------------------------------------------------
local function startDisable(id, d, cfg)
    CreateThread(function()
        TriggerServerEvent('wsm:device:disableStart', id)
        local owner = d.owner == myId
        local ok = WSM.Progress({
            label = owner and 'Picking up sensor' or 'Disabling sensor',
            duration = cfg.disableTime * 1000,
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
            check = function() return Devices[id] ~= nil end,
        })
        TriggerServerEvent(ok and 'wsm:device:disableFinish' or 'wsm:device:disableCancel')
    end)
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        if next(Devices) and not IsEntityDead(ped) then
            local veh = GetVehiclePedIsIn(ped, false)
            local driver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
            local pos = veh ~= 0 and GetEntityCoords(veh) or GetEntityCoords(ped)
            local now = GetGameTimer()

            for id, d in pairs(Devices) do
                local cfg = Config.Devices[d.type]
                local dist = #(pos - d.coords)
                if dist < 50.0 then sleep = math.min(sleep, 150) end

                if now >= d.armedAt and dist <= cfg.radius and (not reported[id] or now - reported[id] > 2500) then
                    local fire = false
                    if cfg.kind == 'mine' then fire = veh == 0 or driver
                    elseif cfg.kind == 'emp' then fire = driver
                    elseif cfg.kind == 'sensor' then fire = not (cfg.ignoreOwner and d.owner == myId) end
                    if fire then
                        reported[id] = now
                        TriggerServerEvent('wsm:device:trigger', id, veh ~= 0 and VehToNet(veh) or nil)
                    end
                end

                if cfg.kind == 'sensor' and veh == 0 and dist <= 1.8 and not WSM.busy then
                    sleep = 0
                    WSM.Help(d.owner == myId and '~INPUT_CONTEXT~ Pick up sensor' or '~INPUT_CONTEXT~ Disable sensor')
                    if IsControlJustPressed(0, 38) then startDisable(id, d, cfg) end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
RegisterNetEvent('wsm:fx:beep', function(coords, hearDistance)
    if #(GetEntityCoords(PlayerPedId()) - coords) > hearDistance then return end
    CreateThread(function()
        for _ = 1, 3 do
            PlaySoundFromCoord(-1, 'Beep_Red', coords.x, coords.y, coords.z, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, hearDistance, false)
            Wait(350)
        end
    end)
end)

RegisterNetEvent('wsm:sensor:alert', function(coords)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, 20.0)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, 140)
    SetTimeout(10000, function() RemoveBlip(blip) end)
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
end)

RegisterNetEvent('wsm:fx:emp', function(coords)
    if #(GetEntityCoords(PlayerPedId()) - coords) > 150.0 then return end
    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_dst_elec_fire_sp', coords.x, coords.y, coords.z + 0.3, 0.0, 0.0, 0.0, 3.0, false, false, false)
    PlaySoundFromCoord(-1, 'Power_Down', coords.x, coords.y, coords.z, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 60, false)
end)

-- Sent to the vehicle network owner (and to the driver who triggered it).
local empVehicles = {}
RegisterNetEvent('wsm:emp:hit', function(netId, seconds)
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh == 0 or empVehicles[veh] then return end
    empVehicles[veh] = true
    CreateThread(function()
        local endAt = GetGameTimer() + seconds * 1000
        local ped = PlayerPedId()
        if GetPedInVehicleSeat(veh, -1) == ped then WSM.Notify('Electromagnetic pulse! Vehicle systems offline.', 'warning', 'EMP') end
        while GetGameTimer() < endAt and DoesEntityExist(veh) do
            SetVehicleEngineOn(veh, false, true, true)
            SetVehicleUndriveable(veh, true)
            if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
                for _, c in ipairs({ 59, 60, 63, 64, 71, 72, 76, 86, 87, 88, 89, 90, 107, 108, 109, 110, 111, 112 }) do
                    DisableControlAction(0, c, true)
                end
            end
            Wait(0)
        end
        if DoesEntityExist(veh) then
            SetVehicleUndriveable(veh, false)
            SetVehicleEngineOn(veh, true, false, true)
        end
        empVehicles[veh] = nil
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Objects) do removeDevice(id) end
end)

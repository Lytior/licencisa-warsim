--[[
    Contraband cluster launcher.
    The player holds the base weapon model but native firing is blocked; pulling the trigger
    asks the server for permission (it checks launcher + preloaded volley), then the volley is
    simulated here: visual rockets + heavy networked explosions + burning area at each impact.
    Extra vehicle damage is applied by the server (sent to each vehicle's network owner).
]]
local cfg = Config.Launcher
local weaponHash = joaat(cfg.weapon)
local rocketHash = joaat('WEAPON_RPG')
local equipped, loaded, firing = false, false, false

local function unequip()
    equipped = false
    local ped = PlayerPedId()
    if HasPedGotWeapon(ped, weaponHash, false) then RemoveWeaponFromPed(ped, weaponHash) end
end

local function aimPoint(ped)
    local camPos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local dest = camPos + dir * cfg.range
    local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, ped, 4)
    local _, hit, endPos = GetShapeTestResult(ray)
    return hit == 1 and endPos or dest
end

local function raycast(from, to, ped)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, -1, ped, 4)
    local _, hit, endPos = GetShapeTestResult(ray)
    return hit == 1 and endPos or to
end

-- Optional homing: nearest vehicle (preferred) or ped around the aim point.
local function findTarget(ped, point)
    local best, bestDist = nil, cfg.homing.radius
    for _, pool in ipairs({ 'CVehicle', 'CPed' }) do
        for _, ent in ipairs(GetGamePool(pool)) do
            if ent ~= ped and not IsEntityDead(ent) and (pool == 'CVehicle' or not IsPedInAnyVehicle(ent, false)) then
                local d = #(GetEntityCoords(ent) - point)
                if d < bestDist then best, bestDist = ent, d end
            end
        end
        if best then break end
    end
    return best
end

local function burnArea(p)
    local f = cfg.fire
    CreateThread(function()
        local endAt = GetGameTimer() + f.duration * 1000
        while GetGameTimer() < endAt do
            for i = 1, f.points do
                local a = (i / f.points) * math.pi * 2
                AddExplosion(p.x + math.cos(a) * f.radius, p.y + math.sin(a) * f.radius, p.z, 3, 1.0, true, false, 0.0) -- 3 = MOLOTOV (networked fire)
            end
            Wait(f.refresh * 1000)
        end
    end)
end

local function impact(p)
    AddExplosion(p.x, p.y, p.z, cfg.explosion.type, cfg.explosion.damageScale, true, false, cfg.explosion.shake)
    if cfg.fire.enabled then burnArea(p) end
    TriggerServerEvent('wsm:launcher:impact', p)
end

local function fireVolley(count)
    local ped = PlayerPedId()
    local target = aimPoint(ped)
    local homingTarget = cfg.homing.enabled and findTarget(ped, target) or nil
    local wEnt = GetCurrentPedWeaponEntityIndex(ped)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.4)

    for i = 1, count do
        local origin = (wEnt ~= 0 and GetOffsetFromEntityInWorldCoords(wEnt, 0.0, 1.2, 0.05)) or GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.6)
        local a, r = math.random() * math.pi * 2, math.random() * cfg.spread
        local aimAt = homingTarget and GetEntityCoords(homingTarget) or target
        local wanted = aimAt + vector3(math.cos(a) * r * (homingTarget and 0.25 or 1.0), math.sin(a) * r * (homingTarget and 0.25 or 1.0), 0.0)
        -- extend the line and find the real impact point
        local dir = wanted - origin
        local len = #dir
        local endPos = raycast(origin, origin + dir / len * math.min(cfg.range, len + 5.0), ped)

        ShootSingleBulletBetweenCoords(origin.x, origin.y, origin.z, endPos.x, endPos.y, endPos.z, 1, true, rocketHash, ped, true, false, cfg.rocketSpeed)

        local travel = math.floor(#(endPos - origin) / cfg.rocketSpeed * 1000)
        SetTimeout(travel, function()
            local p = endPos
            if homingTarget and DoesEntityExist(homingTarget) then p = GetEntityCoords(homingTarget) end
            impact(p)
        end)
        Wait(cfg.staggerMs)
    end
end

local function fire()
    if firing then return end
    if not loaded then
        PlaySoundFrontend(-1, 'Faster_Click', 'RESPAWN_ONLINE_SOUNDSET', false)
        return WSM.Notify('Launcher empty. Use it again from your inventory to preload.', 'error', 'Launcher')
    end
    firing = true
    ESX.TriggerServerCallback('wsm:launcher:fire', function(ok, data)
        if ok then
            loaded = false
            fireVolley(data)
        elseif data == 'nolauncher' then
            unequip()
        else
            loaded = false
        end
        firing = false
    end)
end

local function equip()
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, weaponHash, 1, false, true)
    SetPedAmmo(ped, weaponHash, 1)
    SetCurrentPedWeapon(ped, weaponHash, true)
    if equipped then return end
    equipped = true
    CreateThread(function()
        while equipped do
            ped = PlayerPedId()
            if GetSelectedPedWeapon(ped) ~= weaponHash or IsEntityDead(ped) then unequip() break end
            DisablePlayerFiring(PlayerId(), true) -- blocks the native RPG rocket
            DisableControlAction(0, 45, true)     -- reload
            if (IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24)) and IsPlayerFreeAiming(PlayerId()) then fire() end
            Wait(0)
        end
    end)
end

RegisterNetEvent('wsm:launcher:equip', function()
    loaded = true
    equip()
end)

RegisterNetEvent('wsm:launcher:preload', function()
    if WSM.busy then return end
    CreateThread(function()
        ESX.TriggerServerCallback('wsm:launcher:preloadStart', function(ok)
            if not ok then return end
            CreateThread(function()
                local done = WSM.Progress({ label = 'Preloading cluster rockets', duration = cfg.preloadTime * 1000, anim = cfg.anim })
                if not done then
                    TriggerServerEvent('wsm:launcher:preloadCancel')
                    return WSM.Notify('Preload cancelled.', 'error', 'Launcher')
                end
                ESX.TriggerServerCallback('wsm:launcher:preloadFinish', function(success)
                    if not success then return WSM.Notify('Preload failed.', 'error', 'Launcher') end
                    loaded = true
                    WSM.Notify(('Cluster volley loaded (%d rockets).'):format(cfg.rocketsPerVolley), 'success', 'Launcher')
                    equip()
                end)
            end)
        end)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and equipped then unequip() end
end)

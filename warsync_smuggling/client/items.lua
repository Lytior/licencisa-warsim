-- Thermal binoculars, thermal goggles, alcohol and drugs.

---------------------------------------------------------------------------
-- Thermal binoculars (held in hand, look through them)
---------------------------------------------------------------------------
local binoActive = false

local function stopBinoculars() binoActive = false end

RegisterNetEvent('wsm:binoculars:toggle', function()
    if binoActive then return stopBinoculars() end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    binoActive = true
    local c = Config.Binoculars

    CreateThread(function()
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_BINOCULARS', 0, true)
        Wait(1800) -- raise them to the eyes

        local fov = c.fovMax
        local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
        AttachCamToEntity(cam, ped, 0.0, 0.0, 1.0, true)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped), 2)
        SetCamFov(cam, fov)
        RenderScriptCams(true, false, 0, true, false)
        SetSeethrough(true)

        local sf = RequestScaleformMovie('BINOCULARS')
        while not HasScaleformMovieLoaded(sf) do Wait(0) end

        while binoActive do
            Wait(0)
            if IsEntityDead(ped) or IsControlJustPressed(0, c.exitKey) or not IsPedUsingScenario(ped, 'WORLD_HUMAN_BINOCULARS') then break end
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
            DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
            DisableControlAction(0, 14, true); DisableControlAction(0, 15, true)

            -- look around with the mouse
            local zoomFactor = fov / c.fovMax
            local x = GetDisabledControlNormal(0, 1) * c.lookSpeed * zoomFactor
            local y = GetDisabledControlNormal(0, 2) * c.lookSpeed * zoomFactor
            local rot = GetCamRot(cam, 2)
            local pitch = math.max(-60.0, math.min(60.0, rot.x - y))
            SetCamRot(cam, pitch, 0.0, rot.z - x, 2)
            SetEntityHeading(ped, rot.z - x)

            -- zoom with the mouse wheel
            if IsDisabledControlJustPressed(0, 15) then fov = math.max(c.fovMin, fov - c.zoomSpeed) end
            if IsDisabledControlJustPressed(0, 14) then fov = math.min(c.fovMax, fov + c.zoomSpeed) end
            SetCamFov(cam, fov)
            DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0)
            WSM.Help('~INPUT_FRONTEND_RRIGHT~ Lower binoculars  ~INPUT_CURSOR_SCROLL_UP~ Zoom')
        end

        binoActive = false
        SetSeethrough(false)
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        SetScaleformMovieAsNoLongerNeeded(sf)
        ClearPedTasks(ped)
    end)
end)

---------------------------------------------------------------------------
-- Thermal goggles (worn, hands free)
---------------------------------------------------------------------------
local worn, vision = false, false
local savedProp

local function setVision(on)
    vision = on
    SetSeethrough(on)
    PlaySoundFrontend(-1, on and 'NIGHTVISION_ON' or 'NIGHTVISION_OFF', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end

local function setProp(on)
    local p = Config.Goggles.prop
    if not p then return end
    local ped = PlayerPedId()
    local def = IsPedMale(ped) and p.male or p.female
    if on then
        savedProp = { GetPedPropIndex(ped, def.component), GetPedPropTextureIndex(ped, def.component) }
        SetPedPropIndex(ped, def.component, def.drawable, def.texture, true)
    elseif savedProp then
        if savedProp[1] == -1 then ClearPedProp(ped, def.component)
        else SetPedPropIndex(ped, def.component, savedProp[1], savedProp[2], true) end
        savedProp = nil
    end
end

RegisterNetEvent('wsm:goggles:equip', function(timeLeft)
    if worn then return end
    worn = true
    setProp(true)
    local h, m = math.floor(timeLeft / 3600), math.floor(timeLeft % 3600 / 60)
    WSM.Notify(('Goggles equipped (%dh %02dm left). Press L to toggle thermal vision.'):format(h, m), 'success', 'Thermal goggles')
    CreateThread(function()
        while worn do -- watchdog: death turns the vision off
            Wait(2000)
            if vision and IsEntityDead(PlayerPedId()) then setVision(false) end
        end
    end)
end)

RegisterNetEvent('wsm:goggles:unequip', function()
    if not worn then return end
    worn = false
    if vision then setVision(false) end
    setProp(false)
end)

RegisterCommand('wsm_thermal', function()
    if not worn then return end
    if IsEntityDead(PlayerPedId()) then return end
    setVision(not vision)
end, false)
RegisterKeyMapping('wsm_thermal', 'Thermal goggles: toggle vision', 'keyboard', Config.Goggles.toggleKey)

---------------------------------------------------------------------------
-- Alcohol & drugs
---------------------------------------------------------------------------
local Active = {} -- [item] = endsAt

local function resetVisuals()
    local ped = PlayerPedId()
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    ResetPedMovementClipset(ped, 1.0)
    SetPedIsDrunk(ped, false)
    SetPedMotionBlur(ped, false)
end

local function visualEffect(item, e)
    local ped = PlayerPedId()
    RequestAnimSet(e.clipset)
    local t = GetGameTimer() + 3000
    while not HasAnimSetLoaded(e.clipset) and GetGameTimer() < t do Wait(10) end
    SetPedMovementClipset(ped, e.clipset, 1.0)
    SetTimecycleModifier(e.timecycle)
    SetTimecycleModifierStrength(e.strength)
    ShakeGameplayCam(e.shake, e.strength)
    SetPedIsDrunk(ped, true)
    SetPedMotionBlur(ped, true)

    while Active[item] and GetGameTimer() < Active[item] do
        Wait(5000)
        ped = PlayerPedId()
        if IsEntityDead(ped) then break end
        if e.stumbleChance and math.random() < e.stumbleChance and not IsPedInAnyVehicle(ped, false) and IsPedWalking(ped) then
            SetPedToRagdoll(ped, 1500, 2000, 3, false, false, false)
        end
    end
    Active[item] = nil
    resetVisuals()
end

local Handlers = {}

Handlers.contraband_alcohol = function(item, e) visualEffect(item, e) end
Handlers.drug_recreational = function(item, e) visualEffect(item, e) end

Handlers.drug_stamina = function(item, e)
    local pid = PlayerId()
    SetRunSprintMultiplierForPlayer(pid, math.min(1.49, e.sprintMultiplier))
    while GetGameTimer() < Active[item] do
        Wait(1000)
        if IsEntityDead(PlayerPedId()) then break end
        RestorePlayerStamina(pid, e.restorePerSecond)
    end
    SetRunSprintMultiplierForPlayer(pid, 1.0)
    Active[item] = nil
end

Handlers.drug_health = function(item, e)
    local ped = PlayerPedId()
    local baseMax = GetEntityMaxHealth(ped)
    SetEntityMaxHealth(ped, baseMax + e.bonusHealth)
    SetEntityHealth(ped, math.min(baseMax + e.bonusHealth, GetEntityHealth(ped) + e.bonusHealth))
    while GetGameTimer() < Active[item] do
        Wait(1000)
        if IsEntityDead(PlayerPedId()) then break end
    end
    ped = PlayerPedId()
    SetEntityMaxHealth(ped, baseMax)
    if GetEntityHealth(ped) > baseMax then SetEntityHealth(ped, baseMax) end
    Active[item] = nil
end

RegisterNetEvent('wsm:effect:apply', function(item)
    local e = Config.Effects[item]
    if not e or Active[item] then return end
    Active[item] = GetGameTimer() + e.duration * 1000
    WSM.Notify(('You used %s.'):format(WSM.ItemLabel(item)), 'info')
    CreateThread(function() Handlers[item](item, e) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetSeethrough(false)
    resetVisuals()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end)

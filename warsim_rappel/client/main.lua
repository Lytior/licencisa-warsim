local mv = Config.Movement
local anims = Config.Anims

local UNARMED = `WEAPON_UNARMED`

local rappel = nil   -- estado del rappel en curso
local pending = nil  -- superficie detectada a la espera de que el servidor consuma el objeto

local function notify(msg)
    ESX.ShowNotification(msg)
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - t > 3000 then return false end
        Wait(0)
    end
    return true
end

local function playAnim(ped, anim, flag)
    if loadDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, -1, flag or 1, 0.0, false, false, false)
    end
end

local function canStart(ped)
    return not IsPedInAnyVehicle(ped, true)
        and not IsEntityDead(ped)
        and not IsPedSwimming(ped)
        and not IsPedFalling(ped)
        and not IsPedRagdoll(ped)
        and not IsPedClimbing(ped)
end

local function releasePed(ped)
    FreezeEntityPosition(ped, false)
    SetPedCanRagdoll(ped, true)
    ClearPedSecondaryTask(ped)
    ClearPedTasks(ped)
end

---------------------------------------------------------------------------
-- Fin del rappel
---------------------------------------------------------------------------
local function stopRappel(exitPos)
    if not rappel then return end
    local ped = PlayerPedId()
    rappel = nil

    releasePed(ped)
    if exitPos then
        SetEntityCoords(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false, false)
    end
    TriggerServerEvent('warsim_rappel:stop')
end

---------------------------------------------------------------------------
-- Bucle de control (W/S, parada libre, armas solo en parado)
---------------------------------------------------------------------------
local function controlLoop()
    while rappel do
        local ped = PlayerPedId()
        local r = rappel

        if IsEntityDead(ped) then
            stopRappel(nil)
            break
        end

        -- El jugador no camina, salta ni se cubre mientras cuelga.
        DisableControlAction(0, 30, true)  -- mover izquierda/derecha
        DisableControlAction(0, 31, true)  -- mover delante/detrás
        DisableControlAction(0, mv.KeyUp, true)
        DisableControlAction(0, mv.KeyDown, true)
        DisableControlAction(0, 34, true)
        DisableControlAction(0, 35, true)
        DisableControlAction(0, 21, true)  -- sprint
        DisableControlAction(0, 22, true)  -- saltar
        DisableControlAction(0, 23, true)  -- entrar en vehículo
        DisableControlAction(0, 36, true)  -- agacharse
        DisableControlAction(0, 44, true)  -- cobertura

        local up = IsDisabledControlPressed(0, mv.KeyUp)
        local down = IsDisabledControlPressed(0, mv.KeyDown)
        local dir = 0
        if up and not down then dir = 1 elseif down and not up then dir = -1 end

        if dir ~= 0 then
            -- En movimiento: las dos manos en la cuerda, sin armas.
            DisableControlAction(0, 24, true)  -- disparar
            DisableControlAction(0, 25, true)  -- apuntar
            DisableControlAction(0, 37, true)  -- rueda de armas
            DisableControlAction(0, 45, true)  -- recargar
            DisablePlayerFiring(PlayerId(), true)
            if GetSelectedPedWeapon(ped) ~= UNARMED then
                SetCurrentPedWeapon(ped, UNARMED, true)
            end

            local speed = dir > 0 and mv.AscendSpeed or mv.DescendSpeed
            r.z = r.z + dir * speed * GetFrameTime()

            if dir > 0 and r.z >= r.maxZ then
                stopRappel(r.topExit)
                break
            elseif dir < 0 and r.z <= r.minZ then
                stopRappel(r.bottomExit)
                break
            end

            SetEntityCoordsNoOffset(ped, r.x, r.y, r.z, false, false, false)
            SetEntityHeading(ped, r.heading)
            local base = (anims.WalkLegs and not r.legsFailed) and anims.Legs or anims.Move
            if r.anim ~= 'move' and r.anim ~= 'move_fallback' then
                playAnim(ped, base, 1)
                if base == anims.Legs then
                    -- Encima, solo de cintura para arriba (16) y como tarea secundaria (32):
                    -- torso y manos en la cuerda mientras las piernas caminan.
                    playAnim(ped, anims.Idle, 1 + 16 + 32)
                    SetEntityAnimSpeed(ped, base.dict, base.name, base.speed or 1.0)
                end
                r.anim = 'move'
                r.animAt = GetGameTimer()
            elseif r.anim == 'move' and GetGameTimer() - r.animAt > 300
                and not IsEntityPlayingAnim(ped, base.dict, base.name, 3) then
                -- La animación no existe o no carga: usar la de colgar en vez de dejar
                -- al personaje en pose T.
                if base == anims.Legs then r.legsFailed = true end
                ClearPedSecondaryTask(ped)
                playAnim(ped, anims.Idle, 1)
                r.anim = 'move_fallback'
            end
        elseif GetSelectedPedWeapon(ped) ~= UNARMED then
            -- Parado con arma en mano: la animación de colgar ocupa todo el cuerpo y bloquea
            -- la tarea de apuntar, así que se quita para usar el sistema de armas normal.
            if r.anim then
                ClearPedSecondaryTask(ped)
                ClearPedTasks(ped)
                SetEntityCoordsNoOffset(ped, r.x, r.y, r.z, false, false, false)
                r.anim = nil
            end
        elseif r.anim ~= 'idle' or not IsEntityPlayingAnim(ped, anims.Idle.dict, anims.Idle.name, 3) then
            -- Parado sin arma: animación de colgar quieto.
            ClearPedSecondaryTask(ped)
            SetEntityCoordsNoOffset(ped, r.x, r.y, r.z, false, false, false)
            SetEntityHeading(ped, r.heading)
            playAnim(ped, anims.Idle, 1)
            r.anim = 'idle'
        end

        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(Config.Text.Help)
        EndTextCommandDisplayHelp(0, false, false, -1)

        Wait(0)
    end
end

---------------------------------------------------------------------------
-- Inicio del rappel
---------------------------------------------------------------------------
local function startRappel(data)
    local ped = PlayerPedId()
    local n = data.normal
    local ropeXY = data.wall + n * mv.WallOffset

    local minZ = data.bottomZ + mv.PedRootOffset
    local maxZ = data.topZ + mv.PedRootOffset - mv.TopHangDepth

    rappel = {
        x = ropeXY.x,
        y = ropeXY.y,
        z = data.startAtTop and maxZ or math.min(minZ + 0.3, maxZ),
        minZ = minZ,
        maxZ = maxZ,
        heading = GetHeadingFromVector_2d(-n.x, -n.y),
        topExit = data.topStand,
        bottomExit = vector3(ropeXY.x, ropeXY.y, data.bottomZ),
        anim = nil,
    }

    SetCurrentPedWeapon(ped, UNARMED, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, rappel.x, rappel.y, rappel.z, false, false, false)
    SetEntityHeading(ped, rappel.heading)

    CreateThread(controlLoop)
end

-- Punto de anclaje de la cuerda: en el borde superior de la pared.
local function anchorFor(data)
    local a = data.wall + data.normal * 0.05
    return vector3(a.x, a.y, data.topZ + 0.1)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

-- El servidor avisa de que el jugador ha usado el objeto.
RegisterNetEvent('warsim_rappel:tryStart', function()
    local ped = PlayerPedId()
    if rappel or pending or not canStart(ped) then
        notify(Config.Text.CantNow)
        TriggerServerEvent('warsim_rappel:cancel')
        return
    end

    local data, err = Detection.Find(ped)
    if not data then
        notify(err)
        TriggerServerEvent('warsim_rappel:cancel') -- el objeto NO se consume
        return
    end

    pending = data
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, UNARMED, true)
    playAnim(ped, anims.Hook, 1)
    Wait(anims.Hook.duration)

    TriggerServerEvent('warsim_rappel:confirm', anchorFor(data))

    -- Si el servidor no responde, liberar al jugador.
    local sent = pending
    SetTimeout(Config.ConfirmTimeout * 1000, function()
        if pending == sent then
            pending = nil
            releasePed(PlayerPedId())
        end
    end)
end)

-- Respuesta del servidor tras intentar consumir el objeto.
RegisterNetEvent('warsim_rappel:begin', function(ok)
    local data = pending
    pending = nil
    if not data then return end

    if not ok then
        releasePed(PlayerPedId())
        notify(Config.Text.NoItem)
        return
    end
    startRappel(data)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if rappel or pending then
        rappel, pending = nil, nil
        releasePed(PlayerPedId())
    end
end)

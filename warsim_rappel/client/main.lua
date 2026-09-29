local mv = Config.Movement
local anims = Config.Anims

local UNARMED = `WEAPON_UNARMED`

local rappel = nil   -- estado del rappel en curso
local pending = nil  -- superficie detectada a la espera de que el servidor consuma el objeto

local function debug(...)
    if Config.Debug then print('[warsim_rappel]', ...) end
end

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

local function playAnim(ped, anim)
    if loadDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.name, anim.blend or 4.0, -1.0, -1, anim.flag or 1, 0.0, false, false, false)
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

-- Coloca el origen del ped (≈ cadera) en z. SET_ENTITY_COORDS pone los pies en la z que
-- recibe, por eso se resta PedRootOffset. El ped NO se congela: congelarlo y moverlo en
-- cada fotograma es lo que lo dejaba en pose T.
local function setRoot(ped, x, y, z)
    SetEntityCoords(ped, x, y, z - mv.PedRootOffset, true, true, true, false)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
end

-- Devuelve al ped su estado normal (gravedad, ragdoll, sin animación).
local function releasePed(ped)
    FreezeEntityPosition(ped, false)
    SetPedGravity(ped, true)
    SetPedCanRagdoll(ped, true)
    ClearPedTasks(ped)
end

---------------------------------------------------------------------------
-- Fin del rappel
---------------------------------------------------------------------------

-- Red de seguridad: si tras soltarlo el personaje cae por debajo del suelo esperado,
-- se le devuelve al punto donde usó la cuerda.
local function watchFall(ped, groundZ, safePos)
    CreateThread(function()
        local t = GetGameTimer()
        while GetGameTimer() - t < 5000 do
            local p = GetEntityCoords(ped)
            if p.z < groundZ - 3.0 then
                debug(('ha atravesado el suelo (z %.2f, suelo %.2f): vuelta al punto de inicio'):format(p.z, groundZ))
                FreezeEntityPosition(ped, true)
                SetEntityCoords(ped, safePos.x, safePos.y, safePos.z - mv.PedRootOffset, true, true, true, false)
                SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                local w = GetGameTimer()
                while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - w < 2000 do
                    RequestCollisionAtCoord(safePos.x, safePos.y, safePos.z)
                    Wait(0)
                end
                FreezeEntityPosition(ped, false)
                return
            end
            Wait(0)
        end
    end)
end

-- how = 'drop' → abajo: suelta la cuerda a ReleaseHeight del suelo y cae con la gravedad normal.
-- how = 'top'  → arriba: queda de pie en la cornisa.
-- how = nil    → muerte / recurso parado: solo se suelta.
local function stopRappel(how)
    local r = rappel
    if not r then return end
    local ped = PlayerPedId()
    rappel = nil
    debug('fin del rappel: ' .. tostring(how))

    if how == 'top' then
        local e = r.topExit
        RequestCollisionAtCoord(e.x, e.y, e.z)
        -- SET_ENTITY_COORDS con la z del suelo deja los pies sobre la cornisa.
        SetEntityCoords(ped, e.x, e.y, e.z, true, true, true, false)
        SetEntityHeading(ped, r.heading)
        watchFall(ped, e.z, r.startPos)
    elseif how == 'drop' then
        RequestCollisionAtCoord(r.x, r.y, r.bottomZ)
        watchFall(ped, r.bottomZ, r.startPos)
    end

    releasePed(ped)
    TriggerServerEvent('warsim_rappel:stop')
end

---------------------------------------------------------------------------
-- Bucle de control (W/S, parada libre, armas solo en parado)
---------------------------------------------------------------------------
local function setState(ped, r, state)
    if r.state == state then return end
    r.state = state
    if state == 'move' then
        playAnim(ped, anims.Move)
    elseif state == 'idle' then
        playAnim(ped, anims.Idle)
    elseif state == 'armed' then
        -- La animación de colgar ocupa todo el cuerpo y bloquea la tarea de apuntar.
        ClearPedTasks(ped)
    end
end

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
        local armed = GetSelectedPedWeapon(ped) ~= UNARMED

        if dir ~= 0 then
            -- En movimiento: las dos manos en la cuerda, sin armas.
            DisableControlAction(0, 24, true)  -- disparar
            DisableControlAction(0, 25, true)  -- apuntar
            DisableControlAction(0, 37, true)  -- rueda de armas
            DisableControlAction(0, 45, true)  -- recargar
            DisablePlayerFiring(PlayerId(), true)
            if armed then
                SetCurrentPedWeapon(ped, UNARMED, true)
                armed = false
            end

            local speed = dir > 0 and mv.AscendSpeed or mv.DescendSpeed
            r.z = r.z + dir * speed * GetFrameTime()

            if dir > 0 and r.z >= r.maxZ then
                stopRappel('top')
                break
            elseif dir < 0 and r.z <= r.minZ then
                stopRappel('drop')
                break
            end

            -- Al bajar: si ya hay suelo a ReleaseHeight bajo los pies, soltar la cuerda ahí
            -- aunque la altura calculada al enganchar fuese otra.
            if dir < 0 and r.z < r.maxZ - 1.5 then
                local gz = Detection.GroundBelow(vector3(r.x, r.y, r.z),
                    mv.PedRootOffset + mv.ReleaseHeight + 0.1, ped)
                if gz then
                    stopRappel('drop')
                    break
                end
            end

            setState(ped, r, 'move')
        elseif armed then
            -- Parado con arma: sistema de armas normal, girando con la cámara.
            setState(ped, r, 'armed')
        else
            setState(ped, r, 'idle')
        end

        -- Sin gravedad el ped no cae; se le recoloca en la cuerda cada fotograma.
        setRoot(ped, r.x, r.y, r.z)
        if r.state == 'armed' then
            SetEntityHeading(ped, GetGameplayCamRot(2).z)
        else
            SetEntityHeading(ped, r.heading)
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

    -- Abajo no se llega al suelo: se suelta la cuerda a ReleaseHeight y se cae solo.
    local minZ = data.bottomZ + mv.PedRootOffset + mv.ReleaseHeight
    local maxZ = data.topZ + mv.PedRootOffset - mv.TopHangDepth
    local heading = GetHeadingFromVector_2d(-n.x, -n.y)
    local z = data.startAtTop and maxZ or math.min(data.bottomZ + mv.PedRootOffset + 0.3, maxZ)

    rappel = {
        x = ropeXY.x,
        y = ropeXY.y,
        z = z,
        minZ = minZ,
        maxZ = maxZ,
        heading = heading,
        topExit = data.topStand,
        bottomZ = data.bottomZ,
        startPos = GetEntityCoords(ped),
        state = nil,
    }

    ClearPedTasksImmediately(ped)
    SetCurrentPedWeapon(ped, UNARMED, true)
    FreezeEntityPosition(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedGravity(ped, false)
    setRoot(ped, rappel.x, rappel.y, rappel.z)
    SetEntityHeading(ped, heading)

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
    debug('objeto usado, comprobando superficie...')
    if rappel or pending or not canStart(ped) then
        debug('no se puede empezar ahora (ya en rappel, en vehículo, cayendo, nadando...)')
        notify(Config.Text.CantNow)
        TriggerServerEvent('warsim_rappel:cancel', 'no puede ahora')
        return
    end

    local data, err = Detection.Find(ped)
    if not data then
        debug('superficie no válida: ' .. tostring(err))
        notify(err)
        TriggerServerEvent('warsim_rappel:cancel', err) -- el objeto NO se consume
        return
    end
    debug(('superficie válida: %s, suelo %.2f, borde %.2f, altura %.2f m'):format(
        data.startAtTop and 'desde arriba' or 'desde abajo', data.bottomZ, data.topZ, data.topZ - data.bottomZ))

    pending = data
    local hook = data.startAtTop and anims.HookTop or anims.HookBottom
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, UNARMED, true)
    playAnim(ped, hook)
    Wait(hook.duration)

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
    debug('respuesta del servidor: ' .. tostring(ok))
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
    if rappel then
        stopRappel(nil)
    elseif pending then
        pending = nil
        releasePed(PlayerPedId())
    end
end)

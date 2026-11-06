-- Salida VOLUNTARIA segura. El ped permanece congelado hasta confirmar suelo real.
--  1) raycast hacia abajo para el suelo real + margen
--  2) forzar carga de colision en la zona
--  3) descongelar solo si se confirma suelo (varios frames seguidos y tras cargar la colision)
--  4) red de seguridad: si cae por debajo del punto de salida durante X s, se le devuelve
-- La salida por interrupcion (muerte) NO pasa por aqui.
SafeExit = {}

local netActiveUntil = 0

local function groundAt(target, ignore, up)
    local c = Config.Exit
    local from = vector3(target.x, target.y, target.z + up)
    local z = U.floorBelow(from, up + c.ProbeDown, ignore)
    return z
end

function SafeExit.netActive() return GetGameTimer() < netActiveUntil end

local function safetyNet(ped, final)
    local c = Config.Exit
    local session = Rappel.session
    netActiveUntil = GetGameTimer() + c.SafetyNetMs
    CreateThread(function()
        while GetGameTimer() < netActiveUntil do
            if U.isDead(ped) or (Rappel.active and Rappel.session ~= session) then break end -- muerte o nuevo rappel: sin red
            local p = GetEntityCoords(ped)
            local dxy = math.sqrt((p.x - final.x) ^ 2 + (p.y - final.y) ^ 2)
            if p.z < final.z - c.NetDrop and dxy < c.NetRadius then
                FreezeEntityPosition(ped, true)
                RequestCollisionAtCoord(final.x, final.y, final.z)
                SetEntityCoordsNoOffset(ped, final.x, final.y, final.z, false, false, false)
                SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                local t = GetGameTimer() + 1000
                while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
                FreezeEntityPosition(ped, false)
            end
            Wait(0)
        end
        netActiveUntil = 0
    end)
end

-- probeUp: altura sobre target desde la que se busca el suelo (bajo para no 'aterrizar' en salientes superiores).
-- tick(): callback por frame mientras se espera (restricciones, cuerda...).
-- Devuelve 'ok' | 'noground' | 'dead'
function SafeExit.run(ped, target, heading, tick, probeUp)
    local c = Config.Exit
    local up = probeUp or c.ProbeUp
    local deadline = GetGameTimer() + c.Timeout
    local confirmed, gz = 0, nil

    while GetGameTimer() < deadline do
        if U.isDead(ped) then return 'dead' end
        if tick then tick() end
        RequestCollisionAtCoord(target.x, target.y, target.z)
        local z = groundAt(target, ped, up)
        if z and gz and math.abs(z - gz) < 0.05 then
            confirmed = confirmed + 1
        else
            confirmed = z and 1 or 0
        end
        gz = z

        if confirmed >= c.ConfirmFrames then
            local final = vector3(target.x, target.y, gz + Config.PedRootHeight + c.Margin)
            -- sigue congelado: se coloca y se espera a que cargue la colision alrededor
            SetEntityCoordsNoOffset(ped, final.x, final.y, final.z, false, false, false)
            while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
                if U.isDead(ped) then return 'dead' end
                if tick then tick() end
                RequestCollisionAtCoord(final.x, final.y, final.z)
                Wait(0)
            end
            if HasCollisionLoadedAroundEntity(ped) then
                local z2 = groundAt(target, ped, up)
                if z2 and math.abs(z2 - gz) < 0.3 then
                    final = vector3(target.x, target.y, z2 + Config.PedRootHeight + c.Margin)
                    ClearPedTasksImmediately(ped)
                    SetEntityRotation(ped, 0.0, 0.0, heading, 2, true)
                    SetEntityCoordsNoOffset(ped, final.x, final.y, final.z, false, false, false)
                    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                    FreezeEntityPosition(ped, false)
                    safetyNet(ped, final)
                    return 'ok'
                end
            end
            confirmed = 0
        end
        Wait(0)
    end
    return 'noground'
end

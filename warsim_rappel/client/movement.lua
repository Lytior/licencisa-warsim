-- Movimiento en la cuerda: W sube, S baja, Espacio impulsos encadenados (solo bajando).
Movement = {}

local function allowedDown(gd)
    local m = Config.Move
    if gd >= m.BrakeDistance then return m.MaxSpeed end
    return U.lerp(m.MinSpeed, m.MaxSpeed, U.clamp(gd / m.BrakeDistance, 0.0, 1.0))
end

local function startImpulse(R, gd)
    local m = Config.Move
    local drop = m.ImpulseDrop * (1.0 + R.chain * m.ChainGain)
    drop = math.min(drop, m.MaxSpeed * m.ImpulseTime, allowedDown(gd) * m.ImpulseTime * 1.5,
        gd - m.ImpulseGroundMargin)
    if drop < m.ImpulseMinDrop then R.chain = 0 return false end
    R.impulseId = (R.impulseId or 0) + 1
    R.impulse = { t = 0.0, z0 = R.z, drop = drop, push = 0.0 }
    return true
end

-- Actualiza R.z, R.vel, R.impulse y devuelve el estado de movimiento.
function Movement.tick(R, dt)
    local m, k = Config.Move, Config.Keys
    local up = IsDisabledControlPressed(0, k.Up)
    local down = IsDisabledControlPressed(0, k.Down)
    local jump = IsDisabledControlPressed(0, k.Impulse)
    local gd = R.groundDist or 999.0

    if R.impulse then
        local im = R.impulse
        im.t = im.t + dt / m.ImpulseTime
        local kk = math.min(im.t, 1.0)
        local newZ = im.z0 - im.drop * U.smooth(kk)
        R.vel = (newZ - R.z) / math.max(dt, 0.001)
        R.z = newZ
        im.push = math.sin(math.pi * kk) * m.ImpulsePush
        if kk >= 1.0 or gd <= m.BottomThreshold then
            R.impulse = nil
            if jump and gd > m.ImpulseGroundMargin then
                R.chain = math.min(R.chain + 1, m.MaxChain)
                startImpulse(R, gd)
            else
                R.chain = 0
                R.vel = -m.DownSpeed * 0.5
            end
        end
    elseif jump and not up and gd > m.ImpulseGroundMargin and startImpulse(R, gd) then
        -- impulso iniciado
    else
        local target = (down and -m.DownSpeed) or (up and m.UpSpeed) or 0.0
        R.vel = U.approach(R.vel, target, m.Accel * dt)
        if R.vel < 0 then R.vel = math.max(R.vel, -allowedDown(gd)) end
        R.z = R.z + R.vel * dt
    end

    -- Limites: nunca por encima del tope ni por debajo del suelo
    if R.z >= R.topZ then R.z = R.topZ; if R.vel > 0 then R.vel = 0 end end
    if gd < 0 then R.z = R.z - gd; if R.vel < 0 then R.vel = 0 end end

    if R.impulse then return RState.IMPULSE end
    if R.z >= R.topZ - 0.02 and not down then
        return R.plan.hasEdge and RState.TOP or RState.STOPPED
    end
    if gd <= m.BottomThreshold and not up then R.vel = 0 return RState.BOTTOM end
    if math.abs(R.vel) > 0.05 then return R.vel > 0 and RState.ASCEND or RState.DESCEND end
    return RState.STOPPED
end

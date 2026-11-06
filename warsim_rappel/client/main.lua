-- Controlador del jugador local (es quien decide y envia el estado).
Rappel = { active = false, busy = false, state = RState.IDLE, session = 0 }
local R = Rappel
local S = RState

---------------------------------------------------------------- red
local Net = { last = 0, lastZ = -99999.0, lastS = -1 }

local function netSend(force)
    local now = GetGameTimer()
    local c = Config.Net
    if force or R.state ~= Net.lastS
        or (now - Net.last >= c.MinInterval and math.abs(R.z - Net.lastZ) > c.MinDeltaZ)
        or now - Net.last >= c.Heartbeat then
        Net.last, Net.lastZ, Net.lastS = now, R.z, R.state
        TriggerServerEvent('warsim_rappel:update', R.state,
            math.floor(R.z * 100 + 0.5) / 100, math.floor((R.vel or 0) * 10 + 0.5) / 10)
    end
end

local function groundDistance(pos, ped)
    local fz = U.floorBelow(pos, 400.0, ped)
    if not fz then return 999.0 end
    return pos.z - fz - Config.PedRootHeight
end

---------------------------------------------------------------- fin
local function cleanup(ped)
    RopeVisual.destroy(R.rope)
    R.rope = nil
    Restrictions.finish(ped)
    Anim.forget(ped)
    R.active = false
    R.state = S.IDLE
    R.plan, R.tracker, R.impulse, R.climb = nil, nil, nil, nil
    TriggerServerEvent('warsim_rappel:stop')
end

-- Interrupcion (muerte u otra): se corta al instante y cae por gravedad. SIN red de seguridad.
function R.interrupt(reason)
    if not R.active then return end
    local ped = PlayerPedId()
    local n = R.tracker and R.tracker.normal
    Anim.stop(ped)
    ClearPedSecondaryTask(ped)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    if n then
        local nh = U.horiz(n)
        if nh then SetEntityVelocity(ped, nh.x * 0.8, nh.y * 0.8, 0.0) end
    end
    if not U.isDead(ped) then SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false) end
    cleanup(ped)
end

local function finishVoluntary(ped)
    cleanup(ped)
end

---------------------------------------------------------------- salidas voluntarias
local function exitTick(ped)
    return function()
        Restrictions.tick(ped)
        if R.rope then RopeVisual.update(R.rope, Pose.harness(ped), Pose.hand(ped), GetFrameTime()) end
    end
end

local function exitBottom(ped)
    local prev = R.state
    R.state = S.EXIT
    netSend(true)
    Anim.playState(ped, S.EXIT, true)
    local nh = U.horiz(R.tracker.normal) or R.tracker.n0h
    local target = GetEntityCoords(ped) + nh * Config.Exit.BottomPushOut
    local heading = GetHeadingFromVector_2d(-nh.x, -nh.y)
    local res = SafeExit.run(ped, target, heading, exitTick(ped), Config.Exit.BottomProbeUp)
    if res == 'ok' then finishVoluntary(ped)
    elseif res == 'dead' then R.interrupt('death')
    else R.state = prev; U.notify(Config.Text.NoGround) end
end

local function startClimb(ped)
    R.state = S.CLIMB
    R.climb = { t = 0.0, from = GetEntityCoords(ped), to = Pose.standPos(R.plan.anchor, R.plan.n0) }
    Anim.playState(ped, S.CLIMB, true)
    netSend(true)
end

local function climbTick(ped, dt)
    local c = R.climb
    c.t = c.t + dt / Config.Top.ClimbTime
    local pos = Pose.climbPath(c.from, c.to, math.min(c.t, 1.0))
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    local nh = R.tracker.n0h
    local heading = GetHeadingFromVector_2d(-nh.x, -nh.y)
    local pitch = U.rotationFromNormal(R.tracker.normal)
    SetEntityRotation(ped, pitch * (1.0 - U.smooth(c.t)), 0.0, heading, 2, true)
    RopeVisual.update(R.rope, Pose.harness(ped), Pose.hand(ped), dt)
    netSend()
    if c.t >= 1.0 then
        R.state = S.EXIT
        netSend(true)
        local res = SafeExit.run(ped, c.to, heading, exitTick(ped))
        if res == 'ok' then finishVoluntary(ped)
        elseif res == 'dead' then R.interrupt('death')
        else
            -- sin suelo arriba (no deberia pasar): vuelve a colgar
            U.notify(Config.Text.NoGround)
            R.climb = nil
            R.state = S.TOP
            R.blend, R.blendFrom = 0.0, GetEntityCoords(ped)
        end
    end
end

---------------------------------------------------------------- bucle
local function frame(ped, dt)
    if U.isDead(ped) then return R.interrupt('death') end
    Restrictions.tick(ped)

    if R.state == S.CLIMB then return climbTick(ped, dt) end

    local mstate = Movement.tick(R, dt)
    local pos, _, n = R.tracker:update(R.z, dt)
    if R.impulse then pos = pos + n * R.impulse.push end
    if R.blend < 1.0 then
        R.blend = R.blend + dt / Config.Pose.AttachTime
        pos = Pose.blendPath(R.blendFrom, pos, R.blend)
        mstate = (R.blend < 1.0) and S.HOOK or mstate
    end
    Pose.apply(ped, pos, n)
    R.groundDist = groundDistance(pos, ped)

    local newImpulse = R.impulseId ~= R.lastImpulseId
    R.lastImpulseId = R.impulseId
    R.state = mstate
    Anim.playState(ped, R.state, R.state == S.IMPULSE and newImpulse)

    local harness = Pose.harness(ped)
    RopeVisual.update(R.rope, harness, Pose.hand(ped), dt)
    Pose.applyIK(ped, R.plan.anchor, harness)
    netSend()

    if R.state == S.BOTTOM then
        U.help(Config.Text.HelpBottom)
        if IsDisabledControlJustPressed(0, Config.Keys.Exit) then exitBottom(ped) end
    elseif R.state == S.TOP and R.plan.hasEdge then
        U.help(Config.Text.HelpTop)
        if IsDisabledControlJustPressed(0, Config.Keys.Exit) then startClimb(ped) end
    elseif R.state ~= S.HOOK then
        U.help(Config.Text.HelpMove)
    end
end

local function attach(ped, plan)
    R.session = R.session + 1
    R.plan = plan
    R.tracker = SurfaceTracker.new(plan.anchor, plan.n0, plan.depth0, plan.wallNormal, ped)
    R.tracker:warmTo(plan.wallPoint.z, plan.z0)
    R.topZ = plan.topZ
    R.z = plan.z0
    R.vel, R.chain, R.impulse = 0.0, 0, nil
    R.groundDist = nil
    R.blend, R.blendFrom = 0.0, GetEntityCoords(ped)
    R.state = S.HOOK
    FreezeEntityPosition(ped, true)
    R.rope = RopeVisual.create(plan.anchor, Pose.harness(ped))
    netSend(true)

    CreateThread(function()
        local session = R.session
        while R.active and R.session == session do
            frame(PlayerPedId(), GetFrameTime())
            Wait(0)
        end
    end)
end

---------------------------------------------------------------- inicio
local function tryStart()
    local ped = PlayerPedId()
    if R.active or IsPedInAnyVehicle(ped, false) or U.isDead(ped) or IsPedFalling(ped)
        or IsPedSwimming(ped) or IsPedRagdoll(ped) then
        return U.notify(Config.Text.Busy)
    end

    local plan = Detect.find(ped)
    if not plan then return U.notify(Config.Text.NoSurface) end -- no se consume
    Detect.finalize(plan, ped)

    -- Desde aqui el rappel esta activo (restricciones y estado) aunque aun no este colgado
    R.active = true
    R.state = S.ANCHORING
    R.z, R.vel = plan.z0, 0.0
    Restrictions.begin(ped)
    Anim.playState(ped, S.ANCHORING, true)

    -- El item se retira al empezar la animacion
    local p = promise.new()
    ESX.TriggerServerCallback('warsim_rappel:consume', function(ok) p:resolve(ok) end, {
        anchor = plan.anchor, n0 = plan.n0, wallNormal = plan.wallNormal, depth0 = plan.depth0,
        z0 = plan.z0, topZ = plan.topZ, hasEdge = plan.hasEdge, wallZ = plan.wallPoint.z,
    })
    local started = GetGameTimer()
    local ok = Citizen.Await(p)
    if not ok then
        Anim.stop(ped)
        Restrictions.finish(ped)
        R.active = false
        R.state = S.IDLE
        return U.notify(Config.Text.NoItem)
    end

    while GetGameTimer() - started < Config.Pose.AnchorTime do
        if U.isDead(ped) then return R.interrupt('death') end
        Restrictions.tick(ped)
        Wait(0)
    end
    if not R.active then return end
    attach(ped, plan)
end

RegisterNetEvent('warsim_rappel:tryStart', function()
    if R.busy then return end
    R.busy = true
    local ok, err = pcall(tryStart)
    if not ok then print('[warsim_rappel] ' .. tostring(err)); R.interrupt('error') end
    R.busy = false
end)

AddEventHandler('esx:onPlayerDeath', function() R.interrupt('death') end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and R.active then R.interrupt('resource') end
end)

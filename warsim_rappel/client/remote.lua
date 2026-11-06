-- Reproduccion de OTROS jugadores rapeleando.
-- Solo se recibe: anclaje (una vez) + estado, altura z y velocidad. Todo lo demas
-- (posicion sobre la superficie, cuerda, animacion, IK) se reconstruye aqui.
-- Para que se vea fluido se usa un clon local no networked que se coloca cada frame con
-- la altura interpolada; el ped real (sincronizado por red a menor frecuencia) se oculta localmente.
local S = RState
local remotes = {}

local function destroyVisual(e)
    if e.rope then RopeVisual.destroy(e.rope); e.rope = nil end
    if e.clone and DoesEntityExist(e.clone) then
        Anim.forget(e.clone)
        DeleteEntity(e.clone)
    end
    e.clone, e.tracker = nil, nil
end

local function interpolatedZ(e, now)
    local buf = e.buf
    if #buf == 0 then return e.z0 end
    local rt = now - Config.Net.InterpDelay
    if rt <= buf[1].t then return buf[1].z end
    for i = #buf - 1, 1, -1 do
        local a, b = buf[i], buf[i + 1]
        if rt >= a.t and rt <= b.t then
            return U.lerp(a.z, b.z, (rt - a.t) / math.max(b.t - a.t, 1))
        end
    end
    local last = buf[#buf]
    local ex = math.min(rt - last.t, Config.Net.MaxExtrapolate) / 1000.0
    local z = last.z + last.v * ex
    return math.min(z, e.topZ)
end

local function createVisual(e, real)
    local clone = ClonePed(real, false, false, true)
    if not clone or clone == 0 then return false end
    SetEntityCollision(clone, false, false)
    FreezeEntityPosition(clone, true)
    SetEntityInvincible(clone, true)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetPedCanRagdoll(clone, false)
    SetCurrentPedWeapon(clone, `WEAPON_UNARMED`, true)
    e.clone = clone
    e.tracker = SurfaceTracker.new(e.anchor, e.n0, e.depth0, e.wallNormal, clone)
    e.zr = interpolatedZ(e, GetGameTimer())
    e.tracker:warmTo(e.wallZ or e.z0, e.zr)
    e.blend, e.blendFrom = (e.s == S.HOOK) and 0.0 or 1.0, GetEntityCoords(real)
    e.rope = RopeVisual.create(e.anchor, Pose.harness(clone))
    e.lastState = nil
    return true
end

local function tickRemote(id, e, dt, now, myPos)
    local player = GetPlayerFromServerId(id)
    local real = player ~= -1 and GetPlayerPed(player) or 0
    if real == 0 or not DoesEntityExist(real)
        or e.s == S.ANCHORING or e.s == S.IDLE
        or #(myPos - e.anchor) > Config.Net.RenderRange then
        if e.clone then destroyVisual(e) end
        return
    end
    if not e.clone and not createVisual(e, real) then return end
    SetEntityLocallyInvisible(real)

    local clone = e.clone
    local target = interpolatedZ(e, now)
    e.zr = U.lerp(e.zr, target, 1.0 - math.exp(-Config.Net.RemoteSmooth * dt))

    local stateChanged = e.s ~= e.lastState
    e.lastState = e.s

    if e.s == S.CLIMB or (e.s == S.EXIT and e.climb) then
        if not e.climb then
            e.climb = { t = 0.0, from = GetEntityCoords(clone), to = Pose.standPos(e.anchor, e.n0) }
        end
        local c = e.climb
        c.t = math.min(c.t + dt / Config.Top.ClimbTime, 1.0)
        local pos = Pose.climbPath(c.from, c.to, c.t)
        SetEntityCoordsNoOffset(clone, pos.x, pos.y, pos.z, false, false, false)
        local nh = e.tracker.n0h
        SetEntityRotation(clone, 0.0, 0.0, GetHeadingFromVector_2d(-nh.x, -nh.y), 2, true)
    elseif e.s ~= S.EXIT then
        e.climb = nil
        local pos, _, n = e.tracker:update(e.zr, dt)
        if e.s == S.IMPULSE then
            if stateChanged or not e.impStart then e.impStart = now end
            local k = (now - e.impStart) / (Config.Move.ImpulseTime * 1000.0)
            if k >= 1.0 then e.impStart = now; k = 0.0; stateChanged = true end
            pos = pos + n * (math.sin(math.pi * k) * Config.Move.ImpulsePush)
        else
            e.impStart = nil
        end
        if e.blend < 1.0 then
            e.blend = e.blend + dt / Config.Pose.AttachTime
            pos = Pose.blendPath(e.blendFrom, pos, e.blend)
        end
        Pose.apply(clone, pos, n)
    end
    -- EXIT sin trepar: el clon se queda quieto hasta que llega remoteStop

    Anim.playState(clone, e.s, stateChanged and e.s == S.IMPULSE)
    local harness = Pose.harness(clone)
    RopeVisual.update(e.rope, harness, Pose.hand(clone), dt)
    Pose.applyIK(clone, e.anchor, harness)
end

CreateThread(function()
    while true do
        if next(remotes) then
            local dt, now = GetFrameTime(), GetGameTimer()
            local myPos = GetEntityCoords(PlayerPedId())
            for id, e in pairs(remotes) do tickRemote(id, e, dt, now, myPos) end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function addRemote(src, data, s, z, v)
    if src == GetPlayerServerId(PlayerId()) then return end
    if remotes[src] then destroyVisual(remotes[src]) end
    remotes[src] = {
        anchor = data.anchor, n0 = data.n0, wallNormal = data.wallNormal, depth0 = data.depth0,
        z0 = data.z0, topZ = data.topZ, hasEdge = data.hasEdge, wallZ = data.wallZ,
        s = s or S.ANCHORING, buf = {},
    }
    if z then remotes[src].buf[1] = { t = GetGameTimer(), z = z, v = v or 0.0 } end
end

RegisterNetEvent('warsim_rappel:remoteStart', function(src, data) addRemote(src, data) end)

RegisterNetEvent('warsim_rappel:remoteUpdate', function(src, s, z, v)
    local e = remotes[src]
    if not e then return end
    e.s = s
    local buf = e.buf
    buf[#buf + 1] = { t = GetGameTimer(), z = z, v = v }
    if #buf > 8 then table.remove(buf, 1) end
end)

RegisterNetEvent('warsim_rappel:remoteStop', function(src)
    local e = remotes[src]
    if not e then return end
    destroyVisual(e)
    remotes[src] = nil
end)

RegisterNetEvent('warsim_rappel:activeList', function(list)
    for src, a in pairs(list) do addRemote(src, a.data, a.s, a.z, a.v) end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    TriggerServerEvent('warsim_rappel:requestActive')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(remotes) do destroyVisual(e) end
end)

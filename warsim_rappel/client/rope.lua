-- Representacion visual de la cuerda (siempre local, nunca se envia por red).
--   tense: tramo recto del anclaje al descendedor del cinturon.
--   slack: sobrante que sale de la mano de freno y cuelga con fisica.
-- Los puntos de enganche se filtran (paso bajo) para que el temblor de los huesos no llegue a la cuerda.
RopeVisual = {}

local function texturesReady()
    if RopeAreTexturesLoaded() then return true end
    RopeLoadTextures()
    local t = GetGameTimer() + 3000
    while not RopeAreTexturesLoaded() and GetGameTimer() < t do Wait(0) end
    return RopeAreTexturesLoaded()
end

local function newRope(pos, len, maxLen)
    local c = Config.Rope
    local r = AddRope(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, len, c.Type, maxLen, c.MinLength,
        0.0, false, false, false, 1.0, false, 0)
    if r and r ~= 0 and DoesRopeExist(r) then return r end
    return nil
end

local function newProp()
    local m = Config.Rope.PropModel
    RequestModel(m)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(m) then return nil end
    local e = CreateObjectNoOffset(m, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, true)
    SetModelAsNoLongerNeeded(m)
    return e
end

-- Estira un prop de 1 m (eje Z) entre dos puntos.
local function stretch(e, a, b)
    if not e then return end
    local up = b - a
    local len = #up
    if len < 0.01 then return end
    local dir = up / len
    local ref = math.abs(dir.z) < 0.95 and U.UP or vector3(1.0, 0.0, 0.0)
    local right = U.norm(vector3(dir.y * ref.z - dir.z * ref.y, dir.z * ref.x - dir.x * ref.z, dir.x * ref.y - dir.y * ref.x))
    local fwd = vector3(right.y * dir.z - right.z * dir.y, right.z * dir.x - right.x * dir.z, right.x * dir.y - right.y * dir.x)
    SetEntityMatrix(e, fwd.x, fwd.y, fwd.z, right.x, right.y, right.z,
        up.x, up.y, up.z, a.x, a.y, a.z)
end

function RopeVisual.create(anchor, harness)
    local c = Config.Rope
    local o = { anchor = anchor, harness = harness, hand = harness, lenSet = 0.0 }
    if c.UseNatives and texturesReady() then
        local L = math.max(#(anchor - harness), 0.5)
        o.tense = newRope(anchor, L, c.MaxLength)
        o.slack = newRope(harness, c.SlackLength, c.SlackLength)
        if o.tense and o.slack then
            o.mode = 'native'
            RopeForceLength(o.tense, L * c.Tension)
            o.lenSet = L
        else
            if o.tense then DeleteRope(o.tense) end
            if o.slack then DeleteRope(o.slack) end
            o.tense, o.slack = nil, nil
        end
    end
    if not o.mode then
        o.mode = 'prop'
        o.tenseProp = newProp()
        o.slackProp = newProp()
    end
    return o
end

function RopeVisual.update(o, harnessRaw, handRaw, dt)
    if not o then return end
    local c = Config.Rope
    local k = 1.0 - math.exp(-c.Smooth * math.max(dt, 0.001))
    o.harness = U.lerp(o.harness, harnessRaw, k)
    o.hand = U.lerp(o.hand, handRaw, k)
    local a, h, hd = o.anchor, o.harness, o.hand

    if o.mode == 'native' then
        local L = #(a - h)
        if math.abs(L - o.lenSet) > c.LengthDeadZone then
            RopeForceLength(o.tense, math.max(L * c.Tension, c.MinLength))
            o.lenSet = L
        end
        local n = GetRopeVertexCount(o.tense)
        PinRopeVertex(o.tense, 0, a.x, a.y, a.z)
        if n > 1 then PinRopeVertex(o.tense, n - 1, h.x, h.y, h.z) end
        PinRopeVertex(o.slack, 0, hd.x, hd.y, hd.z)
        if GetRopeVertexCount(o.slack) > 2 then
            PinRopeVertex(o.slack, 1, hd.x, hd.y, hd.z - c.SlackPinDrop)
        end
    else
        stretch(o.tenseProp, h, a)
        stretch(o.slackProp, vector3(hd.x, hd.y, hd.z - 2.0), hd)
    end
end

function RopeVisual.destroy(o)
    if not o then return end
    if o.tense then DeleteRope(o.tense) end
    if o.slack then DeleteRope(o.slack) end
    if o.tenseProp and DoesEntityExist(o.tenseProp) then DeleteEntity(o.tenseProp) end
    if o.slackProp and DoesEntityExist(o.slackProp) then DeleteEntity(o.slackProp) end
    o.tense, o.slack, o.tenseProp, o.slackProp = nil, nil, nil, nil
end

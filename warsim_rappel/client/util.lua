if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end

U = {}

local UP = vector3(0.0, 0.0, 1.0)
U.UP = UP

function U.ray(from, to, ignore, flags)
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z,
        flags or Config.RayFlags, ignore or 0, 7)
    local _, hit, pos, normal, ent = GetShapeTestResult(h)
    if hit == 1 or hit == true then return pos, normal, ent end
    return nil
end

function U.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function U.norm(v)
    local l = #v
    if l < 1e-6 then return v end
    return v / l
end

function U.horiz(v)
    local l = math.sqrt(v.x * v.x + v.y * v.y)
    if l < 1e-4 then return nil end
    return vector3(v.x / l, v.y / l, 0.0)
end

function U.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function U.lerp(a, b, t) return a + (b - a) * t end
function U.smooth(t) t = U.clamp(t, 0.0, 1.0) return t * t * (3.0 - 2.0 * t) end

function U.approach(cur, target, maxStep)
    local d = target - cur
    if d > maxStep then return cur + maxStep elseif d < -maxStep then return cur - maxStep end
    return target
end

function U.angleDeg(a, b)
    return math.deg(math.acos(U.clamp(U.dot(U.norm(a), U.norm(b)), -1.0, 1.0)))
end

-- Primer suelo "pisable" bajo un punto (salta paredes y salientes verticales).
function U.floorBelow(from, maxDist, ignore)
    local start = from
    local bottom = from.z - maxDist
    for _ = 1, 6 do
        local pos, n = U.ray(start, vector3(start.x, start.y, bottom), ignore)
        if not pos then return nil end
        if n.z >= Config.FloorNormalZ then return pos.z, pos end
        start = vector3(start.x, start.y, pos.z - 0.05)
        if start.z <= bottom then return nil end
    end
    return nil
end

function U.notify(msg)
    if ESX and ESX.ShowNotification then ESX.ShowNotification(msg)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

function U.help(msg)
    AddTextEntry('WRAPPEL_HELP', msg)
    BeginTextCommandDisplayHelp('WRAPPEL_HELP')
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function U.loadDict(dict, timeout)
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeout or 1000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- Rotacion del ped segun la normal de la superficie.
function U.rotationFromNormal(n)
    local nh = U.horiz(n) or vector3(0.0, 1.0, 0.0)
    local yaw = GetHeadingFromVector_2d(-nh.x, -nh.y)
    local tilt = math.deg(math.asin(U.clamp(n.z, -1.0, 1.0)))
    local pitch = Config.Pose.BasePitch + tilt * Config.Pose.SlopePitchFactor * Config.Pose.SlopePitchSign
    return pitch, 0.0, yaw
end

function U.isDead(ped)
    return IsEntityDead(ped) or IsPedFatallyInjured(ped)
end

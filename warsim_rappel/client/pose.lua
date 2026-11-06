-- Utilidades de postura compartidas por el jugador local y los remotos.
Pose = {}

local PELVIS, R_HAND = 11816, 57005

function Pose.harness(ped)
    local fwd = GetEntityForwardVector(ped)
    return GetPedBoneCoords(ped, PELVIS, 0.0, 0.0, 0.0) + fwd * Config.Pose.HarnessForward
end

function Pose.hand(ped)
    return GetPedBoneCoords(ped, R_HAND, 0.0, 0.0, 0.0)
end

-- Transicion de enganche: primero horizontal, luego vertical (evita cruzar el bordillo).
function Pose.blendPath(from, to, t)
    local eh = U.smooth(math.min(1.0, t * 1.6))
    local ev = U.smooth((t - 0.3) / 0.7)
    return vector3(U.lerp(from.x, to.x, eh), U.lerp(from.y, to.y, eh), U.lerp(from.z, to.z, ev))
end

-- Trepar: primero sube por encima del borde, luego entra hacia el tejado.
function Pose.climbPath(from, to, t)
    local ev = U.smooth(math.min(1.0, t * 1.7))
    local eh = U.smooth((t - 0.35) / 0.65)
    return vector3(U.lerp(from.x, to.x, eh), U.lerp(from.y, to.y, eh), U.lerp(from.z, to.z, ev))
end

function Pose.standPos(anchor, n0)
    local n0h = U.horiz(n0)
    local p = anchor - n0h * Config.Top.StandInward
    return vector3(p.x, p.y, anchor.z + Config.PedRootHeight)
end

function Pose.apply(ped, pos, normal)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    local pitch, roll, yaw = U.rotationFromNormal(normal)
    SetEntityRotation(ped, pitch, roll, yaw, 2, true)
end

-- IK: mano guia (izq) sobre la cuerda tensa, mano de freno (der) junto a la cadera.
function Pose.applyIK(ped, anchor, harness)
    if not Config.IK.Enabled then return end
    local c = Config.IK
    local toAnchor = U.norm(anchor - harness)
    local guide = harness + toAnchor * c.GuideDist
    SetIkTarget(ped, c.LeftArm, 0, 0, guide.x, guide.y, guide.z, 0, 100, 100)
    local right = GetEntityForwardVector(ped)
    right = vector3(right.y, -right.x, 0.0)
    local brake = harness + right * c.BrakeRight - U.UP * c.BrakeDown
    SetIkTarget(ped, c.RightArm, 0, 0, brake.x, brake.y, brake.z, 0, 100, 100)
end

-- Deteccion de superficie al usar el item. Devuelve un "plan" de enganche o nil.
Detect = {}

local function avgNormal(list)
    local s = vector3(0.0, 0.0, 0.0)
    for i = 1, #list do s = s + list[i] end
    return U.norm(s / #list)
end

local function majority(total) return math.floor(total / 2) + 1 end

-- 1) Pared/ladera delante del jugador (inicio desde el suelo)
local function wallAhead(ped)
    local c = Config.Detect
    local pos = GetEntityCoords(ped)
    local fwd = U.horiz(GetEntityForwardVector(ped))
    if not fwd then return nil end
    local feet = pos.z - Config.PedRootHeight
    local normals, lowest = {}, nil
    for _, h in ipairs(c.WallHeights) do
        local o = vector3(pos.x, pos.y, feet + h)
        local p, n = U.ray(o, o + fwd * c.WallReach, ped)
        if p and math.abs(n.z) <= c.MaxWallNormalZ and U.dot(n, fwd) < -0.3 then
            normals[#normals + 1] = n
            lowest = lowest or p
        end
    end
    if #normals < majority(#c.WallHeights) then return nil end
    return lowest, avgNormal(normals)
end

-- Sube por la superficie (en el plano vertical) hasta encontrar el borde o la altura maxima.
local function marchUp(ped, base, n)
    local c = Config.Detect
    local n0h = U.horiz(n)
    local depth, lastHit, misses = 0.0, base, 0
    local steps = math.ceil(c.MaxSearchHeight / c.MarchStep)
    local foundEdge = false
    for i = 1, steps do
        local z = base.z + i * c.MarchStep
        local o = vector3(base.x + n0h.x * (depth + c.MarchProbeOut), base.y + n0h.y * (depth + c.MarchProbeOut), z)
        local p, nn = U.ray(o, o - n0h * (c.MarchProbeOut + c.MarchProbeIn), ped)
        if p and U.dot(nn, n0h) > Config.Surface.MinFacing then
            lastHit = p
            depth = U.dot(p - base, n0h)
            misses = 0
        else
            misses = misses + 1
            if misses >= c.EdgeMisses then foundEdge = true; break end
        end
        if i % 25 == 0 then Wait(0) end
    end

    if foundEdge then
        local top = lastHit - n0h * c.TopInward
        local probe = vector3(top.x, top.y, lastHit.z + c.MarchStep * c.EdgeMisses + 1.0)
        local fz = U.floorBelow(probe, c.MarchStep * c.EdgeMisses + 3.0, ped)
        if fz then return vector3(top.x, top.y, fz), true end
    end
    -- Sin borde detectable: anclaje a la altura maxima alcanzada
    return lastHit + n0h * 0.05, false
end

-- 2) Borde de tejado/caida delante del jugador (inicio colgando)
local function edgeAhead(ped)
    local c = Config.Detect
    local pos = GetEntityCoords(ped)
    local fwd = U.horiz(GetEntityForwardVector(ped))
    if not fwd then return nil end
    local feet = pos.z - Config.PedRootHeight

    local ahead = vector3(pos.x, pos.y, feet + 0.5) + fwd * c.EdgeProbeAhead
    if U.floorBelow(ahead, c.EdgeDropMin + 0.5, ped) then return nil end -- no hay caida

    local normals, closest = {}, nil
    for _, d in ipairs(c.EdgeWallDepths) do
        local o = vector3(pos.x, pos.y, feet - d) + fwd * c.EdgeBackProbe
        local p, n = U.ray(o, o - fwd * (c.EdgeBackProbe + 1.5), ped)
        if p and U.dot(n, fwd) > 0.3 then
            normals[#normals + 1] = n
            closest = closest or p
        end
    end
    if #normals < majority(#c.EdgeWallDepths) then return nil end
    local n = avgNormal(normals)
    local n0h = U.horiz(n) or fwd
    local top = closest - n0h * c.TopInward
    local fz = U.floorBelow(vector3(top.x, top.y, feet + 0.5), 1.5, ped) or feet
    return vector3(top.x, top.y, fz), n, closest
end

function Detect.find(ped)
    local wallPoint, n = wallAhead(ped)
    if wallPoint then
        local anchor, hasEdge = marchUp(ped, wallPoint, n)
        return {
            mode = 'ground', anchor = anchor, n0 = n, wallNormal = n, hasEdge = hasEdge,
            wallPoint = wallPoint,
        }
    end
    local anchor, en, wp = edgeAhead(ped)
    if anchor then
        return {
            mode = 'edge', anchor = anchor, n0 = en, wallNormal = en, hasEdge = true,
            wallPoint = wp,
        }
    end
    return nil
end

-- Completa el plan con los datos derivados que tambien necesitan los remotos.
function Detect.finalize(plan, ped)
    local n0h = U.horiz(plan.n0)
    plan.depth0 = U.dot(plan.wallPoint - plan.anchor, n0h)
    if plan.hasEdge then
        plan.topZ = plan.anchor.z - Config.Top.HangBelowEdge
    else
        plan.topZ = plan.anchor.z - Config.Top.NoEdgeMargin
    end
    if plan.mode == 'edge' then
        plan.z0 = plan.topZ
    else
        plan.z0 = math.min(GetEntityCoords(ped).z, plan.topZ)
    end
    return plan
end

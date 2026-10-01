-- Detección dinámica de superficies aptas para rappel mediante raycast.
-- No hay puntos de anclaje fijos: el anclaje se calcula a partir de la geometría del mapa.

Detection = {}

local cfg = Config.Detection

local function raycast(from, to, ignore)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        from.x, from.y, from.z, to.x, to.y, to.z, cfg.Flags, ignore, 7)
    local _, hit, coords, normal = GetShapeTestResult(handle)
    if hit == true or hit == 1 then
        return true, coords, normal
    end
    return false
end

-- Una superficie es "vertical" si su normal es casi horizontal.
local maxNormalZ = math.sin(math.rad(cfg.MaxWallTilt))

local function isVertical(normal)
    return math.abs(normal.z) <= maxNormalZ
end

local function horizontal(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y)
    if len < 0.001 then return vector3(0.0, 0.0, 0.0) end
    return vector3(v.x / len, v.y / len, 0.0)
end

local function groundBelow(pos, depth, ped)
    local hit, coords = raycast(pos, pos - vector3(0.0, 0.0, depth), ped)
    if hit then return coords.z end
end

Detection.GroundBelow = groundBelow

-- Busca, subiendo por la pared, el borde superior y la cornisa donde se puede pisar.
local function findLedge(wall, normal, fromZ, ped)
    local probeStart = wall + normal * 0.8
    local z = fromZ
    while z - fromZ <= cfg.MaxHeight do
        z = z + cfg.ScanStep
        local from = vector3(probeStart.x, probeStart.y, z)
        local hit = raycast(from, from - normal * 1.6, ped)
        if not hit then
            -- Por encima del borde: buscamos la superficie superior justo detrás de la pared.
            local inside = wall - normal * cfg.LedgeInset
            local top = vector3(inside.x, inside.y, z + 1.0)
            local ledgeHit, ledge, ledgeNormal = raycast(top, top - vector3(0.0, 0.0, cfg.ScanStep * 2 + 1.5), ped)
            if ledgeHit and ledgeNormal.z > 0.7 then
                return ledge
            end
            return nil
        end
    end
    return nil
end

-- Caso A: el jugador está abajo, mirando a la pared → empieza abajo y sube.
local function detectFromBottom(ped, pos, forward)
    local hit, wall, normal = raycast(pos, pos + forward * cfg.WallProbeDistance, ped)
    if not hit then return nil end
    if not isVertical(normal) then return nil, Config.Text.NoSurface end

    local groundZ = groundBelow(pos, 3.0, ped)
    if not groundZ then return nil, Config.Text.NoSurface end

    local n = horizontal(normal)
    local ledge = findLedge(wall, n, pos.z, ped)
    if not ledge then return nil, Config.Text.NoLedge end
    if ledge.z - groundZ < cfg.MinHeight then return nil, Config.Text.TooLow end

    return {
        wall = wall,
        normal = n,
        topZ = ledge.z,
        bottomZ = groundZ,
        topStand = ledge,
        startAtTop = false,
    }
end

-- Caso B: el jugador está en un borde mirando al vacío → empieza arriba y baja.
local function detectFromTop(ped, pos, forward)
    local feetZ = groundBelow(pos, 3.0, ped)
    if not feetZ then return nil end

    -- Delante debe haber vacío (sin muro ni barandilla que lo impida).
    local chest = vector3(pos.x, pos.y, feetZ + 0.5)
    if raycast(chest, chest + forward * (cfg.EdgeProbeDistance + 0.5), ped) then return nil end

    -- Comprobar la pared justo bajo el borde: rayos desde fuera hacia el edificio a dos
    -- alturas. Solo vale una pared que dé hacia donde mira el jugador y esté pegada al borde
    -- (evita anclarse a farolas, semáforos o fachadas lejanas).
    local wall, normal
    for _, depth in ipairs({ 1.5, 3.0 }) do
        local outside = pos + forward * (cfg.EdgeProbeDistance + 2.0)
        outside = vector3(outside.x, outside.y, feetZ - depth)
        local hit, hitPos, hitNormal = raycast(outside, outside - forward * 4.5, ped)
        if not hit or not isVertical(hitNormal) then return nil, Config.Text.NoSurface end
        local n = horizontal(hitNormal)
        local facing = n.x * forward.x + n.y * forward.y
        local gap = #(vector3(hitPos.x, hitPos.y, 0.0) - vector3(pos.x, pos.y, 0.0))
        if facing < cfg.MinWallFacing or gap > cfg.MaxEdgeGap then
            return nil, Config.Text.NoSurface
        end
        if not wall then wall, normal = hitPos, n end
    end

    -- Suelo justo debajo de donde colgará la cuerda (no delante del jugador).
    local ropePoint = wall + normal * Config.Movement.WallOffset
    local dropStart = vector3(ropePoint.x, ropePoint.y, feetZ - 1.0)
    local dropHit, dropGround = raycast(dropStart, dropStart - vector3(0.0, 0.0, cfg.MaxHeight), ped)
    if not dropHit then return nil, Config.Text.NoSurface end
    if feetZ - dropGround.z < cfg.MinHeight then return nil, Config.Text.TooLow end

    return {
        wall = wall,
        normal = normal,
        topZ = feetZ,
        bottomZ = dropGround.z,
        topStand = vector3(pos.x, pos.y, feetZ),
        startAtTop = true,
    }
end

-- Devuelve (datos, nil) si la superficie es válida, o (nil, mensaje) si no.
function Detection.Find(ped)
    local pos = GetEntityCoords(ped)
    local forward = horizontal(GetEntityForwardVector(ped))

    local result, bottomErr = detectFromBottom(ped, pos, forward)
    if result then return result end

    local topErr
    result, topErr = detectFromTop(ped, pos, forward)
    if result then return result end
    return nil, bottomErr or topErr or Config.Text.NoSurface
end

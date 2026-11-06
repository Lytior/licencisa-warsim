-- Seguimiento de la superficie durante el rappel.
-- El personaje se mueve en el plano vertical que pasa por el anclaje con normal "lateral".
-- Su posicion queda definida por la altura z en la cuerda: la profundidad (distancia horizontal
-- desde el anclaje hacia fuera) se obtiene por raycast. Asi el cliente local y los remotos
-- reconstruyen la misma posicion a partir de un unico numero (z).
SurfaceTracker = {}
SurfaceTracker.__index = SurfaceTracker

function SurfaceTracker.new(anchor, n0, depth, normal, ignore)
    local n0h = U.horiz(n0) or vector3(0.0, 1.0, 0.0)
    local o = setmetatable({}, SurfaceTracker)
    o.anchor = anchor
    o.n0h = n0h
    o.lat = vector3(-n0h.y, n0h.x, 0.0)
    o.depth = depth or 0.0
    o.normal = normal and U.norm(normal) or n0h
    o.ignore = ignore
    o.lastZ = nil
    return o
end

function SurfaceTracker:basePoint(depth, z)
    local a = self.anchor
    return vector3(a.x + self.n0h.x * depth, a.y + self.n0h.y * depth, z)
end

-- Varios rayos a distintas alturas/laterales, decision por mayoria y media sin atipicos.
function SurfaceTracker:sample(z, depthHint)
    local cfg = Config.Surface
    local hits = {}
    local d0 = (depthHint or self.depth) + cfg.ProbeStart
    for i = 1, #cfg.Probes do
        local off = cfg.Probes[i]
        local o = self:basePoint(d0, z + off[1]) + self.lat * off[2]
        local pos, n = U.ray(o, o - self.n0h * (cfg.ProbeStart + cfg.ProbeReach), self.ignore)
        if pos and U.dot(n, self.n0h) > cfg.MinFacing then
            hits[#hits + 1] = { d = U.dot(pos - self.anchor, self.n0h), n = n }
        end
    end
    if #hits < cfg.MinHits then return nil end
    table.sort(hits, function(a, b) return a.d < b.d end)
    local med = hits[math.ceil(#hits / 2)].d
    local sumD, sumN, c = 0.0, vector3(0.0, 0.0, 0.0), 0
    for i = 1, #hits do
        local h = hits[i]
        if math.abs(h.d - med) <= cfg.OutlierDist then
            sumD = sumD + h.d; sumN = sumN + h.n; c = c + 1
        end
    end
    if c < cfg.MinHits then return nil end
    return sumD / c, U.norm(sumN / c)
end

-- Avanza el tracker por pasos (para jugadores remotos que llegan tarde o saltos grandes).
function SurfaceTracker:warmTo(zFrom, zTo)
    local step = zTo > zFrom and 1.0 or -1.0
    local z = zFrom
    for _ = 1, 400 do
        if (step > 0 and z >= zTo) or (step < 0 and z <= zTo) then break end
        z = z + step
        local d, n = self:sample(z)
        if d then self.depth = d; self.normal = n end
    end
    local d, n = self:sample(zTo)
    if d then self.depth = d; self.normal = n end
    self.lastZ = zTo
end

-- Devuelve: posicion del root del ped, punto de contacto, normal suavizada.
function SurfaceTracker:update(z, dt)
    local cfg = Config.Surface
    if self.lastZ and math.abs(z - self.lastZ) > 3.0 then self:warmTo(self.lastZ, z) end
    dt = math.max(dt, 0.001)

    -- Prediccion segun la pendiente actual (evita retraso en laderas a alta velocidad)
    if self.lastZ then
        local nh = U.dot(self.normal, self.n0h)
        if nh > 0.1 then
            local slope = U.clamp(-self.normal.z / nh, -cfg.MaxSlopeRatio, cfg.MaxSlopeRatio)
            self.depth = self.depth + slope * (z - self.lastZ)
        end
    end
    self.lastZ = z

    local d, n = self:sample(z)
    if d then
        local diff = d - self.depth
        if math.abs(diff) > cfg.DepthDeadZone then
            local k = 1.0 - math.exp(-cfg.DepthSmooth * dt)
            self.depth = U.approach(self.depth, self.depth + diff * k, cfg.MaxDepthSpeed * dt)
        end
        local ang = U.angleDeg(self.normal, n)
        if ang > cfg.NormalDeadZoneDeg then
            local k = 1.0 - math.exp(-cfg.NormalSmooth * dt)
            local maxK = (cfg.MaxNormalDegPerSec * dt) / ang
            self.normal = U.norm(U.lerp(self.normal, n, math.min(k, maxK, 1.0)))
        end
    end
    -- Sin mayoria (ventana, hueco): se mantienen los ultimos valores, sin tirones.

    local base = self:basePoint(self.depth, z)
    return base + self.normal * Config.Pose.BodyOffset, base, self.normal
end

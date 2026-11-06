Validation = {}

local function isVec(v) return type(v) == 'vector3' end
local function isNum(n) return type(n) == 'number' and n == n and n > -1e5 and n < 1e5 end

Validation.oneSync = GetConvar('onesync', 'off') ~= 'off'

function Validation.start(src, d)
    if type(d) ~= 'table' then return false end
    if not (isVec(d.anchor) and isVec(d.n0) and isVec(d.wallNormal)) then return false end
    if not (isNum(d.depth0) and isNum(d.z0) and isNum(d.topZ) and isNum(d.wallZ)) then return false end
    if Validation.oneSync then
        local ped = GetPlayerPed(src)
        if ped == 0 then return false end
        if #(GetEntityCoords(ped) - d.anchor) > Config.Detect.MaxSearchHeight + 30.0 then return false end
    end
    d.hasEdge = d.hasEdge == true
    return true
end

local buckets = {}

function Validation.rate(src)
    local now = os.time()
    local b = buckets[src]
    if not b or b.t ~= now then b = { t = now, n = 0 }; buckets[src] = b end
    b.n = b.n + 1
    return b.n <= Config.Net.MaxPerSecond
end

function Validation.update(a, s, z, v)
    if type(s) ~= 'number' or s < RState.IDLE or s > RState.EXIT then return false end
    if not isNum(z) or not isNum(v) then return false end
    if z > a.data.topZ + 0.5 then return false end
    if math.abs(a.data.anchor.z - z) > 1000.0 then return false end
    return true
end

function Validation.clear(src) buckets[src] = nil end

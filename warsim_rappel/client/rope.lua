-- Cuerda visual. El servidor reparte a todos los clientes qué jugadores están en rappel y
-- dónde está su anclaje; cada cliente dibuja la cuerda solo si ese jugador está en su rango.
--
-- Física (como el mod de referencia): la cuerda va del anclaje a la mano izquierda del ped
-- y en cada fotograma se ajusta su longitud a la distancia real, recogiéndola al subir
-- (winding) y soltándola al bajar (unwinding).
-- Seguridad: la cuerda del jugador local se borra en cuanto acaba el rappel, ANTES de
-- devolverle la gravedad, para que nunca pueda tirar de él (ver stopRappel en main.lua).

Ropes = {}

local cfg = Config.Rope
local active = {} -- [serverId] = { anchor = vector3, rope, obj, winding }

local HAND_BONE = 36029 -- SKEL_L_Hand

local function setWinding(entry, mode)
    if entry.winding == mode then return end
    local rope = entry.rope
    if entry.winding == 'in' then StopRopeWinding(rope) end
    if entry.winding == 'out' then StopRopeUnwindingFront(rope) end
    if mode == 'in' then StartRopeWinding(rope) end
    if mode == 'out' then StartRopeUnwindingFront(rope) end
    entry.winding = mode
end

local function destroy(entry)
    if entry.rope then
        DeleteRope(entry.rope)
        entry.rope = nil
    end
    if entry.obj and DoesEntityExist(entry.obj) then
        DeleteEntity(entry.obj)
    end
    entry.obj, entry.winding = nil, nil
end

local function handPos(ped)
    return GetPedBoneCoords(ped, HAND_BONE, 0.0, 0.0, 0.0)
end

local function create(entry, ped)
    local model = cfg.AnchorModel
    RequestModel(model)
    RopeLoadTextures()
    local t = GetGameTimer()
    while (not HasModelLoaded(model) or not RopeAreTexturesLoaded()) and GetGameTimer() - t < 4000 do
        Wait(0)
    end
    if not HasModelLoaded(model) or not RopeAreTexturesLoaded() or not DoesEntityExist(ped) then
        return
    end

    local a = entry.anchor
    local obj = CreateObjectNoOffset(model, a.x, a.y, a.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(obj, true)
    SetEntityVisible(obj, false, false)
    SetEntityCollision(obj, false, false)

    local p = handPos(ped)
    local length = math.max(#(a - p), cfg.MinLength)
    -- ADD_ROPE(pos, rot, maxLength, ropeType, initLength, minLength, lengthChangeRate,
    --          ppuOnly, collisionOn, lockFromFront, timeMultiplier, breakable, unk)
    -- lengthChangeRate antes era 1 m/s: la cuerda no podía seguir al jugador al subir.
    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, Config.Detection.MaxHeight + 5.0, cfg.Type,
        length, cfg.MinLength, cfg.ChangeRate, false, cfg.Collision, false, 1.0, false, 0)
    if not rope or rope == 0 then
        DeleteEntity(obj)
        return
    end
    ActivatePhysics(rope)
    AttachEntitiesToRope(rope, obj, ped, a.x, a.y, a.z, p.x, p.y, p.z, length, false, false, nil, nil)

    entry.obj, entry.rope = obj, rope
end

-- Ajusta la longitud de la cuerda a la distancia anclaje → mano en este fotograma.
local function follow(entry, ped)
    local target = math.max(#(entry.anchor - handPos(ped)), cfg.MinLength)
    local current = RopeGetDistanceBetweenEnds(entry.rope)
    if target < current - 0.05 then
        setWinding(entry, 'in')
    elseif target > current + 0.05 then
        setWinding(entry, 'out')
    else
        setWinding(entry, nil)
    end
    RopeForceLength(entry.rope, target)
end

function Ropes.Add(serverId, anchor)
    if not cfg.Enabled then return end
    if active[serverId] then destroy(active[serverId]) end
    active[serverId] = { anchor = anchor }
end

function Ropes.Remove(serverId)
    local entry = active[serverId]
    if not entry then return end
    destroy(entry)
    active[serverId] = nil
end

-- Crea/destruye cuerdas según el jugador entre o salga de rango y las mantiene a la
-- longitud correcta cada fotograma.
CreateThread(function()
    while true do
        local sleep = 1000
        -- Copia de la tabla: create() cede el hilo y los eventos pueden modificarla mientras.
        local snapshot = {}
        for serverId, entry in pairs(active) do snapshot[serverId] = entry end

        for serverId, entry in pairs(snapshot) do
            local player = GetPlayerFromServerId(serverId)
            local ped = player ~= -1 and GetPlayerPed(player) or 0
            if ped ~= 0 and DoesEntityExist(ped) then
                if not entry.rope then
                    create(entry, ped)
                    -- Si se quitó mientras se cargaba, limpiar lo recién creado.
                    if active[serverId] ~= entry then destroy(entry) end
                end
                if entry.rope then
                    follow(entry, ped)
                    sleep = 0
                else
                    sleep = math.min(sleep, 100) -- reintentar pronto si no se pudo crear
                end
            elseif entry.rope then
                destroy(entry)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('warsim_rappel:ropeStart', function(serverId, anchor)
    Ropes.Add(serverId, anchor)
end)

RegisterNetEvent('warsim_rappel:ropeStop', function(serverId)
    Ropes.Remove(serverId)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, entry in pairs(active) do destroy(entry) end
end)

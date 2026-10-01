-- Cuerda visual. El servidor reparte a todos los clientes qué jugadores están en rappel y
-- dónde está su anclaje; cada cliente dibuja la cuerda solo si ese jugador está en su rango.
--
-- La cuerda NO se engancha al ped: va de un objeto invisible en el borde a otro objeto
-- invisible pegado a la mano izquierda. Una cuerda con física tira de lo que lleva
-- enganchado; enganchada al ped podía lanzarlo fuera del mapa al subir a la cornisa.

Ropes = {}

local active = {} -- [serverId] = { anchor = vector3, rope, obj, hand }

local HAND_BONE = 36029 -- SKEL_L_Hand

local function deleteEntity(ent)
    if ent and DoesEntityExist(ent) then
        DetachEntity(ent, false, false)
        DeleteEntity(ent)
    end
end

local function destroy(entry)
    if entry.rope then
        DeleteRope(entry.rope)
        entry.rope = nil
    end
    deleteEntity(entry.obj)
    deleteEntity(entry.hand)
    entry.obj, entry.hand = nil, nil
end

local function spawnHidden(model, pos)
    local obj = CreateObjectNoOffset(model, pos.x, pos.y, pos.z, false, false, false)
    SetEntityVisible(obj, false, false)
    SetEntityCollision(obj, false, false)
    return obj
end

local function create(entry, ped)
    local model = Config.Rope.AnchorModel
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 2000 do Wait(0) end
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() and GetGameTimer() - t < 4000 do Wait(0) end
    if not HasModelLoaded(model) or not DoesEntityExist(ped) then return end

    local a = entry.anchor
    local obj = spawnHidden(model, a)
    FreezeEntityPosition(obj, true)

    -- Objeto pegado a la mano: es el otro extremo de la cuerda. Al ir enganchado al hueso
    -- no tiene física propia y la cuerda no puede empujar al ped a través de él.
    local p = GetPedBoneCoords(ped, HAND_BONE, 0.0, 0.0, 0.0)
    local hand = spawnHidden(model, p)
    AttachEntityToEntity(hand, ped, GetPedBoneIndex(ped, HAND_BONE), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)

    local length = #(a - p)
    -- ADD_ROPE(pos, rot, maxLength, ropeType, initLength, minLength, lengthChangeRate,
    --          ppuOnly, collisionOn, lockFromFront, timeMultiplier, breakable, unk)
    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, Config.Detection.MaxHeight + 5.0, Config.Rope.Type,
        length, 0.5, 1.0, false, Config.Rope.Collision, false, 1.0, false, 0)
    ActivatePhysics(rope)
    AttachEntitiesToRope(rope, obj, hand, a.x, a.y, a.z, p.x, p.y, p.z, length, false, false, nil, nil)

    entry.obj, entry.hand, entry.rope = obj, hand, rope
end

function Ropes.Add(serverId, anchor)
    if not Config.Rope.Enabled then return end
    if active[serverId] then destroy(active[serverId]) end
    active[serverId] = { anchor = anchor }
end

function Ropes.Remove(serverId)
    local entry = active[serverId]
    if not entry then return end
    destroy(entry)
    active[serverId] = nil
end

-- Crea/destruye cuerdas según el jugador entre o salga de rango y ajusta su longitud.
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
                if entry.rope and entry.hand and DoesEntityExist(entry.hand) then
                    RopeForceLength(entry.rope, #(entry.anchor - GetEntityCoords(entry.hand)))
                    sleep = 0
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

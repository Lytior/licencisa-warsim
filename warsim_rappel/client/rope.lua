-- Cuerda visual. El servidor reparte a todos los clientes qué jugadores están en rappel y
-- dónde está su anclaje; cada cliente dibuja la cuerda solo si ese jugador está en su rango.

Ropes = {}

local active = {} -- [serverId] = { anchor = vector3, rope = int?, obj = int? }

local function destroy(entry)
    if entry.rope then
        DeleteRope(entry.rope)
        entry.rope = nil
    end
    if entry.obj and DoesEntityExist(entry.obj) then
        DeleteEntity(entry.obj)
    end
    entry.obj = nil
end

local function create(entry, ped)
    local model = Config.Rope.AnchorModel
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 2000 do Wait(0) end
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() and GetGameTimer() - t < 4000 do Wait(0) end
    if not HasModelLoaded(model) then return end

    local a = entry.anchor
    local obj = CreateObjectNoOffset(model, a.x, a.y, a.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(obj, true)
    SetEntityVisible(obj, false, false)
    SetEntityCollision(obj, false, false)

    local p = GetEntityCoords(ped)
    local length = #(a - p)
    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, length, Config.Rope.Type,
        Config.Detection.MaxHeight + 5.0, 0.5, 1.0, false, false, false, 1.0, false, 0)
    AttachEntitiesToRope(rope, obj, ped, a.x, a.y, a.z, p.x, p.y, p.z, length, false, false, nil, nil)

    entry.obj = obj
    entry.rope = rope
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
                if entry.rope then
                    RopeForceLength(entry.rope, #(entry.anchor - GetEntityCoords(ped)))
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

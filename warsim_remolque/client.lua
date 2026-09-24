local remolquesHash = {}
local permitidosHash = {}
local miRemolque = nil

for _, m in ipairs(Config.Remolques) do remolquesHash[joaat(m)] = true end
for _, m in ipairs(Config.VehiculosPermitidos) do permitidosHash[joaat(m)] = true end

local function aviso(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end
RegisterNetEvent('warsim_remolque:aviso', aviso)

local function esRemolque(veh)
    return remolquesHash[GetEntityModel(veh)] == true
end

local function puedeEnganchar(veh)
    return Config.PermitirTodos or permitidosHash[GetEntityModel(veh)] == true
end

local function cargarModelo(modelo)
    local hash = joaat(modelo)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local limite = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > limite then return nil end
        Wait(0)
    end
    return hash
end

-- Remolque enganchado de forma "rigida" (fallback para vehiculos sin punto de enganche)
local function remolqueRigido(veh)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if esRemolque(v) and IsEntityAttachedToEntity(v, veh) then return v end
    end
    return nil
end

local function buscarRemolqueCercano(veh)
    local vMin = GetModelDimensions(GetEntityModel(veh))
    local trasera = GetOffsetFromEntityInWorldCoords(veh, 0.0, vMin.y, 0.0)
    local mejor, mejorDist = nil, Config.DistanciaEnganche

    for _, v in ipairs(GetGamePool('CVehicle')) do
        if v ~= veh and esRemolque(v) and not IsEntityAttached(v) then
            local _, tMax = GetModelDimensions(GetEntityModel(v))
            local morro = GetOffsetFromEntityInWorldCoords(v, 0.0, tMax.y, 0.0)
            local dist = #(trasera - morro)
            if dist < mejorDist then
                mejor, mejorDist = v, dist
            end
        end
    end
    return mejor
end

local function controlarRed(ent)
    NetworkRequestControlOfEntity(ent)
    local limite = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < limite do
        NetworkRequestControlOfEntity(ent)
        Wait(0)
    end
end

local function enganchar(veh, remolque)
    controlarRed(remolque)
    AttachVehicleToTrailer(veh, remolque, 1.1)
    Wait(250)
    if IsVehicleAttachedToTrailer(veh) then
        aviso('~g~Remolque enganchado.')
        return
    end

    -- Algunos vehiculos no tienen punto de enganche: lo pegamos detras "a mano"
    local vMin = GetModelDimensions(GetEntityModel(veh))
    local tMin, tMax = GetModelDimensions(GetEntityModel(remolque))
    local offY = vMin.y - tMax.y - 0.2
    local offZ = vMin.z - tMin.z
    AttachEntityToEntity(remolque, veh, 0, 0.0, offY, offZ, 0.0, 0.0, 0.0, false, false, true, false, 2, true)
    aviso('~g~Remolque enganchado.')
end

local function desenganchar(veh)
    if IsVehicleAttachedToTrailer(veh) then
        DetachVehicleFromTrailer(veh)
        aviso('~y~Remolque desenganchado.')
        return true
    end
    local rigido = remolqueRigido(veh)
    if rigido then
        controlarRed(rigido)
        DetachEntity(rigido, true, true)
        SetVehicleOnGroundProperly(rigido)
        aviso('~y~Remolque desenganchado.')
        return true
    end
    return false
end

RegisterCommand('+warsim_enganchar', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    if desenganchar(veh) then return end

    if not puedeEnganchar(veh) then
        aviso('~r~Este vehiculo no puede llevar el remolque.')
        return
    end

    local remolque = buscarRemolqueCercano(veh)
    if not remolque then
        aviso('~r~No hay ningun remolque detras. Da marcha atras hasta el enganche.')
        return
    end
    enganchar(veh, remolque)
end, false)
RegisterCommand('-warsim_enganchar', function() end, false)
RegisterKeyMapping('+warsim_enganchar', 'Enganchar / desenganchar remolque de artilleria', 'keyboard', Config.Tecla)

-- Impide que GTA enganche el remolque solo (marcha atras) a vehiculos no permitidos
CreateThread(function()
    while true do
        local espera = 1000
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 and not Config.PermitirTodos and not puedeEnganchar(veh) then
            espera = 250
            local ok, trailer = GetVehicleTrailerVehicle(veh)
            if ok and trailer ~= 0 and esRemolque(trailer) then
                DetachVehicleFromTrailer(veh)
                aviso('~r~Este vehiculo no puede llevar el remolque.')
            end
        end
        Wait(espera)
    end
end)

RegisterNetEvent('warsim_remolque:spawn', function()
    local ped = PlayerPedId()
    local hash = cargarModelo(Config.ModeloSpawn)
    if not hash then
        aviso('~r~No se pudo cargar el modelo ' .. Config.ModeloSpawn)
        return
    end

    if miRemolque and DoesEntityExist(miRemolque) then
        SetEntityAsMissionEntity(miRemolque, true, true)
        DeleteVehicle(miRemolque)
    end

    local base = GetVehiclePedIsIn(ped, false)
    if base == 0 then base = ped end
    local pos = GetOffsetFromEntityInWorldCoords(base, 0.0, -7.0, 0.5)
    local heading = GetEntityHeading(base)

    miRemolque = CreateVehicle(hash, pos.x, pos.y, pos.z, heading, true, false)
    SetVehicleOnGroundProperly(miRemolque)
    SetEntityAsMissionEntity(miRemolque, true, true)
    SetVehicleHasBeenOwnedByPlayer(miRemolque, true)
    SetModelAsNoLongerNeeded(hash)
    aviso('~g~Remolque de artilleria creado detras de ti.')
end)

RegisterNetEvent('warsim_remolque:borrar', function()
    if miRemolque and DoesEntityExist(miRemolque) then
        SetEntityAsMissionEntity(miRemolque, true, true)
        DeleteVehicle(miRemolque)
        miRemolque = nil
        aviso('~y~Remolque borrado.')
    else
        aviso('~r~No tienes ningun remolque creado.')
    end
end)

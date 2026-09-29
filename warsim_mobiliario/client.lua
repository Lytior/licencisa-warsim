local sillasHash = {}
local camasHash = {}
for modelo, d in pairs(Config.Sillas) do sillasHash[joaat(modelo)] = d end
for modelo, d in pairs(Config.Camas) do camasHash[joaat(modelo)] = d end

local cercano = nil -- { obj, tipo, datos } mueble libre mas cercano
local uso = nil     -- { obj, tipo, clave, inicio, posAntes, heridas, vidaLlena } mueble en uso
local respuestas = {}

-- Icono de la tecla que tenga asignada el jugador (respeta el cambio en Ajustes)
local COMANDO = '+warsim_mobiliario'
local iconoTecla = ('~INPUT_%X~'):format((joaat(COMANDO) & 0xFFFFFFFF) | 0x80000000)

local function texto(clave)
    return (Config.Texto[clave]:gsub('{tecla}', iconoTecla))
end

local function aviso(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

local function ayuda(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function cargarDict(dict)
    RequestAnimDict(dict)
    local limite = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > limite then return false end
        Wait(0)
    end
    return true
end

-- Los props del mapa no tienen id de red: se identifican por su posicion
local function claveMueble(obj)
    local c = GetEntityCoords(obj)
    return ('%.1f:%.1f:%.1f'):format(c.x, c.y, c.z)
end

-- Pregunta al servidor si el mueble esta libre y lo reserva
local function reservar(clave)
    respuestas[clave] = nil
    TriggerServerEvent('warsim_mobiliario:ocupar', clave)
    local limite = GetGameTimer() + 2000
    while respuestas[clave] == nil and GetGameTimer() < limite do Wait(0) end
    local ok = respuestas[clave] == true
    respuestas[clave] = nil
    return ok
end

RegisterNetEvent('warsim_mobiliario:respuesta', function(clave, ok)
    respuestas[clave] = ok
end)

local function puedeUsar(ped)
    return not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, true) and not IsPedRagdoll(ped)
        and not IsPedFalling(ped) and not IsPedSwimming(ped) and not IsPedCuffed(ped)
end

---------------------------------------------------------------------------
-- Heridas
---------------------------------------------------------------------------
local function curarHeridas(ped)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedLastWeaponDamage(ped)
    for _, e in ipairs(Config.EventosHeridas) do
        TriggerEvent(e.evento, table.unpack(e.args or {}))
    end
    TriggerEvent('warsim_mobiliario:heridasCuradas')
    aviso(texto('HeridasCuradas'))
end

---------------------------------------------------------------------------
-- Sentarse / tumbarse / levantarse
---------------------------------------------------------------------------
local function sentarse(ped, obj, d)
    local pos = GetOffsetFromEntityInWorldCoords(obj, 0.0, d.atras or 0.0, d.z)
    TaskStartScenarioAtPosition(ped, Config.EscenarioSilla, pos.x, pos.y, pos.z,
        GetEntityHeading(obj) + d.heading, 0, true, true)
end

local function tumbarse(ped, obj, d)
    if not cargarDict(Config.AnimCama.dict) then return false end
    local pos = GetOffsetFromEntityInWorldCoords(obj, 0.0, d.atras or 0.0, d.z)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(obj) + d.heading)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, Config.AnimCama.dict, Config.AnimCama.name, 8.0, -8.0, -1, 1, 0, false, false, false)
    return true
end

local function usar(m)
    local ped = PlayerPedId()
    if not puedeUsar(ped) or not DoesEntityExist(m.obj) then return end

    local clave = claveMueble(m.obj)
    if not reservar(clave) then
        aviso(texto('Ocupado'))
        return
    end

    uso = {
        obj = m.obj, tipo = m.tipo, clave = clave, inicio = GetGameTimer(),
        posAntes = GetEntityCoords(ped), heridas = false, vidaLlena = false,
    }
    cercano = nil

    if m.tipo == 'silla' then
        sentarse(ped, m.obj, m.datos)
    elseif not tumbarse(ped, m.obj, m.datos) then
        uso = nil
        TriggerServerEvent('warsim_mobiliario:liberar')
    end
end

-- conAnimacion = false cuando hay que cortar de golpe (muerte, vehiculo, mueble borrado)
local function levantarse(conAnimacion)
    if not uso then return end
    local ped = PlayerPedId()
    local u = uso
    uso = nil

    if u.tipo == 'cama' then
        if Config.Cura.CurarAlLevantarse and not u.heridas and not IsEntityDead(ped) then
            curarHeridas(ped)
        end
        FreezeEntityPosition(ped, false)
        StopAnimTask(ped, Config.AnimCama.dict, Config.AnimCama.name, 2.0)
        if conAnimacion then
            -- Vuelve al sitio desde el que se tumbo, que sabemos que es suelo valido
            SetEntityCoords(ped, u.posAntes.x, u.posAntes.y, u.posAntes.z, false, false, false, false)
        end
    elseif conAnimacion then
        ClearPedTasks(ped) -- el scenario hace solo la animacion de levantarse
        CreateThread(function()
            Wait(2500)
            if not uso and IsPedUsingScenario(ped, Config.EscenarioSilla) then
                ClearPedTasksImmediately(ped)
            end
        end)
    else
        ClearPedTasksImmediately(ped)
    end

    TriggerServerEvent('warsim_mobiliario:liberar')
end

RegisterCommand(COMANDO, function()
    if uso then
        levantarse(true)
    elseif cercano then
        usar(cercano)
    end
end, false)
RegisterCommand('-warsim_mobiliario', function() end, false)
RegisterKeyMapping(COMANDO, 'Sentarse / tumbarse / levantarse', 'keyboard', Config.Tecla)

---------------------------------------------------------------------------
-- Busqueda de muebles cercanos
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local encontrado = nil
        local ped = PlayerPedId()
        if not uso and puedeUsar(ped) then
            local pos = GetEntityCoords(ped)
            local mejorDist = Config.Distancia
            for _, obj in ipairs(GetGamePool('CObject')) do
                local modelo = GetEntityModel(obj)
                local d, tipo = sillasHash[modelo], 'silla'
                if not d then d, tipo = camasHash[modelo], 'cama' end
                if d then
                    local dist = #(pos - GetEntityCoords(obj))
                    if dist < mejorDist then
                        encontrado, mejorDist = { obj = obj, tipo = tipo, datos = d }, dist
                    end
                end
            end
        end
        cercano = encontrado
        Wait(Config.IntervaloBusqueda)
    end
end)

-- Texto de ayuda
CreateThread(function()
    while true do
        if uso then
            ayuda(texto('Levantarse'))
            Wait(0)
        elseif cercano then
            ayuda(texto(cercano.tipo == 'silla' and 'Sentarse' or 'Tumbarse'))
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---------------------------------------------------------------------------
-- Mientras se usa un mueble: vigilar y curar
---------------------------------------------------------------------------
CreateThread(function()
    local siguienteCura = 0
    while true do
        local espera = 500
        if uso then
            espera = 250
            local ped = PlayerPedId()
            local ahora = GetGameTimer()

            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, true) or not DoesEntityExist(uso.obj) then
                levantarse(false)
            elseif uso.tipo == 'silla' then
                -- Si algo saca al jugador del scenario (le empujan, cae...) se libera la silla
                if ahora - uso.inicio > 1500 and not IsPedUsingScenario(ped, Config.EscenarioSilla) then
                    levantarse(false)
                end
            else
                -- Un golpe puede cortar la animacion: se vuelve a poner
                if not IsEntityPlayingAnim(ped, Config.AnimCama.dict, Config.AnimCama.name, 3) then
                    TaskPlayAnim(ped, Config.AnimCama.dict, Config.AnimCama.name, 8.0, -8.0, -1, 1, 0, false, false, false)
                end

                if ahora >= siguienteCura then
                    siguienteCura = ahora + Config.Cura.Intervalo
                    local vida, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                    if vida < max then
                        SetEntityHealth(ped, math.min(max, vida + Config.Cura.VidaPorTick))
                    elseif not uso.vidaLlena then
                        uso.vidaLlena = true
                        aviso(texto('VidaLlena'))
                    end
                end

                if not uso.heridas and ahora - uso.inicio >= Config.Cura.TiempoHeridas * 1000 then
                    uso.heridas = true
                    curarHeridas(ped)
                end
            end
        end
        Wait(espera)
    end
end)

-- Si se para el recurso con alguien sentado/tumbado, no se queda congelado
AddEventHandler('onResourceStop', function(recurso)
    if recurso == GetCurrentResourceName() and uso then
        levantarse(false)
    end
end)

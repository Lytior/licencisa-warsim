-- Lleva la cuenta de que muebles estan ocupados para que dos jugadores no se sienten
-- en la misma silla ni se tumben en la misma cama.

local ocupados = {}   -- [clave] = src
local porJugador = {} -- [src] = clave

local function liberar(src)
    local clave = porJugador[src]
    if clave and ocupados[clave] == src then ocupados[clave] = nil end
    porJugador[src] = nil
end

RegisterNetEvent('warsim_mobiliario:ocupar', function(clave)
    local src = source
    if type(clave) ~= 'string' or #clave > 64 then return end

    local dueno = ocupados[clave]
    if dueno and dueno ~= src and GetPlayerPing(dueno) > 0 then
        TriggerClientEvent('warsim_mobiliario:respuesta', src, clave, false)
        return
    end

    liberar(src)
    ocupados[clave] = src
    porJugador[src] = clave
    TriggerClientEvent('warsim_mobiliario:respuesta', src, clave, true)
end)

RegisterNetEvent('warsim_mobiliario:liberar', function()
    liberar(source)
end)

AddEventHandler('playerDropped', function()
    liberar(source)
end)

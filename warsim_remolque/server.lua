local function tienePermiso(src)
    return not Config.UsarPermisos or IsPlayerAceAllowed(src, 'warsim.remolque')
end

RegisterCommand(Config.ComandoSpawn, function(src)
    if src == 0 then return end
    if not tienePermiso(src) then
        TriggerClientEvent('warsim_remolque:aviso', src, '~r~No tienes permiso para sacar el remolque.')
        return
    end
    TriggerClientEvent('warsim_remolque:spawn', src)
end, false)

RegisterCommand(Config.ComandoBorrar, function(src)
    if src == 0 then return end
    if not tienePermiso(src) then
        TriggerClientEvent('warsim_remolque:aviso', src, '~r~No tienes permiso.')
        return
    end
    TriggerClientEvent('warsim_remolque:borrar', src)
end, false)

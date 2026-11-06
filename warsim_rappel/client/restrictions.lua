-- Mientras se cuelga: sin armas ni inventario.
Restrictions = {}

local UNARMED = `WEAPON_UNARMED`
local lastMenuCheck = 0

function Restrictions.begin(ped)
    SetCurrentPedWeapon(ped, UNARMED, true)
    SetPedCanSwitchWeapon(ped, false)
    LocalPlayer.state:set('invBusy', true, true)
end

function Restrictions.tick(ped)
    DisablePlayerFiring(PlayerId(), true)
    for i = 1, #Config.DisabledControls do
        DisableControlAction(0, Config.DisabledControls[i], true)
    end
    HudWeaponWheelIgnoreSelection()
    if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end

    local now = GetGameTimer()
    if now - lastMenuCheck > 250 then
        lastMenuCheck = now
        if ESX and ESX.UI and ESX.UI.Menu then
            if ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory')
                or ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory_item') then
                ESX.UI.Menu.CloseAll()
            end
        end
    end
end

function Restrictions.finish(ped)
    SetPedCanSwitchWeapon(ped, true)
    LocalPlayer.state:set('invBusy', false, true)
end

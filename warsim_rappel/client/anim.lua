-- Reproduce animaciones por clave logica (ver shared/animations.lua). Desacoplado de los nombres reales.
Anim = {}

local current = {}

CreateThread(function()
    local seen = {}
    for _, a in pairs(Animations.Clips) do
        if not seen[a.dict] then seen[a.dict] = true; U.loadDict(a.dict, 3000) end
    end
end)

local function start(ped, a)
    TaskPlayAnim(ped, a.dict, a.clip, a.blendIn or 4.0, a.blendOut or -4.0, a.duration or -1,
        a.flags or 1, 0.0, false, false, false)
    if a.rate then SetEntityAnimSpeed(ped, a.dict, a.clip, a.rate) end
end

function Anim.play(ped, key, force)
    local a = Animations.Clips[key]
    if not a then return end
    if current[ped] == key and not force then
        -- Mantener loops vivos si algo los corta
        if (a.flags or 1) & 1 == 1 and HasAnimDictLoaded(a.dict)
            and not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then
            start(ped, a)
        end
        return
    end
    current[ped] = key
    if not U.loadDict(a.dict, 50) then return end -- si no existe se omite sin romper nada
    start(ped, a)
end

function Anim.playState(ped, state, force)
    local key = Animations.ForState[state]
    if key then Anim.play(ped, key, force) end
end

function Anim.stop(ped)
    local key = current[ped]
    local a = key and Animations.Clips[key]
    if a then StopAnimTask(ped, a.dict, a.clip, 8.0) end
    current[ped] = nil
end

function Anim.forget(ped) current[ped] = nil end

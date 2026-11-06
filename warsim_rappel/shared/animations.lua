-- UNICO punto a modificar para cambiar animaciones.
-- Para usar clips propios de Blender: meter el .ycd en stream/ (p.ej. stream/warsim_rappel@anims.ycd)
-- y cambiar aqui dict/clip. El codigo no conoce ningun nombre de animacion.
--
-- flags: 1 = loop, 2 = mantener ultimo frame, 0 = una vez.
Animations = {}

Animations.Clips = {
    anchor  = { dict = 'clothingtie', clip = 'try_tie_positive_a', flags = 0,  blendIn = 4.0, blendOut = -4.0 },
    hook    = { dict = 'missrappel',  clip = 'rappel_idle',        flags = 1,  blendIn = 2.0, blendOut = -2.0 },
    stopped = { dict = 'missrappel',  clip = 'rappel_idle',        flags = 1,  blendIn = 3.0, blendOut = -3.0 },
    descend = { dict = 'missrappel',  clip = 'rappel_walk',        flags = 1,  blendIn = 3.0, blendOut = -3.0, rate = 1.0 },
    ascend  = { dict = 'missrappel',  clip = 'rappel_walk',        flags = 1,  blendIn = 3.0, blendOut = -3.0, rate = 0.7 },
    impulse = { dict = 'missrappel',  clip = 'rappel_jump_a',      flags = 2,  blendIn = 6.0, blendOut = -4.0 },
    -- PROTOTIPO: verificar con un visor de anims; si no carga, se omite y el movimiento sigue igual.
    climb   = { dict = 'move_climb',  clip = 'standclimbup_80',    flags = 2,  blendIn = 4.0, blendOut = -4.0 },
    final   = { dict = 'clothingtie', clip = 'try_tie_positive_a', flags = 48, blendIn = 4.0, blendOut = -4.0 },
}

-- Estado -> clip
Animations.ForState = {
    [RState.ANCHORING] = 'anchor',
    [RState.HOOK]      = 'hook',
    [RState.STOPPED]   = 'stopped',
    [RState.ASCEND]    = 'ascend',
    [RState.DESCEND]   = 'descend',
    [RState.IMPULSE]   = 'impulse',
    [RState.TOP]       = 'stopped',
    [RState.BOTTOM]    = 'stopped',
    [RState.CLIMB]     = 'climb',
    [RState.EXIT]      = 'final',
}

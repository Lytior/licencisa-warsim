-- Estados de la maquina de rappel. Se envian por red como enteros.
RState = {
    IDLE      = 0,
    ANCHORING = 1,  -- gesto de colocarse el arnes
    HOOK      = 2,  -- enganchado: transicion a la pared
    STOPPED   = 3,  -- parado en la cuerda
    ASCEND    = 4,
    DESCEND   = 5,
    IMPULSE   = 6,  -- impulso con las piernas (Espacio)
    TOP       = 7,  -- arriba, esperando confirmacion (E)
    BOTTOM    = 8,  -- abajo, esperando confirmacion (E)
    CLIMB     = 9,  -- trepando el bordillo
    EXIT      = 10, -- final: saliendo de la cuerda
}

-- Mensajes de red (solo lo minimo):
--   remoteStart(src, { anchor, n0, wallNormal, depth0, z0, topZ, hasEdge })  una vez
--   remoteUpdate(src, state, z, v)   z = altura en la cuerda, v = velocidad vertical con signo
--   remoteStop(src)

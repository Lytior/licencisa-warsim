Config = {}

-- Escribe cada paso en la consola F8 (cliente) y en la del servidor. Poner en false en producción.
Config.Debug = true

-- Nombre interno del objeto de inventario (debe coincidir con el definido en sql/items.sql
-- o en ox_inventory). La compra/reparto lo gestiona la tienda de objetos existente.
Config.ItemName = 'cuerda_arnes'

-- Segundos que el servidor espera la confirmación del cliente tras usar el objeto.
Config.ConfirmTimeout = 15

---------------------------------------------------------------------------
-- Detección de superficie (raycast)
---------------------------------------------------------------------------
Config.Detection = {
    -- Altura mínima (m) entre suelo inferior y borde superior para permitir rappel.
    MinHeight = 4.0,
    -- Altura máxima (m) que se escanea.
    MaxHeight = 80.0,
    -- Inclinación máxima (grados) respecto a la vertical para considerar la pared apta.
    MaxWallTilt = 20.0,
    -- Distancia máxima (m) a la pared cuando el jugador está abajo mirando a ella.
    WallProbeDistance = 1.5,
    -- Distancia (m) hacia delante en la que se busca el vacío cuando el jugador está en un borde.
    EdgeProbeDistance = 1.2,
    -- Paso (m) del escaneo vertical al buscar el borde superior de la pared.
    ScanStep = 0.5,
    -- Profundidad (m) hacia dentro del edificio donde se busca la cornisa/azotea.
    LedgeInset = 0.8,
    -- Desde arriba: la pared bajo el borde debe estar a como mucho esta distancia (m)
    -- del jugador y mirar hacia fuera (1 = justo hacia donde mira el jugador).
    MaxEdgeGap = 2.0,
    MinWallFacing = 0.6,
    -- Flags del shape test: 1 = mundo, 16 = objetos (props/ymaps mapeados).
    Flags = 1 | 16,
}

---------------------------------------------------------------------------
-- Movimiento
---------------------------------------------------------------------------
Config.Movement = {
    AscendSpeed = 2.5,      -- m/s pulsando W
    DescendSpeed = 2.0,     -- m/s pulsando S
    WallOffset = 0.45,      -- separación (m) del jugador respecto a la pared
    PedRootOffset = 1.0,    -- altura del origen del ped sobre los pies
    TopHangDepth = 1.3,     -- cuánto por debajo del borde cuelga el jugador al empezar arriba
    ReleaseHeight = 1.0,    -- al bajar, se suelta la cuerda a esta altura del suelo y se cae solo
    KeyUp = 32,             -- INPUT_MOVE_UP_ONLY (W)
    KeyDown = 33,           -- INPUT_MOVE_DOWN_ONLY (S)

    -- Bajada rápida: mantener Shift mientras se baja con S.
    KeySlide = 21,          -- INPUT_SPRINT (Shift)
    SlideSpeed = 6.0,       -- m/s deslizándose

    -- Salto contra la pared: Espacio, parado o moviéndose.
    KeyJump = 22,           -- INPUT_JUMP (Espacio)
    JumpDrop = 3.0,         -- metros que baja en cada salto
    JumpOut = 0.9,          -- metros que se separa de la pared en el punto más alejado
    JumpTime = 900,         -- duración del salto (ms)

    -- F: arriba del todo sube a la cornisa; cerca del suelo (como mucho
    -- ManualReleaseHeight metros) se suelta de la cuerda.
    KeyRelease = 23,        -- INPUT_ENTER (F)
    ManualReleaseHeight = 3.0,
    -- Subir a la cornisa: 'place' coloca al jugador en un sitio comprobado de la azotea
    -- (recomendado); 'task' intenta antes la trepada del juego (TASK_CLIMB).
    ClimbMode = 'place',
    ClimbTimeout = 1500,    -- ms que se espera a que empiece a trepar (solo 'task')
    LedgeInsets = { 1.0, 1.5, 2.0, 0.6 }, -- distancias (m) tras la pared donde buscar suelo (no encima de un murete)
    HeadOffset = 0.8,       -- altura de la cabeza sobre el origen del ped (choques al subir)

    -- Con arma: tras dejar de apuntar/disparar, ms que se mantiene la pose de apuntar
    -- antes de volver a la postura de colgar (evita parpadeos entre ráfagas).
    AimHold = 700,
}

---------------------------------------------------------------------------
-- Boca abajo (PROTOTIPO): G estando parado. Sin animación propia se ve la postura de
-- colgar girada; para que parezca colgado de los pies hace falta una animación de Blender.
---------------------------------------------------------------------------
Config.Invert = {
    Enabled = true,
    Key = 47,                           -- INPUT_DETONATE (G)
    CarrierModel = `prop_golf_ball`,    -- objeto invisible al que se engancha para girarlo
    Rot = vector3(0.0, 180.0, 0.0),     -- 180° sobre el eje de delante: boca abajo mirando a la pared
    OffsetZ = 0.0,                      -- ajuste de altura al girarlo
}

---------------------------------------------------------------------------
-- Animaciones (flag: 1 = bucle, 2 = se queda en el último fotograma)
---------------------------------------------------------------------------
Config.Anims = {
    -- Enganche desde arriba: pasar el borde (la de las misiones de golpe).
    HookTop = { dict = 'mp_common_heist', name = 'rappel_intro', flag = 2, blend = 8.0, duration = 3000 },
    -- Enganche desde abajo.
    HookBottom = { dict = 'mini@repair', name = 'fixing_a_ped', flag = 1, duration = 2500 },
    -- Parado en la cuerda.
    Idle = { dict = 'missrappel', name = 'rappel_idle', flag = 2, blend = 4.0 },
    -- Subiendo/bajando: piernas caminando contra la pared.
    Move = { dict = 'missrappel', name = 'rappel_walk', flag = 1, blend = 7.0 },
    -- Bajada rápida (Shift + S).
    Slide = { dict = 'missrappel', name = 'rope_slide', flag = 1, blend = 5.0 },
    -- Salto contra la pared (Espacio).
    Jump = { dict = 'missrappel', name = 'rappel_jump_c', flag = 2, blend = 4.0 },
    -- Desenganche al llegar abajo.
    Dismount = { dict = 'missheistfbi3b_ig9', name = 'rappel_dismount_franklin', flag = 0, blend = 5.0 },
}

---------------------------------------------------------------------------
-- Cuerda visual (sincronizada con el resto de jugadores cercanos)
---------------------------------------------------------------------------
Config.Rope = {
    Enabled = true,
    Type = 4,               -- tipo de cuerda nativo (4 = cuerda fina)
    AnchorModel = `prop_golf_ball`, -- prop invisible que hace de punto de anclaje
    Collision = true,       -- la cuerda choca con edificios y objetos en vez de atravesarlos
}

Config.Text = {
    NoSurface = 'No hay una superficie apta para hacer rappel aquí.',
    TooLow = 'La altura es insuficiente para hacer rappel.',
    NoLedge = 'No se encuentra un punto de anclaje en la parte superior.',
    CantNow = 'No puedes usar la cuerda ahora mismo.',
    NoItem = 'No tienes una cuerda con arnés.',
    NoClimb = 'No hay dónde subir aquí.',
    HelpTop = '~INPUT_ENTER~ Subir a la cornisa  ~INPUT_MOVE_DOWN_ONLY~ Bajar',
    Help = '~INPUT_MOVE_UP_ONLY~ Subir  ~INPUT_MOVE_DOWN_ONLY~ Bajar  ~INPUT_SPRINT~ + ~INPUT_MOVE_DOWN_ONLY~ Deslizarse  ~INPUT_JUMP~ Saltar  ~INPUT_ENTER~ Soltarse (cerca del suelo)  ~INPUT_DETONATE~ Boca abajo',
}

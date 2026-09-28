Config = {}

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
    -- Flags del shape test: 1 = mundo, 16 = objetos (props/ymaps mapeados).
    Flags = 1 | 16,
}

---------------------------------------------------------------------------
-- Movimiento
---------------------------------------------------------------------------
Config.Movement = {
    AscendSpeed = 1.6,      -- m/s pulsando W
    DescendSpeed = 2.4,     -- m/s pulsando S
    WallOffset = 0.45,      -- separación (m) del jugador respecto a la pared
    PedRootOffset = 1.0,    -- altura del origen del ped sobre los pies
    TopHangDepth = 1.3,     -- cuánto por debajo del borde cuelga el jugador al empezar arriba
    KeyUp = 32,             -- INPUT_MOVE_UP_ONLY (W)
    KeyDown = 33,           -- INPUT_MOVE_DOWN_ONLY (S)
}

---------------------------------------------------------------------------
-- Animaciones (verificar en juego; se pueden cambiar sin tocar código)
---------------------------------------------------------------------------
Config.Anims = {
    Hook = { dict = 'mini@repair', name = 'fixing_a_ped', duration = 2500 },
    Idle = { dict = 'missrappel', name = 'rappel_idle' },
    Move = { dict = 'missrappel', name = 'rappel_walk' },
}

---------------------------------------------------------------------------
-- Cuerda visual (sincronizada con el resto de jugadores cercanos)
---------------------------------------------------------------------------
Config.Rope = {
    Enabled = true,
    Type = 4,               -- tipo de cuerda nativo (4 = cuerda fina)
    AnchorModel = `prop_golf_ball`, -- prop invisible que hace de punto de anclaje
}

Config.Text = {
    NoSurface = 'No hay una superficie apta para hacer rappel aquí.',
    TooLow = 'La altura es insuficiente para hacer rappel.',
    NoLedge = 'No se encuentra un punto de anclaje en la parte superior.',
    CantNow = 'No puedes usar la cuerda ahora mismo.',
    NoItem = 'No tienes una cuerda con arnés.',
    Help = '~INPUT_MOVE_UP_ONLY~ Subir  ~INPUT_MOVE_DOWN_ONLY~ Bajar',
}

Config = {}

Config.Item = 'cuerda_arnes'

-- Altura (m) del origen del ped sobre sus pies. GTA coloca el root ~1 m sobre el suelo.
Config.PedRootHeight = 1.0

-- Flags de raycast: 1 = mundo, 16 = objetos/props. Ignora peds y vehiculos.
Config.RayFlags = 1 + 16

-- Una superficie es "suelo" si la componente Z de su normal supera este valor.
Config.FloorNormalZ = 0.6

Config.Keys = {
    Up      = 32,  -- W
    Down    = 33,  -- S
    Impulse = 22,  -- Espacio
    Exit    = 38,  -- E
}

Config.Text = {
    NoSurface   = 'No hay ninguna superficie donde anclar la cuerda.',
    NoItem      = 'No tienes una cuerda con arnés.',
    Busy        = 'Ahora no puedes usar la cuerda.',
    NoGround    = 'No se detecta suelo seguro, sigue en la cuerda.',
    HelpBottom  = '~INPUT_CONTEXT~ Soltarse de la cuerda',
    HelpTop     = '~INPUT_CONTEXT~ Trepar al borde',
    HelpMove    = '~INPUT_MOVE_UP_ONLY~ Subir  ~INPUT_MOVE_DOWN_ONLY~ Bajar  ~INPUT_JUMP~ Impulso',
}

-- Deteccion inicial al usar el item
Config.Detect = {
    WallHeights      = { 0.2, 0.6, 1.0, 1.4, 1.8 }, -- alturas (sobre los pies) de los rayos hacia delante
    WallReach        = 1.6,   -- distancia maxima a la pared/ladera
    MaxWallNormalZ   = 0.75,  -- |normal.z| maxima: ~41 grados o mas de inclinacion = escalable
    MaxSearchHeight  = 150.0, -- si no se encuentra borde, se ancla a esta altura maxima
    MarchStep        = 0.5,
    MarchProbeOut    = 3.0,
    MarchProbeIn     = 3.5,
    EdgeMisses       = 3,     -- fallos seguidos para considerar que se acabo la pared (1.5 m)
    TopInward        = 0.3,   -- el anclaje queda este tramo hacia dentro del borde
    -- Inicio desde el borde de un tejado / caida
    EdgeProbeAhead   = 1.0,
    EdgeDropMin      = 3.0,
    EdgeWallDepths   = { 1.0, 1.5, 2.0, 2.5, 3.0 },
    EdgeBackProbe    = 2.2,
}

-- Seguimiento continuo de la superficie (anti-temblores)
Config.Surface = {
    -- { offset vertical, offset lateral } de cada rayo; se decide por mayoria
    Probes = {
        { 0.0, 0.0 }, { 0.45, 0.0 }, { -0.45, 0.0 }, { 0.0, 0.35 }, { 0.0, -0.35 },
    },
    MinHits            = 3,
    ProbeStart         = 3.0,
    ProbeReach         = 4.0,
    MinFacing          = 0.2,   -- la normal debe mirar hacia fuera de la pared
    OutlierDist        = 0.35,  -- salientes mas grandes que esto respecto a la mediana se ignoran
    DepthDeadZone      = 0.03,
    DepthSmooth        = 6.0,
    MaxDepthSpeed      = 1.2,   -- m/s de correccion maxima hacia/desde la pared
    MaxSlopeRatio      = 3.0,
    NormalDeadZoneDeg  = 2.0,
    NormalSmooth       = 5.0,
    MaxNormalDegPerSec = 70.0,
}

Config.Move = {
    UpSpeed            = 0.9,
    DownSpeed          = 1.6,
    Accel              = 4.0,
    MaxSpeed           = 6.0,   -- tope absoluto de descenso
    MinSpeed           = 0.4,
    BrakeDistance      = 5.0,   -- empieza a frenar a esta distancia del suelo
    BottomThreshold    = 0.08,
    ImpulseTime        = 0.65,
    ImpulseDrop        = 1.2,
    ImpulsePush        = 0.35,  -- separacion de la pared en el impulso
    ChainGain          = 0.35,
    MaxChain           = 6,
    ImpulseMinDrop     = 0.3,
    ImpulseGroundMargin= 1.0,
}

Config.Pose = {
    BodyOffset        = 0.85, -- distancia del root del ped a la pared
    BasePitch         = 0.0,  -- las anims de missrappel ya traen la inclinacion
    SlopePitchFactor  = 0.6,
    SlopePitchSign    = -1.0, -- invertir si en laderas el ped se inclina al reves
    HarnessForward    = 0.15,
    AttachTime        = 0.8,
    AnchorTime        = 2200, -- ms del gesto de anclarse
}

Config.Top = {
    HangBelowEdge = 1.1,  -- con borde: el root no sube mas de esto bajo el anclaje
    NoEdgeMargin  = 1.5,
    StandInward   = 0.7,
    ClimbTime     = 1.8,
}

Config.Exit = {
    BottomPushOut = 0.45,
    ProbeUp       = 1.5,  -- salida arriba
    BottomProbeUp = 0.3,  -- salida abajo
    ProbeDown     = 8.0,
    Margin        = 0.05,
    ConfirmFrames = 3,
    Timeout       = 5000,
    SafetyNetMs   = 2500,
    NetDrop       = 0.6,
    NetRadius     = 2.0,
}

Config.IK = {
    Enabled   = true,
    LeftArm   = 3,
    RightArm  = 4,
    GuideDist = 0.55,
    BrakeRight= 0.20,
    BrakeDown = 0.15,
}

Config.Rope = {
    UseNatives      = true,
    Type            = 4,
    MaxLength       = 400.0,
    MinLength       = 0.5,
    SlackLength     = 6.0,
    SlackPinDrop    = 0.2,
    Tension         = 0.98,
    LengthDeadZone  = 0.05,
    Smooth          = 18.0,  -- filtro paso bajo de los puntos de enganche (amortiguacion)
    -- Fallback: prop de 1 m de largo en +Z con origen en la base, se estira con la matriz
    PropModel       = `prop_cs_rope_tie_01`,
}

Config.Net = {
    MinInterval    = 100,  -- ms (10 Hz max)
    MinDeltaZ      = 0.02,
    Heartbeat      = 1000,
    InterpDelay    = 120,
    MaxExtrapolate = 250,
    RemoteSmooth   = 15.0,
    Range          = 250.0, -- servidor: a quien reenviar las actualizaciones
    RenderRange    = 200.0, -- cliente: a quien dibujar
    MaxPerSecond   = 20,
}

Config.DisabledControls = {
    14, 15, 16, 17, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 45,
    47, 58, 99, 100, 115, 116, 140, 141, 142, 143, 157, 158, 159, 160, 161, 162,
    163, 164, 165, 257, 263, 264, 289,
}

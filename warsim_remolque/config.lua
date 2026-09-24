Config = {}

-- Modelos de remolque que maneja el script.
-- 'trailersmall2' = Anti-Aircraft Trailer (el remolque de artilleria de Gunrunning)
Config.Remolques = {
    'trailersmall2',
}

-- Modelo que se crea con el comando de spawn
Config.ModeloSpawn = 'trailersmall2'

-- Vehiculos a los que SE PUEDE enganchar el remolque (nombre de spawn del modelo).
-- Añade o quita los que querais. Si un vehiculo no esta aqui, no podra engancharlo
-- (ni con la tecla ni marcha atras como hace GTA por defecto).
Config.VehiculosPermitidos = {
    'insurgent',
    'insurgent2',
    'insurgent3',
    'barracks',
    'barracks3',
    'crusader',
    'mesa3',
    'sandking',
    'sandking2',
    'kamacho',
    'halftrack',
    'nightshark',
    'menacer',
    'brickade',
    'dune3',
}

-- true = cualquier vehiculo puede engancharlo (ignora la lista de arriba)
Config.PermitirTodos = false

-- Distancia maxima (metros) entre la parte trasera del vehiculo y el morro del remolque
Config.DistanciaEnganche = 4.0

-- Tecla por defecto para enganchar / desenganchar (cada jugador la puede cambiar en
-- Ajustes > Asignacion de teclas > FiveM)
Config.Tecla = 'H'

-- Comandos
Config.ComandoSpawn = 'remolque'          -- crea el remolque detras de ti
Config.ComandoBorrar = 'borrarremolque'   -- borra el remolque que has creado

-- Permisos para /remolque y /borrarremolque (ACE: warsim.remolque)
-- En server.cfg:  add_ace group.admin warsim.remolque allow
Config.UsarPermisos = true

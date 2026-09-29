Config = {}

-- Tecla por defecto para sentarse/tumbarse y para levantarse (cada jugador la puede
-- cambiar en Ajustes > Asignacion de teclas > FiveM)
Config.Tecla = 'E'

-- Distancia maxima (metros) al mueble para poder usarlo
Config.Distancia = 1.8

-- Cada cuanto (ms) se buscan muebles cerca del jugador
Config.IntervaloBusqueda = 500

---------------------------------------------------------------------------
-- Sillas
---------------------------------------------------------------------------
-- Animacion de sentarse (scenario de GTA, se reproduce en bucle hasta levantarse)
Config.EscenarioSilla = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'

-- Modelos de silla. Por cada uno:
--   z       = altura del asiento sobre el origen del modelo
--   heading = giro que se suma al del mueble (180 = mirando hacia delante de la silla)
--   atras   = cuanto se mete el jugador hacia el respaldo (negativo = hacia atras)
-- Si un modelo nuevo sienta al jugador flotando o mirando al reves, ajusta estos valores.
Config.Sillas = {
    ['prop_chair_01a']          = { z = 0.5, heading = 180.0 },
    ['prop_chair_01b']          = { z = 0.5, heading = 180.0 },
    ['prop_chair_02']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_03']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_04a']          = { z = 0.5, heading = 180.0 },
    ['prop_chair_05']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_06']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_08']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_09']           = { z = 0.5, heading = 180.0 },
    ['prop_chair_10']           = { z = 0.5, heading = 180.0 },
    ['prop_chateau_chair_01']   = { z = 0.5, heading = 180.0 },
    ['prop_table_03_chr']       = { z = 0.5, heading = 180.0 },
    ['prop_table_04_chr']       = { z = 0.5, heading = 180.0 },
    ['prop_off_chair_01']       = { z = 0.5, heading = 180.0 },
    ['prop_off_chair_03']       = { z = 0.5, heading = 180.0 },
    ['prop_off_chair_04']       = { z = 0.5, heading = 180.0 },
    ['prop_off_chair_05']       = { z = 0.5, heading = 180.0 },
    ['v_corp_offchair']         = { z = 0.5, heading = 180.0 },
    ['v_club_officechair']      = { z = 0.5, heading = 180.0 },
    ['hei_prop_heist_off_chair']= { z = 0.5, heading = 180.0 },
    ['prop_skid_chair_01']      = { z = 0.5, heading = 180.0 },
    ['prop_skid_chair_02']      = { z = 0.5, heading = 180.0 },
    ['prop_skid_chair_03']      = { z = 0.5, heading = 180.0 },
    ['prop_bench_01a']          = { z = 0.5, heading = 180.0 },
    ['prop_bench_05']           = { z = 0.5, heading = 180.0 },
    ['prop_bench_09']           = { z = 0.5, heading = 180.0 },
    ['gr_prop_gr_chair02_01a']  = { z = 0.5, heading = 180.0 },
}

---------------------------------------------------------------------------
-- Camas
---------------------------------------------------------------------------
-- Animacion de tumbarse boca arriba (se reproduce en bucle hasta levantarse)
Config.AnimCama = { dict = 'anim@gangops@morgue@table@', name = 'body_search' }

-- Modelos de cama. Por cada uno:
--   z       = altura sobre el origen del modelo. La animacion ya tumba al personaje a la
--             altura de una camilla de hospital (~0,9 m), asi que en camas bajas (catres,
--             literas del bunker) hay que poner un valor negativo para que no flote.
--   heading = giro que se suma al del mueble (para que la cabeza quede en la almohada)
Config.Camas = {
    ['v_med_bed1']              = { z = 0.0, heading = 180.0 },
    ['v_med_bed2']              = { z = 0.0, heading = 180.0 },
    ['v_med_emptybed']          = { z = 0.0, heading = 180.0 },
    ['gr_prop_bunker_bed_01']   = { z = 0.0, heading = 180.0 },
    ['gr_prop_gr_campbed_01']   = { z = 0.0, heading = 180.0 },
    ['v_res_msonbed']           = { z = 0.0, heading = 180.0 },
    ['v_res_mbbed']             = { z = 0.0, heading = 180.0 },
    ['v_res_tre_bed1']          = { z = 0.0, heading = 180.0 },
    ['v_res_tre_bed2']          = { z = 0.0, heading = 180.0 },
    ['ex_prop_exec_bed_01']     = { z = 0.0, heading = 180.0 },
}

-- Curacion mientras el jugador esta tumbado
Config.Cura = {
    Intervalo = 1000,       -- cada cuantos ms se suma vida
    VidaPorTick = 5,        -- vida que se suma cada tick (la vida maxima de un ped MP es 200)
    TiempoHeridas = 10,     -- segundos tumbado para que se curen las heridas
    CurarAlLevantarse = false, -- true = al levantarse antes de tiempo tambien cura las heridas
}

-- Eventos de cliente que se lanzan al curar las heridas, para avisar al sistema de
-- heridas/ambulancia del servidor. Pon el que use vuestro servidor. Ejemplos:
--   'esx_ambulancejob:heal'             (con el argumento 'big')
--   'hospital:client:HealInjuries'      (qb-ambulancejob, con 'full')
--   'wasabi_ambulance:heal'
Config.EventosHeridas = {
    -- { evento = 'esx_ambulancejob:heal', args = { 'big', true } },
}

Config.Texto = {
    -- {tecla} se sustituye por la tecla que tenga asignada el jugador
    Sentarse = '{tecla} Sentarse',
    Tumbarse = '{tecla} Tumbarse',
    Levantarse = '{tecla} Levantarse',
    Ocupado = '~r~Ya hay alguien usando esto.',
    HeridasCuradas = '~g~Tus heridas se han curado.',
    VidaLlena = '~g~Estas completamente recuperado.',
}

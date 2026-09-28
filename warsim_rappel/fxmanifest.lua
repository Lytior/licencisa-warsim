fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'warsim_rappel'
description 'Operation Warsim - Sistema de rappel (cuerda con arnés)'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
}

client_scripts {
    'client/detection.lua',
    'client/rope.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependency 'es_extended'

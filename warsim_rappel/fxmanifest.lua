fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'warsim_rappel'
description 'Operation Warsim - sistema de rappel (ESX)'
version '2.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'shared/states.lua',
    'shared/animations.lua',
}

client_scripts {
    'client/util.lua',
    'client/anim.lua',
    'client/surface.lua',
    'client/detect.lua',
    'client/pose.lua',
    'client/rope.lua',
    'client/restrictions.lua',
    'client/exit.lua',
    'client/movement.lua',
    'client/main.lua',
    'client/remote.lua',
}

server_scripts {
    'server/validation.lua',
    'server/main.lua',
}

dependency 'es_extended'

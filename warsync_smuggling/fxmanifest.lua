fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'warsync_smuggling'
author 'WarSync - Operation Warsim'
description 'Civilian / Press contraband smuggling system (crafting table + contraband items)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/crafting.lua',
    'client/items.lua',
    'client/devices.lua',
    'client/tablet.lua',
    'client/launcher.lua',
}

server_scripts {
    'server/main.lua',
    'server/crafting.lua',
    'server/devices.lua',
    'server/tablet.lua',
    'server/launcher.lua',
    'server/items.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'es_extended',
    'ox_inventory',
}

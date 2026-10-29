fx_version 'cerulean'
game 'gta5'

lua54 'yes'

dependencies {
    'ox_lib',
    'ox_core',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/server.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

fx_version 'cerulean'
game 'gta5'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/client.lua',
    'client/carhud.lua',
    'client/needs.lua',
    'stream/minimap.gfx',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/assets/*'
}
fx_version 'cerulean'
game 'gta5'

lua54 'yes'

version '1.1.2'

author 'Mosoto Scripts'
description 'The most advanced seatbelt system for FiveM'

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua',
}

client_scripts {
    'code/modules/editable.lua',
    'code/modules/client.lua',
}

server_scripts {
    'code/modules/server.lua',
}

files {
    'code/web/index.html',
    'code/web/styles.css',
    'code/web/main.js',
    'code/web/assets/indicator.png',
    'code/web/assets/heartbeat.ogg'
}

ui_page 'code/web/index.html'

data_file 'DLC_ITYP_REQUEST' 'mst_seatbelt.ytyp'

escrow_ignore {
    'config.lua',
    'code/modules/editable.lua',
    'install/**',
}
dependency '/assetpacks'
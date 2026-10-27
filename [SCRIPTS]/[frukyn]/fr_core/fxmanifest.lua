fx_version 'cerulean'
game 'gta5'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
    'client/vehmenu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
}

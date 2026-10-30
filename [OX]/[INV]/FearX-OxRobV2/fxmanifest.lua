fx_version 'cerulean'
game 'gta5'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'config/sv_config.lua',
    'server/main.lua',
}
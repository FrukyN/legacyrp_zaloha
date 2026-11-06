fx_version 'cerulean'
game 'gta5'

lua54 'yes'
ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/penal_code.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@ox_core/lib/init.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'sql/mdt.sql'
}

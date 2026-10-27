fx_version 'cerulean'
game 'gta5'
author 'wx / woox'
lua54 'yes'

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'server/*.lua'
}

client_scripts {
	'client/*.lua'
}

shared_scripts {'@ox_lib/init.lua', 'shared/*.lua'}

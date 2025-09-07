fx_version 'cerulean'
game 'gta5'

description 'Boombox script'
author 'BeerGames5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua'
}

ui_page 'index.html'

files {
    'index.html'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Monoskrypt'
description 'Appearance system for Monoskrypt RP'
version '1.1.0'

dependency 'mono_core'
dependency 'oxmysql'

shared_scripts {
    'shared/config.lua',
    'shared/definitions.lua'
}

client_scripts {
    'client/appearance.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/appearance.lua',
    'server/main.lua'
}

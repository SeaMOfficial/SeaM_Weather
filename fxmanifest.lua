fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'SeaM_Weather'
author 'SeaM'
description 'Weather and time control with per-zone conditions'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/weathers.lua',
    'shared/zones.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'

dependency 'SeaM_Core'

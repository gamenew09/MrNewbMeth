-- Resource Metadata
fx_version 'cerulean'
games { 'gta5' }

name 'MrNewbMeth'
author 'Toenail Clipper#4071'
description 'Originally by MrNewb#6475. Another meth creation and selling script.'

lua54 'yes'

server_scripts {
    "server/sv_config.lua",
    "server/server.lua"
}

client_scripts {
    "client/client.lua"
}

dependencies {
    --'es_extended',
    --'esx_ambulancejob',
    --'mythic_progbar'
}


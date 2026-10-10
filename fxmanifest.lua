-- Pepper Chat – Chat mit Reitern (Alle, OOC, Team) und Werkzeugen fürs Team (kostenlos)
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pepper_chat'
author 'Pepper Scripts'
description 'Chat with tabs (All, OOC, Staff) and staff tools: mute, clear, slow mode, announcements, word filter, log'
version '1.0.0'
repository 'https://github.com/PepperScripts/pepper_chat'

-- Ersetzt den Standard-Chat: andere Ressourcen, die "chat" voraussetzen oder exports.chat nutzen, laufen weiter.
provide 'chat'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config_server.lua',
    'server/permissions.lua',
    'server/mutes.lua',
    'server/log.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'oxmysql',
}

-- Offener Quellcode: Wird die Ressource über das Cfx.re Portal ausgeliefert, bleibt alles lesbar und änderbar.
escrow_ignore {
    'config.lua',
    'config_server.lua',
    'client/*.lua',
    'server/*.lua',
    'shared/*.lua',
    'locales/*.json',
    'install/*.sql',
}

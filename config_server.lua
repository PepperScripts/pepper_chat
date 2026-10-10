-- Einstellungen, die nur der Server kennt (werden nie an Spieler geschickt)
-- Settings only the server knows (never sent to players)
ServerConfig = {}

-- Protokoll: Datei logs/chat-JJJJ-MM-TT.log im Ressourcenordner und/oder Discord-Webhook ('' = aus)
-- Log: file logs/chat-YYYY-MM-DD.log in the resource folder and/or a Discord webhook ('' = off)
ServerConfig.Log = {
    file = true,
    webhook = '',
}

-- Spam-Schutz (gilt nicht fürs Team) · Spam protection (does not apply to staff)
ServerConfig.Spam = {
    cooldown = 1000,       -- Millisekunden zwischen zwei Nachrichten · milliseconds between two messages
    duplicateWindow = 10,  -- gleiche Nachricht erst nach so vielen Sekunden wieder · same message again after this many seconds
    floodCount = 6,        -- so viele Nachrichten …
    floodWindow = 10,      -- … in so vielen Sekunden gelten als Flood
    floodMute = 60,        -- dann so viele Sekunden stumm · then muted for this many seconds
}

-- Wortfilter: 'censor' ersetzt durch Sternchen, 'block' verwirft die Nachricht, 'off' schaltet ihn ab
-- Word filter: 'censor' replaces with asterisks, 'block' drops the message, 'off' disables it
ServerConfig.Filter = {
    mode = 'censor',
    words = {
        -- 'beispielwort', 'example word',
    },
}

Config = {}

-- Sprache: 'de' oder 'en' (Dateien in locales/) · Language: 'de' or 'en' (files in locales/)
Config.Locale = 'en'

-- Taste zum Öffnen (Spieler können sie in den GTA-Einstellungen unter Tastenbelegung → FiveM ändern)
-- Key to open the chat (players can change it in the GTA settings under Key Bindings → FiveM)
Config.OpenKey = 't'

-- Kanäle an/aus. "global" ist der normale Chat für alle, "team" sehen nur Teamler.
-- Channels on/off. "global" is the normal chat for everyone, "team" is visible to staff only.
Config.Channels = { global = true, ooc = true, team = true }

-- In welchen Kanal der Reiter "Alle" schreibt · Which channel the "All" tab writes to
Config.DefaultChannel = 'global'

Config.ShowIds = true      -- Server-ID hinter dem Namen · server ID behind the name
Config.ShowTime = true     -- Uhrzeit vor der Nachricht · time in front of the message
Config.MaxLength = 200     -- Höchstlänge einer Nachricht · max message length
Config.MaxMessages = 100   -- so viele Nachrichten bleiben im Verlauf · messages kept in the history
Config.FadeAfter = 12      -- Sekunden bis zum Ausblenden, 0 = nie · seconds until the chat fades out, 0 = never

-- Aussehen: Position in Prozent des Bildschirms, Breite/Höhe in Textzeilen-Einheiten, Größe 1.0 = normal
-- Look: position in percent of the screen, width/height in text-line units, scale 1.0 = normal
Config.UI = {
    left = 1.2,
    top = 4.0,
    width = 31,
    height = 17,
    scale = 1.0,
    accent = '#E5484D',
}

-- Ankündigungen zusätzlich als Banner oben in der Mitte · Show announcements as a banner at the top as well
Config.AnnouncementBanner = { enabled = true, duration = 8 }

-- "Name ist beigetreten / hat den Server verlassen" im Chat · Join and leave messages in chat
Config.JoinLeaveMessages = false

-- Auswahl im Team-Menü: Langsam-Modus in Sekunden, Stummschaltung in Minuten (0 = dauerhaft)
-- Choices in the staff menu: slow mode in seconds, mute in minutes (0 = permanent)
Config.SlowModeSteps = { 0, 5, 10, 30, 60 }
Config.MuteSteps = { 10, 60, 1440, 0 }

-- Befehlsnamen (ohne Schrägstrich) · Command names (without the slash)
Config.Commands = {
    ooc = 'ooc',
    team = 'team',
    announce = 'announce',
    clear = 'chatclear',
    mute = 'chatmute',
    unmute = 'chatunmute',
    slow = 'chatslow',
}

-- Wer zum Team gehört. Die erste passende Rolle gewinnt (oben = höher).
--   groups: Gruppen aus ESX (getGroup) bzw. Rechte aus QBCore/Qbox (admin, mod, god …)
--   Ohne Framework: add_ace group.admin pepperchat.admin allow   (oder pepperchat.mod)
-- Who counts as staff. The first matching role wins (top = higher).
--   groups: groups from ESX (getGroup) or permissions from QBCore/Qbox (admin, mod, god …)
--   Without a framework: add_ace group.admin pepperchat.admin allow   (or pepperchat.mod)
Config.Staff = {
    { key = 'admin', label = 'Admin', color = '#E5484D', groups = { 'superadmin', 'admin', 'god' } },
    { key = 'mod', label = 'Mod', color = '#4C9AFF', groups = { 'mod', 'moderator', 'support' } },
}

-- Welcher Name im Chat steht. Standard: FiveM-Name. Für den Charakternamen hier dein Framework abfragen.
-- Which name the chat shows. Default: FiveM name. Query your framework here for the character name.
-- Läuft nur auf dem Server · Runs on the server only.
Config.GetName = function(source)
    return GetPlayerName(source)
end

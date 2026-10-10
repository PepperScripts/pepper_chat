# Pepper Chat

Free chat for FiveM with tabs and staff tools · Works with ESX, QBCore, Qbox or no framework · Requires oxmysql

**Pepper Scripts** · More scripts: https://pepper-scripts.tebex.store · Support: https://discord.gg/6NaFJWKDYu

---

## 🇬🇧 English

### Features
- Tabs: **All**, **OOC** and **Staff** (staff tab is visible to staff only)
- Staff tools right in the chat window, no commands needed:
  - Right-click a message: mute the player (10 min, 1 h, 24 h, permanent) or delete the message
  - Buttons: announcement to everyone, slow mode, list of muted players, clear chat
- Announcements appear in chat and as a banner at the top of the screen
- Staff badge in front of the name (Admin, Mod), colours and labels set in the config
- Spam protection: cooldown, duplicate check and flood mute; word filter that censors or blocks
- Mutes are stored in the database and survive a restart
- Log to a daily file and, if you want, to a Discord webhook
- Command suggestions while typing, input history (arrow keys), message counter
- Replaces the default chat: `chat:addMessage`, `chat:addSuggestion`, templates and `exports.chat` keep working
- English and German included

### Installation
1. Put the `pepper_chat` folder into your `resources` folder.
2. In your `server.cfg`, remove `ensure chat` (the default chat) and add, after `oxmysql`:
   ```
   ensure pepper_chat
   ```
3. Restart the server. The database table is created automatically.
4. Set `Config.Locale` and your staff groups in `config.lua`.

### Who is staff?
The first matching role in `Config.Staff` wins.
- **ESX:** the player's group (`admin`, `superadmin`, `mod` …)
- **QBCore / Qbox:** the player's permission (`god`, `admin`, `mod`)
- **No framework:** add to your `server.cfg`
  ```
  add_ace group.admin pepperchat.admin allow
  add_ace group.moderator pepperchat.mod allow
  ```

### Commands
| Command | Who | What it does |
|---|---|---|
| `/ooc [text]` | everyone | Out-of-character message |
| `/team [text]` | staff | Message to the staff chat |
| `/announce [text]` | staff | Announcement to everyone |
| `/chatclear` | staff | Clears the chat for everyone |
| `/chatmute [id] [minutes] [reason]` | staff | Mutes a player, `0` = permanent |
| `/chatunmute [id]` | staff | Unmutes a player |
| `/chatslow [seconds]` | staff | Slow mode, `0` = off |

All names can be changed in `Config.Commands`. The staff commands also work from the server console.

### Settings
`config.lua` (sent to players): language, open key, channels, position and size, fade-out time, banner, staff roles, command names.

`config_server.lua` (server only): log file and Discord webhook, spam limits, word filter.

### For developers
```lua
-- client
exports.pepper_chat:setVisible(false)                       -- hide the chat, e.g. for a cutscene
TriggerEvent('chat:addMessage', { color = { 255, 196, 107 }, args = { 'Bank', 'You received $500.' } })
-- server
TriggerClientEvent('chat:addMessage', source, { args = { 'Server', 'Welcome!' } })
```

---

## 🇩🇪 Deutsch

### Features
- Reiter: **Alle**, **OOC** und **Team** (den Team-Reiter sehen nur Teamler)
- Team-Werkzeuge direkt im Chatfenster, ohne Befehle:
  - Rechtsklick auf eine Nachricht: Spieler stummschalten (10 min, 1 Std., 24 Std., dauerhaft) oder Nachricht löschen
  - Knöpfe: Ankündigung an alle, Langsam-Modus, Liste der Stummgeschalteten, Chat leeren
- Ankündigungen erscheinen im Chat und als Banner oben am Bildschirm
- Team-Abzeichen vor dem Namen (Admin, Mod), Farben und Texte in der Config
- Spam-Schutz: Wartezeit, Wiederholungsprüfung und Flood-Sperre; Wortfilter, der zensiert oder blockiert
- Stummschaltungen liegen in der Datenbank und überstehen einen Neustart
- Protokoll in eine Tagesdatei und auf Wunsch an einen Discord-Webhook
- Befehlsvorschläge beim Tippen, Eingabeverlauf (Pfeiltasten), Zeichenzähler
- Ersetzt den Standard-Chat: `chat:addMessage`, `chat:addSuggestion`, Vorlagen und `exports.chat` laufen weiter
- Deutsch und Englisch dabei

### Installation
1. Ordner `pepper_chat` in deinen `resources`-Ordner legen.
2. In der `server.cfg` die Zeile `ensure chat` (Standard-Chat) entfernen und nach `oxmysql` eintragen:
   ```
   ensure pepper_chat
   ```
3. Server neu starten. Die Datenbanktabelle wird automatisch angelegt.
4. `Config.Locale = 'de'` und deine Team-Gruppen in der `config.lua` einstellen.

### Wer gehört zum Team?
Die erste passende Rolle in `Config.Staff` gewinnt: bei ESX die Gruppe des Spielers, bei QBCore/Qbox sein Recht
(`god`, `admin`, `mod`). Ohne Framework trägst du in der `server.cfg` ein:
```
add_ace group.admin pepperchat.admin allow
```

Befehle und Einstellungen stehen oben im englischen Teil.

---

MIT License · Pepper Scripts is not affiliated with Rockstar Games, Take-Two Interactive or Cfx.re.

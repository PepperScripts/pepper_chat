-- Pepper Chat – Server: prüft jede Nachricht (Rechte, Stummschaltung, Spam, Wortfilter) und verteilt sie
Chat = Chat or {}

local CHANNELS = { global = true, ooc = true, team = true }
local RECENT_MAX = 300

local nextId = 0
local recent = {}       -- [Nachrichten-ID] = { identifier, name, source } für Löschen/Stummschalten per Rechtsklick
local recentOrder = {}
local slowSeconds = 0
local players = {}      -- [source] = { last, lastSlow, lastText, lastTextAt, stamps = {}, floodUntil }
local hooks = {}

-- ---------------------------------------------------------------------------------------------- Hilfen

-- Entfernt Steuerzeichen und Farbcodes (^1), kürzt auf die Höchstlänge (UTF-8-sicher).
local function clean(text, max)
    text = tostring(text or '')
    text = text:gsub('%c', ' '):gsub('%^%d', '')
    text = text:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    max = max or Config.MaxLength
    local length = utf8.len(text)
    if length == nil then
        text = text:sub(1, max)
    elseif length > max then
        text = text:sub(1, utf8.offset(text, max + 1) - 1)
    end
    return text
end

local function playerName(source)
    if source == 0 then return L('console') end
    local ok, name = pcall(Config.GetName, source)
    name = clean(ok and name or GetPlayerName(source) or ('#' .. source), 40)
    return name ~= '' and name or ('#' .. source)
end

local function badgeOf(role)
    return role and { label = role.label, color = role.color } or nil
end

-- Graue Systemzeile nur für einen Spieler (oder -1 für alle); auf der Konsole als Ausgabe.
local function system(target, text, kind)
    if target == 0 then
        print('[pepper_chat] ' .. text)
    else
        TriggerClientEvent('pepper_chat:system', target, text, kind or 'info')
    end
end

local function systemStaff(text)
    for _, source in ipairs(Chat.staffPlayers()) do
        system(source, text, 'staff')
    end
    print('[pepper_chat] ' .. text)
end

local function durationText(minutes)
    if not minutes or minutes <= 0 then return L('duration_perm') end
    return L('duration_min', { minutes = math.floor(minutes) })
end

local function remember(id, source, name)
    recent[id] = { identifier = Chat.identifier(source), name = name, source = source }
    recentOrder[#recentOrder + 1] = id
    if #recentOrder > RECENT_MAX then
        recent[table.remove(recentOrder, 1)] = nil
    end
end

-- Wortfilter: liefert den (ggf. zensierten) Text oder nil, wenn die Nachricht verworfen wird.
local function filterWords(text)
    local filter = ServerConfig.Filter
    if not filter or filter.mode == 'off' or not filter.words or #filter.words == 0 then return text end
    local lower = text:lower()
    local hit = false
    for _, word in ipairs(filter.words) do
        word = tostring(word):lower()
        if word ~= '' then
            local from = 1
            while true do
                local a, b = lower:find(word, from, true)
                if not a then break end
                hit = true
                if filter.mode == 'block' then return nil end
                local stars = ('*'):rep(b - a + 1)
                text = text:sub(1, a - 1) .. stars .. text:sub(b + 1)
                lower = lower:sub(1, a - 1) .. stars .. lower:sub(b + 1)
                from = b + 1
            end
        end
    end
    return text, hit
end

-- Spam-Schutz: liefert einen Fehlertext-Schlüssel (und Platzhalter) oder nil, wenn die Nachricht durchgeht.
local function checkSpam(source, text)
    local spam = ServerConfig.Spam
    local now = GetGameTimer()
    local state = players[source]
    if not state then
        state = { last = -100000, lastSlow = -100000000, lastTextAt = -100000, stamps = {} }
        players[source] = state
    end

    if state.floodUntil and now < state.floodUntil then
        return 'spam_flood', { seconds = math.ceil((state.floodUntil - now) / 1000) }
    end
    if now - state.last < spam.cooldown then return 'spam_wait' end
    if state.lastText == text and now - state.lastTextAt < spam.duplicateWindow * 1000 then return 'spam_duplicate' end

    -- Flood: zu viele Nachrichten im Zeitfenster
    local stamps = state.stamps
    local window = spam.floodWindow * 1000
    while stamps[1] and now - stamps[1] > window do table.remove(stamps, 1) end
    stamps[#stamps + 1] = now
    if #stamps >= spam.floodCount then
        state.floodUntil = now + spam.floodMute * 1000
        state.stamps = {}
        return 'spam_flood', { seconds = spam.floodMute }
    end

    state.last, state.lastText, state.lastTextAt = now, text, now
    return nil
end

local function sendState(source)
    local role = Chat.getRole(source)
    TriggerClientEvent('pepper_chat:state', source, {
        staff = role ~= nil,
        badge = badgeOf(role),
        slow = slowSeconds,
    })
end

local function sendCommands(source)
    local list = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        if IsPlayerAceAllowed(source, ('command.%s'):format(command.name)) then
            list[#list + 1] = { name = '/' .. command.name, help = '' }
        end
    end
    TriggerClientEvent('chat:addSuggestions', source, list)
end

-- ---------------------------------------------------------------------------------------------- Nachrichten

-- Kernablauf für jede Spielernachricht. source 0 (Konsole) darf nur ins Team und überspringt die Prüfungen.
local function handleMessage(source, channel, text)
    if not CHANNELS[channel] then return end
    if not Config.Channels[channel] then return system(source, L('channel_off'), 'warn') end

    text = clean(text)
    if text == '' or text:sub(1, 1) == '/' then return end

    local role = Chat.getRole(source)
    if channel == 'team' and not role then return system(source, L('no_permission'), 'warn') end

    if source ~= 0 then
        local mute = Chat.getMute(Chat.identifier(source))
        if mute then
            local line = mute.expires and L('muted_you', { ['until'] = os.date('%d.%m. %H:%M', mute.expires) }) or L('muted_you_perm')
            if mute.reason and mute.reason ~= '' then line = line .. ' ' .. L('muted_reason', { reason = mute.reason }) end
            return system(source, line, 'warn')
        end
    end

    if not role then
        local state = players[source]
        local now = GetGameTimer()
        if slowSeconds > 0 and state and now - state.lastSlow < slowSeconds * 1000 then
            return system(source, L('slow_wait', { seconds = math.ceil((slowSeconds * 1000 - (now - state.lastSlow)) / 1000) }), 'warn')
        end
        local problem, vars = checkSpam(source, text)
        if problem then return system(source, L(problem, vars), 'warn') end
        players[source].lastSlow = now
    end

    if channel ~= 'team' then
        local filtered = filterWords(text)
        if not filtered then return system(source, L('filter_blocked'), 'warn') end
        text = filtered
    end

    local name = playerName(source)

    -- Verträglich mit dem Standard-Chat: andere Ressourcen dürfen mitlesen, ändern oder abbrechen.
    if channel ~= 'team' and source ~= 0 then
        TriggerEvent('chatMessage', source, name, text)
        if WasEventCanceled() then return end

        local out = { args = { name, text }, color = { 255, 255, 255 }, multiline = true }
        local canceled = false
        local ref = {
            updateMessage = function(changes)
                if type(changes) == 'table' then
                    for key, value in pairs(changes) do out[key] = value end
                end
            end,
            cancel = function() canceled = true end,
            setSeObject = function() end,
            setRouting = function() end,
        }
        for _, hook in ipairs(hooks) do pcall(hook, source, out, ref) end
        if canceled then return end
        if type(out.args) == 'table' and out.args[2] then
            text = clean(out.args[2])
            if text == '' then return end
        end
    end

    nextId = nextId + 1
    local message = {
        id = nextId,
        channel = channel,
        source = source,
        name = name,
        badge = badgeOf(role),
        text = text,
    }
    if source ~= 0 then remember(nextId, source, name) end

    if channel == 'team' then
        for _, target in ipairs(Chat.staffPlayers()) do
            TriggerClientEvent('pepper_chat:message', target, message)
        end
    else
        TriggerClientEvent('pepper_chat:message', -1, message)
    end
    Chat.log(channel:upper(), source, name, text)
end

RegisterNetEvent('pepper_chat:send', function(channel, text)
    local source = source
    if type(channel) ~= 'string' or type(text) ~= 'string' then return end
    handleMessage(source, channel, text)
end)

RegisterNetEvent('pepper_chat:init', function()
    local source = source
    Chat.forgetRole(source)
    sendState(source)
    sendCommands(source)
end)

-- ---------------------------------------------------------------------------------------------- Team-Werkzeuge

local function requireStaff(source)
    if Chat.isStaff(source) then return true end
    system(source, L('no_permission'), 'warn')
    return false
end

local function clearChat(source)
    TriggerClientEvent('chat:clear', -1)
    system(-1, L('cleared'), 'info')
    Chat.log('CLEAR', source, playerName(source), '-')
end

local function setSlow(source, seconds)
    seconds = math.max(0, math.min(600, math.floor(tonumber(seconds) or 0)))
    slowSeconds = seconds
    TriggerClientEvent('pepper_chat:slow', -1, slowSeconds)
    system(-1, seconds > 0 and L('slow_on', { seconds = seconds }) or L('slow_off'), 'info')
    Chat.log('SLOW', source, playerName(source), tostring(seconds))
end

local function announce(source, text)
    text = clean(text)
    if text == '' then return system(source, L('usage_text', { command = Config.Commands.announce }), 'warn') end
    TriggerClientEvent('pepper_chat:announce', -1, text)
    Chat.log('ANNOUNCE', source, playerName(source), text)
end

-- target = { identifier, name, source? }
local function mute(source, target, minutes, reason)
    if not Chat.mutesReady() then return system(source, L('db_not_ready'), 'warn') end
    minutes = math.max(0, math.min(525600, tonumber(minutes) or 0))
    reason = clean(reason or '', 160)
    local staff = playerName(source)
    Chat.setMute(target.identifier, target.name, minutes, reason, staff)

    local duration = durationText(minutes)
    systemStaff(L('staff_muted', { staff = staff, name = target.name, duration = duration }))
    if target.source and GetPlayerName(target.source) and Chat.identifier(target.source) == target.identifier then
        local line = L('you_muted', { duration = duration })
        if reason ~= '' then line = line .. ' ' .. L('muted_reason', { reason = reason }) end
        system(target.source, line, 'warn')
    end
    Chat.log('MUTE', source, staff, ('%s (%s) %s %s'):format(target.name, target.identifier, duration, reason))
end

local function unmute(source, identifier)
    if not Chat.mutesReady() then return system(source, L('db_not_ready'), 'warn') end
    local removed = Chat.removeMute(identifier)
    if not removed then return system(source, L('not_muted'), 'warn') end
    local staff = playerName(source)
    systemStaff(L('staff_unmuted', { staff = staff, name = removed.name }))
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if Chat.identifier(target) == identifier then system(target, L('you_unmuted'), 'info') end
    end
    Chat.log('UNMUTE', source, staff, ('%s (%s)'):format(removed.name, identifier))
end

local function deleteMessage(source, id)
    local entry = recent[id]
    if not entry then return end
    TriggerClientEvent('pepper_chat:delete', -1, id)
    local staff = playerName(source)
    systemStaff(L('staff_deleted', { staff = staff, name = entry.name }))
    Chat.log('DELETE', source, staff, ('message %s from %s'):format(id, entry.name))
end

-- Alles, was das Team-Menü in der Oberfläche auslöst. Jede Aktion prüft die Rechte auf dem Server neu.
RegisterNetEvent('pepper_chat:staff', function(action, data)
    local source = source
    if type(action) ~= 'string' then return end
    if type(data) ~= 'table' then data = {} end
    Chat.forgetRole(source)
    if not requireStaff(source) then return end

    if action == 'clear' then
        clearChat(source)
    elseif action == 'slow' then
        setSlow(source, data.seconds)
    elseif action == 'announce' then
        announce(source, tostring(data.text or ''))
    elseif action == 'mute' then
        local entry = recent[tonumber(data.id) or -1]
        if not entry then return system(source, L('player_not_found'), 'warn') end
        mute(source, entry, data.minutes, '')
    elseif action == 'unmute' then
        unmute(source, tostring(data.identifier or ''))
    elseif action == 'delete' then
        deleteMessage(source, tonumber(data.id) or -1)
    elseif action == 'mutes' then
        TriggerClientEvent('pepper_chat:mutes', source, Chat.listMutes())
    end
end)

-- ---------------------------------------------------------------------------------------------- Befehle

local function textCommand(name, handler)
    if not name or name == '' then return end
    RegisterCommand(name, function(source, args)
        handler(source, table.concat(args, ' '), args)
    end, false)
end

textCommand(Config.Commands.ooc, function(source, text)
    if source == 0 then return end
    if clean(text) == '' then return system(source, L('usage_text', { command = Config.Commands.ooc }), 'warn') end
    handleMessage(source, 'ooc', text)
end)

textCommand(Config.Commands.team, function(source, text)
    if clean(text) == '' then return system(source, L('usage_text', { command = Config.Commands.team }), 'warn') end
    handleMessage(source, 'team', text)
end)

textCommand(Config.Commands.announce, function(source, text)
    if requireStaff(source) then announce(source, text) end
end)

textCommand(Config.Commands.clear, function(source)
    if requireStaff(source) then clearChat(source) end
end)

textCommand(Config.Commands.slow, function(source, _, args)
    if not requireStaff(source) then return end
    if not tonumber(args[1]) then return system(source, L('usage_slow', { command = Config.Commands.slow }), 'warn') end
    setSlow(source, args[1])
end)

textCommand(Config.Commands.mute, function(source, _, args)
    if not requireStaff(source) then return end
    local target = tonumber(args[1])
    if not target or not tonumber(args[2]) then return system(source, L('usage_mute', { command = Config.Commands.mute }), 'warn') end
    if not GetPlayerName(target) then return system(source, L('player_not_found'), 'warn') end
    mute(source, { identifier = Chat.identifier(target), name = playerName(target), source = target },
        tonumber(args[2]), table.concat(args, ' ', 3))
end)

textCommand(Config.Commands.unmute, function(source, _, args)
    if not requireStaff(source) then return end
    local target = tonumber(args[1])
    if not target then return system(source, L('usage_unmute', { command = Config.Commands.unmute }), 'warn') end
    if not GetPlayerName(target) then return system(source, L('player_not_found'), 'warn') end
    unmute(source, Chat.identifier(target))
end)

-- Wie beim Standard-Chat: "say" auf der Server-Konsole schreibt in den Chat.
RegisterCommand('say', function(source, args)
    if source ~= 0 then return end
    local text = clean(table.concat(args, ' '))
    if text == '' then return end
    TriggerClientEvent('chat:addMessage', -1, { color = { 255, 255, 255 }, args = { L('console'), text } })
    Chat.log('CONSOLE', 0, L('console'), text)
end, true)

-- Unbekannter Befehl: nicht als Chatnachricht an alle schicken, sondern dem Spieler sagen.
AddEventHandler('__cfx_internal:commandFallback', function(command)
    local source = source
    local name = tostring(command):match('^(%S+)') or ''
    system(source, L('unknown_command', { command = clean(name, 40) }), 'warn')
    CancelEvent()
end)

-- ---------------------------------------------------------------------------------------------- Verträglichkeit

-- exports.chat:addMessage(target, message) wie beim Standard-Chat
exports('addMessage', function(target, message)
    if not message then
        message = target
        target = -1
    end
    if not target or not message then return end
    TriggerClientEvent('chat:addMessage', target, message)
end)

exports('registerMessageHook', function(hook)
    hooks[#hooks + 1] = hook
end)

-- Weitere Exports des Standard-Chats, die manche Ressourcen aufrufen; hier ohne Wirkung.
exports('registerMode', function() end)

-- ---------------------------------------------------------------------------------------------- Spieler kommen und gehen

AddEventHandler('playerJoining', function()
    local source = source
    if Config.JoinLeaveMessages then system(-1, L('joined', { name = playerName(source) }), 'info') end
end)

AddEventHandler('playerDropped', function()
    local source = source
    if Config.JoinLeaveMessages then system(-1, L('left', { name = playerName(source) }), 'info') end
    players[source] = nil
    Chat.forgetRole(source)
end)

-- Startet eine andere Ressource, kommen neue Befehle dazu: Vorschläge neu schicken.
AddEventHandler('onServerResourceStart', function()
    SetTimeout(500, function()
        for _, id in ipairs(GetPlayers()) do sendCommands(tonumber(id)) end
    end)
end)

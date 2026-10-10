-- Pepper Chat – Client: verbindet Spiel, Server und Oberfläche (NUI)
local OPEN_COMMAND = 'pepper_chat_open'

local isOpen = false
local uiReady = false
local pending = {}
local isStaff = false

-- Nachrichten an die Oberfläche; vor dem Laden werden sie gesammelt.
local function nui(action, data)
    local payload = { action = action, data = data }
    if uiReady then
        SendNUIMessage(payload)
    elseif #pending < 200 then
        pending[#pending + 1] = payload
    end
end

local function closeChat()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
end

-- Der eingebaute GTA-Textchat bleibt aus.
SetTextChatEnabled(false)

RegisterCommand(OPEN_COMMAND, function()
    if isOpen or not uiReady or IsPauseMenuActive() then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end, false)
RegisterKeyMapping(OPEN_COMMAND, L('key_open'), 'keyboard', Config.OpenKey)

-- ---------------------------------------------------------------------------------------------- Befehlsvorschläge

-- Befehle, die auf dem Client angemeldet sind (Tastenbelegungen mit +/- und interne mit _ ausgenommen).
local function refreshCommands()
    local list = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        local name = command.name
        if name ~= OPEN_COMMAND and not name:match('^[%+%-_]') and IsAceAllowed(('command.%s'):format(name)) then
            list[#list + 1] = { name = '/' .. name, help = '' }
        end
    end
    nui('suggestions', { list = list })
end

local function param(key)
    return { name = L('param_' .. key) }
end

-- Hilfetexte für die eigenen Befehle; Team-Befehle nur fürs Team.
local function ownSuggestions()
    local commands = Config.Commands
    local list = {}
    local function add(name, help, params)
        if name and name ~= '' then list[#list + 1] = { name = '/' .. name, help = L(help), params = params } end
    end
    if Config.Channels.ooc then add(commands.ooc, 'help_ooc', { param('text') }) end
    if isStaff then
        if Config.Channels.team then add(commands.team, 'help_team', { param('text') }) end
        add(commands.announce, 'help_announce', { param('text') })
        add(commands.clear, 'help_clear', {})
        add(commands.mute, 'help_mute', { param('id'), param('minutes'), param('reason') })
        add(commands.unmute, 'help_unmute', { param('id') })
        add(commands.slow, 'help_slow', { param('seconds') })
    else
        -- Team-Befehle nicht vorschlagen, auch wenn sie für alle angemeldet sind
        local hide = {}
        for _, key in ipairs({ 'team', 'announce', 'clear', 'mute', 'unmute', 'slow' }) do
            if commands[key] and commands[key] ~= '' then hide[#hide + 1] = '/' .. commands[key] end
        end
        nui('hideSuggestions', { names = hide })
    end
    nui('suggestions', { list = list, overwrite = true })
end

-- ---------------------------------------------------------------------------------------------- Oberfläche → Spiel

RegisterNUICallback('ready', function(_, cb)
    cb({
        config = {
            channels = Config.Channels,
            defaultChannel = Config.DefaultChannel,
            showIds = Config.ShowIds,
            showTime = Config.ShowTime,
            maxLength = Config.MaxLength,
            maxMessages = Config.MaxMessages,
            fadeAfter = Config.FadeAfter,
            ui = Config.UI,
            banner = Config.AnnouncementBanner,
            slowSteps = Config.SlowModeSteps,
            muteSteps = Config.MuteSteps,
        },
        strings = LocaleUI(),
    })
    uiReady = true
    for i = 1, #pending do SendNUIMessage(pending[i]) end
    pending = {}
    refreshCommands()
    TriggerServerEvent('pepper_chat:init')
end)

RegisterNUICallback('close', function(_, cb)
    closeChat()
    cb({})
end)

RegisterNUICallback('submit', function(data, cb)
    closeChat()
    cb({})
    local text = type(data.text) == 'string' and data.text or ''
    if text == '' then return end
    if text:sub(1, 1) == '/' then
        ExecuteCommand(text:sub(2))
    elseif data.announce then
        TriggerServerEvent('pepper_chat:staff', 'announce', { text = text })
    else
        TriggerServerEvent('pepper_chat:send', tostring(data.channel or Config.DefaultChannel), text)
    end
end)

RegisterNUICallback('staff', function(data, cb)
    cb({})
    if type(data.action) ~= 'string' then return end
    TriggerServerEvent('pepper_chat:staff', data.action, data)
end)

-- ---------------------------------------------------------------------------------------------- Server → Oberfläche

RegisterNetEvent('pepper_chat:message', function(message) nui('message', message) end)
RegisterNetEvent('pepper_chat:system', function(text, kind) nui('system', { text = tostring(text), kind = kind }) end)
RegisterNetEvent('pepper_chat:announce', function(text) nui('announce', { text = tostring(text) }) end)
RegisterNetEvent('pepper_chat:delete', function(id) nui('delete', { id = id }) end)
RegisterNetEvent('pepper_chat:slow', function(seconds) nui('slow', { seconds = seconds }) end)
RegisterNetEvent('pepper_chat:mutes', function(list) nui('mutes', { list = list }) end)

RegisterNetEvent('pepper_chat:state', function(state)
    isStaff = state.staff == true
    nui('state', state)
    ownSuggestions()
end)

-- ---------------------------------------------------------------------------------------------- Verträglichkeit mit dem Standard-Chat

RegisterNetEvent('chat:addMessage', function(message) nui('legacy', message) end)

-- Altes Format: Autor, Farbe, Text
RegisterNetEvent('chatMessage', function(author, color, text)
    local args = { text }
    if author and author ~= '' then args = { author, text } end
    nui('legacy', { color = color, multiline = true, args = args })
end)

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    nui('suggestions', { list = { { name = name, help = help or '', params = params } }, overwrite = true })
end)

RegisterNetEvent('chat:addSuggestions', function(list)
    nui('suggestions', { list = list or {} })
end)

RegisterNetEvent('chat:removeSuggestion', function(name) nui('removeSuggestion', { name = name }) end)
RegisterNetEvent('chat:addTemplate', function(id, html) nui('template', { id = id, html = html }) end)
RegisterNetEvent('chat:clear', function() nui('clear') end)

-- Modi des Standard-Chats gibt es hier nicht; die Events werden angenommen, damit nichts ins Leere läuft.
RegisterNetEvent('chat:addMode', function() end)
RegisterNetEvent('chat:removeMode', function() end)

exports('addMessage', function(message) nui('legacy', message) end)
exports('addSuggestion', function(name, help, params)
    nui('suggestions', { list = { { name = name, help = help or '', params = params } }, overwrite = true })
end)

-- Chat für Filmaufnahmen oder eigene Menüs ausblenden: exports.pepper_chat:setVisible(false)
exports('setVisible', function(visible) nui('visible', { value = visible ~= false }) end)

-- Neue Ressource gestartet: deren Befehle in die Vorschläge aufnehmen.
AddEventHandler('onClientResourceStart', function()
    SetTimeout(500, refreshCommands)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

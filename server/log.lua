-- Pepper Chat – Protokoll: sammelt Zeilen und schreibt sie gebündelt in die Tagesdatei und/oder an Discord
Chat = Chat or {}

local FLUSH_MS = 5000
local buffer = {}
local scheduled = false

local function writeFile(lines)
    local name = ('logs/chat-%s.log'):format(os.date('%Y-%m-%d'))
    local text = table.concat(lines, '\n') .. '\n'
    -- Anhängen ist am günstigsten; steht io nicht zur Verfügung, wird die Datei neu geschrieben.
    local ok = pcall(function()
        local file = assert(io.open(GetResourcePath(GetCurrentResourceName()) .. '/' .. name, 'a'))
        file:write(text)
        file:close()
    end)
    if not ok then
        local existing = LoadResourceFile(GetCurrentResourceName(), name) or ''
        SaveResourceFile(GetCurrentResourceName(), name, existing .. text, -1)
    end
end

local function sendWebhook(lines)
    -- Discord nimmt höchstens 2000 Zeichen je Nachricht: in Blöcke teilen.
    local chunk, size = {}, 0
    local function post()
        if #chunk == 0 then return end
        local content = table.concat(chunk, '\n'):gsub('@', '@\u{200B}') -- keine Erwähnungen auslösen
        PerformHttpRequest(ServerConfig.Log.webhook, function() end, 'POST',
            json.encode({ username = 'Pepper Chat', content = content }),
            { ['Content-Type'] = 'application/json' })
        chunk, size = {}, 0
    end
    for _, line in ipairs(lines) do
        line = line:sub(1, 600)
        if size + #line + 1 > 1800 then post() end
        chunk[#chunk + 1] = line
        size = size + #line + 1
    end
    post()
end

local function flush()
    scheduled = false
    if #buffer == 0 then return end
    local lines = buffer
    buffer = {}
    if ServerConfig.Log.file then writeFile(lines) end
    if ServerConfig.Log.webhook and ServerConfig.Log.webhook ~= '' then sendWebhook(lines) end
end

-- Chat.log('OOC', 12, 'Max', 'Hallo') → "[14:03:21] [OOC] Max (12): Hallo"
function Chat.log(kind, source, name, text)
    if not ServerConfig.Log.file and (not ServerConfig.Log.webhook or ServerConfig.Log.webhook == '') then return end
    local who = source and source ~= 0 and ('%s (%s)'):format(name, source) or name
    buffer[#buffer + 1] = ('[%s] [%s] %s: %s'):format(os.date('%H:%M:%S'), kind, who, text)
    if not scheduled then
        scheduled = true
        SetTimeout(FLUSH_MS, flush)
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then flush() end
end)

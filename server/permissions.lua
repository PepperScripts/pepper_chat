-- Pepper Chat – Rechte: Wer gehört zum Team? FiveM-Rechte (ACE) und Gruppen aus ESX / QBCore / Qbox.
Chat = Chat or {}

local CACHE_SECONDS = 30
local cache = {} -- [source] = { role = Rolle oder false, at = os.time() }
local CONSOLE_ROLE = { key = 'console', label = 'Console', color = '#9aa0aa' }

local esx, qbcore

-- Frameworks erst beim ersten Bedarf holen: sie starten oft nach dem Chat.
local function getESX()
    if esx then return esx end
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, object = pcall(function() return exports.es_extended:getSharedObject() end)
    if ok and object then esx = object end
    return esx
end

local function getQBCore()
    if qbcore then return qbcore end
    if GetResourceState('qb-core') ~= 'started' then return nil end
    local ok, object = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and object then qbcore = object end
    return qbcore
end

local function esxGroup(source)
    local object = getESX()
    if not object then return nil end
    local ok, group = pcall(function()
        local xPlayer = object.GetPlayerFromId(source)
        return xPlayer and xPlayer.getGroup and xPlayer.getGroup() or nil
    end)
    return ok and group or nil
end

local function qbHasPermission(source, permission)
    local object = getQBCore()
    if not object or not object.Functions or not object.Functions.HasPermission then return false end
    local ok, allowed = pcall(object.Functions.HasPermission, source, permission)
    return ok and allowed == true
end

local function findRole(source)
    local group = esxGroup(source)
    for _, role in ipairs(Config.Staff) do
        if IsPlayerAceAllowed(source, 'pepperchat.' .. role.key) then return role end
        for _, name in ipairs(role.groups or {}) do
            -- Qbox und neuere QBCore-Versionen vergeben die Gruppen als ACE (admin, mod, god)
            if group == name or IsPlayerAceAllowed(source, name) or qbHasPermission(source, name) then
                return role
            end
        end
    end
    return nil
end

-- Liefert die Rolle (Tabelle aus Config.Staff) oder nil. source 0 = Konsole, darf alles.
function Chat.getRole(source)
    if source == 0 then return CONSOLE_ROLE end
    local now = os.time()
    local entry = cache[source]
    if entry and now - entry.at < CACHE_SECONDS then return entry.role or nil end
    local role = findRole(source)
    cache[source] = { role = role or false, at = now }
    return role
end

function Chat.isStaff(source)
    return Chat.getRole(source) ~= nil
end

-- Alle Teamler, die gerade online sind (für Team-Chat und Team-Hinweise).
function Chat.staffPlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        if Chat.isStaff(source) then list[#list + 1] = source end
    end
    return list
end

function Chat.forgetRole(source)
    cache[source] = nil
end

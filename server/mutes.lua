-- Pepper Chat – Stummschaltungen: liegen in der Datenbank und zusätzlich im Speicher (schnelle Prüfung je Nachricht)
Chat = Chat or {}

local mutes = {}   -- [identifier] = { name, reason, by, expires (Unix-Sekunden oder nil = dauerhaft) }
local ready = false

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS pepper_chat_mutes (
            identifier VARCHAR(80) NOT NULL PRIMARY KEY,
            name VARCHAR(64) NOT NULL DEFAULT '',
            reason VARCHAR(160) NOT NULL DEFAULT '',
            muted_by VARCHAR(64) NOT NULL DEFAULT '',
            expires_at BIGINT NULL,
            created_at BIGINT NOT NULL
        )
    ]])
    MySQL.query.await('DELETE FROM pepper_chat_mutes WHERE expires_at IS NOT NULL AND expires_at <= ?', { os.time() })
    local rows = MySQL.query.await('SELECT identifier, name, reason, muted_by, expires_at FROM pepper_chat_mutes') or {}
    for _, row in ipairs(rows) do
        mutes[row.identifier] = {
            name = row.name,
            reason = row.reason,
            by = row.muted_by,
            expires = row.expires_at and tonumber(row.expires_at) or nil,
        }
    end
    ready = true
end)

function Chat.mutesReady()
    return ready
end

-- Eindeutige Kennung eines Spielers (Rockstar-Lizenz). Ohne Lizenz gilt die Stummschaltung nur für die Sitzung.
function Chat.identifier(source)
    return GetPlayerIdentifierByType(source, 'license')
        or GetPlayerIdentifierByType(source, 'license2')
        or ('session:' .. source)
end

-- Aktive Stummschaltung oder nil; abgelaufene werden dabei entfernt.
function Chat.getMute(identifier)
    local mute = mutes[identifier]
    if not mute then return nil end
    if mute.expires and mute.expires <= os.time() then
        mutes[identifier] = nil
        MySQL.query('DELETE FROM pepper_chat_mutes WHERE identifier = ?', { identifier })
        return nil
    end
    return mute
end

-- minutes = 0 oder nil bedeutet dauerhaft.
function Chat.setMute(identifier, name, minutes, reason, by)
    local now = os.time()
    local expires = (minutes and minutes > 0) and (now + math.floor(minutes * 60)) or nil
    mutes[identifier] = { name = name, reason = reason or '', by = by or '', expires = expires }
    -- Dauerhaft = NULL. Als eigener Befehl, weil ein nil mitten in der Parameterliste die Reihenfolge verschieben würde.
    local values = { identifier, name:sub(1, 64), (reason or ''):sub(1, 160), (by or ''):sub(1, 64), now }
    if expires then
        values[#values + 1] = expires
        MySQL.query('REPLACE INTO pepper_chat_mutes (identifier, name, reason, muted_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)', values)
    else
        MySQL.query('REPLACE INTO pepper_chat_mutes (identifier, name, reason, muted_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, NULL)', values)
    end
    return mutes[identifier]
end

function Chat.removeMute(identifier)
    local mute = Chat.getMute(identifier)
    if not mute then return nil end
    mutes[identifier] = nil
    MySQL.query('DELETE FROM pepper_chat_mutes WHERE identifier = ?', { identifier })
    return mute
end

-- Liste für das Team-Menü, neueste Ablaufzeit zuletzt.
function Chat.listMutes()
    local list = {}
    for identifier in pairs(mutes) do
        local mute = Chat.getMute(identifier)
        if mute then
            list[#list + 1] = {
                identifier = identifier,
                name = mute.name,
                reason = mute.reason,
                by = mute.by,
                expires = mute.expires,
            }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

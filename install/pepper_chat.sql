-- Pepper Chat – wird beim ersten Start automatisch angelegt. Diese Datei brauchst du nur, wenn du die Tabelle von Hand anlegen willst.
-- Pepper Chat – created automatically on first start. You only need this file if you want to create the table by hand.
CREATE TABLE IF NOT EXISTS pepper_chat_mutes (
    identifier VARCHAR(80) NOT NULL PRIMARY KEY,
    name VARCHAR(64) NOT NULL DEFAULT '',
    reason VARCHAR(160) NOT NULL DEFAULT '',
    muted_by VARCHAR(64) NOT NULL DEFAULT '',
    expires_at BIGINT NULL,
    created_at BIGINT NOT NULL
);

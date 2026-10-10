// Pepper Chat – Oberfläche: Nachrichten, Reiter, Eingabe mit Befehlsvorschlägen, Team-Werkzeuge
(() => {
    const $ = (id) => document.getElementById(id);
    const chat = $('chat'), tabsEl = $('tabs'), toolsEl = $('tools'), list = $('messages'), mutesEl = $('mutes');
    const input = $('input'), chanEl = $('chan'), countEl = $('count'), hintEl = $('hint'), sugEl = $('suggestions');
    const ctxEl = $('context'), bannerEl = $('banner');

    // Farbcodes des Standard-Chats (^0 bis ^9)
    const CODES = ['#f1f2f4', '#f44336', '#4caf50', '#ffeb3b', '#42a5f5', '#03a9f4', '#ba68c8', '#f0f0f0', '#ff7043', '#9e9e9e'];

    let cfg = {
        channels: { global: true, ooc: true, team: true }, defaultChannel: 'global', showIds: true, showTime: true,
        maxLength: 200, maxMessages: 100, fadeAfter: 12, ui: {}, banner: { enabled: true, duration: 8 },
        slowSteps: [0, 5, 10, 30, 60], muteSteps: [10, 60, 1440, 0],
    };
    // Englische Texte als Rückfall; im Spiel kommen sie aus locales/*.json
    let str = {
        tab_all: 'All', tab_ooc: 'OOC', tab_team: 'Staff', tag_ooc: 'OOC', tag_team: 'STAFF',
        placeholder_global: 'Message to everyone', placeholder_ooc: 'Out-of-character message',
        placeholder_team: 'Message to the staff', placeholder_announce: 'Announcement to everyone',
        hint: 'Enter: send · Esc: close · Tab: complete command', tool_clear: 'Clear chat', tool_slow: 'Slow mode',
        tool_announce: 'Announcement', tool_mutes: 'Muted players', off: 'off', ctx_mute: 'Mute: {duration}',
        ctx_delete: 'Delete message', perm: 'permanent', minutes: '{n} min', hours: '{n} h', mutes_title: 'Muted players',
        mutes_empty: 'Nobody is muted.', mutes_unmute: 'Unmute', mutes_until: 'until {time}', mutes_by: 'by {name}',
        close: 'Close', announcement: 'Announcement',
    };

    const state = { open: false, staff: false, slow: 0, tab: 'all', announce: false, visible: true };
    const entries = [];
    const suggestions = new Map();
    const hiddenSuggestions = new Set();
    const templates = {};
    const history = [];
    let historyIndex = -1, sugIndex = 0, sugMatches = [], idleTimer = null, bannerTimer = null, swallowUntil = 0, stick = true;

    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => resource
        ? fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null)
        : Promise.resolve(null);

    const t = (key, vars) => (str[key] || key).replace(/\{(\w+)\}/g, (m, k) => (vars && vars[k] != null ? vars[k] : m));
    const el = (tag, cls, text) => {
        const node = document.createElement(tag);
        if (cls) node.className = cls;
        if (text != null) node.textContent = text;
        return node;
    };
    const clock = () => new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
    const duration = (minutes) => !minutes ? t('perm') : minutes % 60 === 0 ? t('hours', { n: minutes / 60 }) : t('minutes', { n: minutes });

    // ------------------------------------------------------------------------------------------ Sichtbarkeit

    function wake() {
        chat.classList.remove('idle');
        clearTimeout(idleTimer);
        if (!state.open && cfg.fadeAfter > 0) idleTimer = setTimeout(() => chat.classList.add('idle'), cfg.fadeAfter * 1000);
    }

    function scrollDown(force) {
        if (force || stick || !state.open) list.scrollTop = list.scrollHeight;
    }
    list.addEventListener('scroll', () => { stick = list.scrollHeight - list.scrollTop - list.clientHeight < 24; });

    // ------------------------------------------------------------------------------------------ Nachrichten

    const visibleIn = (ch, tab) => tab === 'all' || ch === tab || ch === 'ann';

    function push(node, ch) {
        node.dataset.ch = ch;
        node.classList.toggle('filtered', !visibleIn(ch, state.tab));
        list.appendChild(node);
        entries.push(node);
        while (entries.length > cfg.maxMessages) entries.shift().remove();
        if (node.classList.contains('filtered') && (ch === 'ooc' || ch === 'team')) {
            const tab = tabsEl.querySelector(`[data-tab="${ch}"]`);
            if (tab) tab.classList.add('unread');
        }
        scrollDown();
        wake();
    }

    function timeSpan(node) {
        if (cfg.showTime) node.appendChild(el('span', 'time', clock()));
    }

    // Text mit ^0–^9 in farbige Abschnitte zerlegen (als Textknoten, nie als HTML).
    function appendColored(parent, text, base) {
        const clean = String(text).replace(/~(?:[a-z]|HUD_COLOUR_\w+|BLIP_\w+|INPUT_\w+)~/gi, '');
        const parts = clean.split(/\^([0-9])/);
        let color = base || null;
        for (let i = 0; i < parts.length; i++) {
            if (i % 2 === 1) { color = CODES[Number(parts[i])]; continue; }
            if (!parts[i]) continue;
            const span = el('span', null, parts[i]);
            if (color) span.style.color = color;
            parent.appendChild(span);
        }
    }

    function addPlayerMessage(m) {
        const node = el('div', 'msg');
        node.dataset.id = m.id;
        timeSpan(node);
        if (m.channel === 'ooc') node.appendChild(el('span', 'tag', t('tag_ooc')));
        if (m.channel === 'team') node.appendChild(el('span', 'tag team', t('tag_team')));
        if (m.badge) {
            const badge = el('span', 'badge', m.badge.label);
            if (/^#[0-9a-f]{3,8}$/i.test(m.badge.color || '')) badge.style.setProperty('--badge', m.badge.color);
            node.appendChild(badge);
        }
        node.appendChild(el('span', 'name', m.name));
        if (cfg.showIds && m.source > 0) node.appendChild(el('span', 'id', '#' + m.source));
        node.appendChild(el('span', 'sep', ':'));
        node.appendChild(el('span', 'text', m.text));
        if (m.source > 0) {
            node._meta = { id: m.id, name: m.name, source: m.source };
            node.classList.add('player');
        }
        push(node, m.channel);
    }

    function addSystem(text, kind) {
        const node = el('div', 'msg sys' + (kind && kind !== 'info' ? ' ' + kind : ''));
        timeSpan(node);
        appendColored(node, text);
        push(node, 'sys');
    }

    const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const colorHtml = (s) => {
        const parts = escapeHtml(s).split(/\^([0-9])/);
        let out = '', open = false;
        for (let i = 0; i < parts.length; i++) {
            if (i % 2 === 1) { out += (open ? '</span>' : '') + `<span style="color:${CODES[Number(parts[i])]}">`; open = true; } else out += parts[i];
        }
        return out + (open ? '</span>' : '');
    };

    // Nachrichten anderer Ressourcen im Format des Standard-Chats (chat:addMessage)
    function addLegacy(m) {
        if (m == null) return;
        if (typeof m === 'string') m = { args: [m] };
        const args = (Array.isArray(m.args) ? m.args : []).map((a) => String(a));
        const node = el('div', 'msg sys');
        const rgb = Array.isArray(m.color) && m.color.length >= 3 ? `rgb(${m.color.slice(0, 3).map((n) => Number(n) || 0).join(',')})` : null;
        const template = m.template || (m.templateId && templates[m.templateId]);
        if (template) {
            // Vorlagen stammen von Server-Ressourcen (wie beim Standard-Chat); die Platzhalter werden maskiert eingesetzt.
            node.innerHTML = String(template).replace(/\{(\d+)\}/g, (_, i) => colorHtml(args[Number(i)] ?? ''));
        } else {
            timeSpan(node);
            if (args.length >= 2) {
                const name = el('span', 'name');
                appendColored(name, args[0], rgb);
                node.appendChild(name);
                node.appendChild(el('span', 'sep', ':'));
                appendColored(node, args.slice(1).join(' '));
            } else if (args.length === 1) {
                appendColored(node, args[0], rgb);
            } else {
                return;
            }
        }
        node.style.color = '#f1f2f4';
        push(node, 'sys');
    }

    function addAnnouncement(text) {
        const node = el('div', 'msg ann');
        timeSpan(node);
        node.appendChild(el('span', 'tag ann', t('announcement')));
        node.appendChild(el('span', 'text', text));
        push(node, 'ann');
        if (cfg.banner && cfg.banner.enabled) {
            $('banner-title').textContent = t('announcement');
            $('banner-text').textContent = text;
            bannerEl.classList.remove('leaving');
            bannerEl.hidden = false;
            clearTimeout(bannerTimer);
            bannerTimer = setTimeout(() => {
                bannerEl.classList.add('leaving');
                setTimeout(() => { bannerEl.hidden = true; }, 320);
            }, (cfg.banner.duration || 8) * 1000);
        }
    }

    function removeMessage(id) {
        const index = entries.findIndex((n) => n.dataset.id === String(id));
        if (index >= 0) entries.splice(index, 1)[0].remove();
    }

    function clearAll() {
        entries.splice(0).forEach((n) => n.remove());
    }

    // ------------------------------------------------------------------------------------------ Reiter + Werkzeuge

    function channelOf(tab) {
        if (tab !== 'all') return tab;
        if (cfg.channels[cfg.defaultChannel]) return cfg.defaultChannel;
        return cfg.channels.global ? 'global' : 'ooc';
    }

    function setTab(tab) {
        state.tab = tab;
        for (const button of tabsEl.children) {
            button.classList.toggle('active', button.dataset.tab === tab);
            if (button.dataset.tab === tab) button.classList.remove('unread');
        }
        for (const node of entries) node.classList.toggle('filtered', !visibleIn(node.dataset.ch, tab));
        updateInput();
        scrollDown(true);
    }

    function buildTabs() {
        const tabs = ['all'];
        if (cfg.channels.ooc) tabs.push('ooc');
        if (cfg.channels.team && state.staff) tabs.push('team');
        if (!tabs.includes(state.tab)) state.tab = 'all';
        tabsEl.textContent = '';
        for (const tab of tabs) {
            const button = el('button', 'tab' + (tab === state.tab ? ' active' : ''), t('tab_' + tab));
            button.dataset.tab = tab;
            button.addEventListener('click', () => { setTab(tab); input.focus(); });
            tabsEl.appendChild(button);
        }
    }

    function buildTools() {
        toolsEl.textContent = '';
        toolsEl.hidden = !state.staff;
        if (!state.staff) { state.announce = false; mutesEl.hidden = true; return; }

        const tool = (label, onClick, active) => {
            const button = el('button', 'tool' + (active ? ' active' : ''), label);
            button.addEventListener('click', () => { onClick(); input.focus(); });
            toolsEl.appendChild(button);
        };
        tool(t('tool_announce'), () => { state.announce = !state.announce; buildTools(); updateInput(); }, state.announce);
        tool(`${t('tool_slow')}: ${state.slow > 0 ? state.slow + ' s' : t('off')}`, () => {
            const steps = cfg.slowSteps && cfg.slowSteps.length ? cfg.slowSteps : [0, 10];
            const next = steps[(steps.indexOf(state.slow) + 1) % steps.length];
            post('staff', { action: 'slow', seconds: next });
        }, state.slow > 0);
        tool(t('tool_mutes'), () => {
            if (mutesEl.hidden) post('staff', { action: 'mutes' }); else mutesEl.hidden = true;
        }, !mutesEl.hidden);
        tool(t('tool_clear'), () => post('staff', { action: 'clear' }));
    }

    function showMutes(rows) {
        mutesEl.textContent = '';
        const head = el('div', 'head');
        head.appendChild(el('span', null, t('mutes_title')));
        const close = el('button', 'tool', t('close'));
        close.addEventListener('click', () => { mutesEl.hidden = true; buildTools(); });
        head.appendChild(close);
        mutesEl.appendChild(head);
        if (!rows || !rows.length) mutesEl.appendChild(el('div', 'empty', t('mutes_empty')));
        for (const row of rows || []) {
            const line = el('div', 'row');
            const who = el('div', 'who', row.name);
            const until = row.expires
                ? t('mutes_until', { time: new Date(row.expires * 1000).toLocaleString([], { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) })
                : t('perm');
            const parts = [until, row.by ? t('mutes_by', { name: row.by }) : '', row.reason || ''].filter(Boolean);
            who.appendChild(el('small', null, parts.join(' · ')));
            line.appendChild(who);
            const button = el('button', 'tool', t('mutes_unmute'));
            button.addEventListener('click', () => {
                post('staff', { action: 'unmute', identifier: row.identifier });
                line.remove();
            });
            line.appendChild(button);
            mutesEl.appendChild(line);
        }
        mutesEl.hidden = false;
        buildTools();
    }

    // Rechtsklick auf eine Spielernachricht (nur Team)
    function openContext(event, meta) {
        ctxEl.textContent = '';
        ctxEl.appendChild(el('div', 'head', `${meta.name} #${meta.source}`));
        for (const minutes of cfg.muteSteps || []) {
            const button = el('button', null, t('ctx_mute', { duration: duration(minutes) }));
            button.addEventListener('click', () => { post('staff', { action: 'mute', id: meta.id, minutes }); closeContext(); });
            ctxEl.appendChild(button);
        }
        const remove = el('button', 'danger', t('ctx_delete'));
        remove.addEventListener('click', () => { post('staff', { action: 'delete', id: meta.id }); closeContext(); });
        ctxEl.appendChild(remove);
        ctxEl.hidden = false;
        const rect = ctxEl.getBoundingClientRect();
        ctxEl.style.left = Math.min(event.clientX, window.innerWidth - rect.width - 8) + 'px';
        ctxEl.style.top = Math.min(event.clientY, window.innerHeight - rect.height - 8) + 'px';
    }
    function closeContext() { ctxEl.hidden = true; }

    list.addEventListener('contextmenu', (event) => {
        event.preventDefault();
        const node = event.target.closest('.msg.player');
        if (!state.open || !state.staff || !node || !node._meta) return closeContext();
        openContext(event, node._meta);
    });
    document.addEventListener('click', (event) => { if (!ctxEl.contains(event.target)) closeContext(); });

    function markClickable() {
        chat.classList.toggle('staff', state.staff);
        for (const node of entries) node.classList.toggle('clickable', state.staff && node.classList.contains('player'));
    }

    // ------------------------------------------------------------------------------------------ Eingabe

    function updateInput() {
        const isCommand = input.value.startsWith('/');
        const channel = channelOf(state.tab);
        const announcing = state.announce && !isCommand;
        chanEl.className = 'chan' + (announcing ? ' ann' : channel === 'ooc' ? ' ooc' : channel === 'team' ? ' team' : '');
        chanEl.textContent = announcing ? t('announcement') : channel === 'ooc' ? t('tag_ooc') : channel === 'team' ? t('tag_team') : t('tab_all');
        input.placeholder = announcing ? t('placeholder_announce') : t('placeholder_' + channel);
        input.maxLength = cfg.maxLength;
        const left = cfg.maxLength - input.value.length;
        countEl.textContent = left;
        countEl.classList.toggle('warn', left <= 20);
        updateSuggestions();
    }

    function updateSuggestions() {
        const value = input.value;
        sugMatches = [];
        if (value.startsWith('/')) {
            const words = value.split(' ');
            const typed = words[0].toLowerCase();
            for (const [name, entry] of suggestions) {
                if (hiddenSuggestions.has(name)) continue;
                if (words.length === 1 ? name.startsWith(typed) : name === typed) sugMatches.push(entry);
            }
            sugMatches.sort((a, b) => a.name.localeCompare(b.name));
            sugMatches = sugMatches.slice(0, 6);
        }
        sugIndex = Math.min(sugIndex, Math.max(0, sugMatches.length - 1));
        sugEl.textContent = '';
        sugEl.hidden = sugMatches.length === 0;
        const current = value.split(' ').length - 2;
        sugMatches.forEach((entry, index) => {
            const row = el('div', 'sug' + (index === sugIndex ? ' active' : ''));
            row.appendChild(el('b', null, entry.name));
            (entry.params || []).forEach((p, i) => row.appendChild(el('span', 'param' + (i === current ? ' current' : ''), `[${p.name}]`)));
            const help = (entry.params && entry.params[current] && entry.params[current].help) || entry.help;
            if (help) row.appendChild(el('span', 'help', help));
            row.addEventListener('click', () => { complete(entry); input.focus(); });
            sugEl.appendChild(row);
        });
    }

    function complete(entry) {
        if (!entry) return;
        if (input.value.split(' ').length === 1) input.value = entry.name + ' ';
        updateInput();
    }

    function openChat() {
        state.open = true;
        stick = true;
        chat.classList.add('open');
        wake();
        markClickable();
        input.value = '';
        historyIndex = -1;
        sugIndex = 0;
        updateInput();
        swallowUntil = Date.now() + 120; // die Taste, die den Chat öffnet, soll nicht im Feld landen
        input.focus();
        scrollDown(true);
    }

    function closeChat(notify) {
        if (!state.open) return;
        state.open = false;
        chat.classList.remove('open');
        closeContext();
        mutesEl.hidden = true;
        sugEl.hidden = true;
        input.blur();
        scrollDown(true);
        wake();
        if (notify) post('close');
    }

    function submit() {
        const text = input.value.trim();
        if (!text) return closeChat(true);
        if (history[0] !== text) history.unshift(text);
        if (history.length > 30) history.pop();
        const announce = state.announce && !text.startsWith('/');
        post('submit', { text, channel: channelOf(state.tab), announce });
        if (announce) { state.announce = false; buildTools(); }
        closeChat(false);
    }

    input.addEventListener('beforeinput', (event) => {
        if (Date.now() < swallowUntil && event.data && event.data.length === 1) event.preventDefault();
    });
    input.addEventListener('input', () => { sugIndex = 0; historyIndex = -1; updateInput(); });

    input.addEventListener('keydown', (event) => {
        const key = event.key;
        if (key === 'Enter') { event.preventDefault(); submit(); }
        else if (key === 'Escape') {
            event.preventDefault();
            if (!ctxEl.hidden) closeContext();
            else if (!mutesEl.hidden) { mutesEl.hidden = true; buildTools(); }
            else closeChat(true);
        } else if (key === 'Tab') {
            event.preventDefault();
            if (sugMatches.length) complete(sugMatches[sugIndex]);
            else {
                const tabs = [...tabsEl.children].map((b) => b.dataset.tab);
                setTab(tabs[(tabs.indexOf(state.tab) + 1) % tabs.length]);
            }
        } else if (key === 'ArrowUp' || key === 'ArrowDown') {
            event.preventDefault();
            const step = key === 'ArrowUp' ? 1 : -1;
            if (sugMatches.length > 1) {
                sugIndex = (sugIndex - step + sugMatches.length) % sugMatches.length;
                updateSuggestions();
            } else if (history.length) {
                historyIndex = Math.max(-1, Math.min(history.length - 1, historyIndex + step));
                input.value = historyIndex >= 0 ? history[historyIndex] : '';
                updateInput();
            }
        } else if (key === 'PageUp' || key === 'PageDown') {
            event.preventDefault();
            list.scrollTop += (key === 'PageUp' ? -1 : 1) * list.clientHeight * 0.8;
        }
    });

    // Klick ins Leere hält den Fokus im Eingabefeld
    document.addEventListener('mouseup', () => { if (state.open && document.activeElement !== input && !window.getSelection().toString()) input.focus(); });

    // ------------------------------------------------------------------------------------------ Vorschläge

    function addSuggestions(rows, overwrite) {
        for (const row of rows || []) {
            if (!row || typeof row.name !== 'string') continue;
            const name = (row.name.startsWith('/') ? row.name : '/' + row.name).toLowerCase();
            const existing = suggestions.get(name);
            const hasInfo = !!row.help || (Array.isArray(row.params) && row.params.length > 0);
            if (existing && !overwrite && !hasInfo) continue;
            suggestions.set(name, { name, help: row.help || '', params: Array.isArray(row.params) ? row.params.map((p) => ({ name: String((p && p.name) || ''), help: (p && p.help) || '' })) : [] });
        }
    }

    // ------------------------------------------------------------------------------------------ Einstellungen

    function applyConfig(config, strings) {
        if (config) cfg = Object.assign(cfg, config);
        if (strings) str = Object.assign(str, strings);
        const ui = cfg.ui || {};
        const root = document.documentElement.style;
        if (Number(ui.scale) > 0) root.setProperty('--scale', Number(ui.scale));
        if (Number(ui.left) >= 0) chat.style.setProperty('--left', Number(ui.left) + '%');
        if (Number(ui.top) >= 0) chat.style.setProperty('--top', Number(ui.top) + '%');
        if (Number(ui.width) > 0) chat.style.setProperty('--width', Number(ui.width) + 'rem');
        if (Number(ui.height) > 0) chat.style.setProperty('--height', Number(ui.height) + 'rem');
        if (/^#[0-9a-f]{3,8}$/i.test(ui.accent || '')) chat.style.setProperty('--accent', ui.accent);
        hintEl.textContent = t('hint');
        buildTabs();
        buildTools();
        updateInput();
    }

    const handlers = {
        open: () => openChat(),
        close: () => closeChat(false),
        message: (m) => { addPlayerMessage(m); markClickable(); },
        system: (d) => addSystem(d.text, d.kind),
        legacy: (m) => addLegacy(m),
        announce: (d) => addAnnouncement(d.text),
        delete: (d) => removeMessage(d.id),
        clear: () => clearAll(),
        slow: (d) => { state.slow = Number(d.seconds) || 0; buildTools(); },
        mutes: (d) => showMutes(d.list),
        state: (s) => { state.staff = !!s.staff; state.slow = Number(s.slow) || 0; buildTabs(); buildTools(); markClickable(); updateInput(); },
        suggestions: (d) => { addSuggestions(d.list, d.overwrite); if (state.open) updateSuggestions(); },
        hideSuggestions: (d) => (d.names || []).forEach((n) => hiddenSuggestions.add(String(n).toLowerCase())),
        removeSuggestion: (d) => suggestions.delete(String(d.name || '').toLowerCase()),
        template: (d) => { if (d && d.id) templates[d.id] = String(d.html || ''); },
        visible: (d) => { state.visible = d.value !== false; chat.classList.toggle('off', !state.visible); },
    };

    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        const handler = handlers[msg.action];
        if (handler) handler(msg.data || {});
    });

    if (resource) {
        post('ready').then((res) => applyConfig(res && res.config, res && res.strings));
    } else {
        // Vorschau im Browser (ohne FiveM): ?demo zeigt Beispielnachrichten, ?staff das Team-Menü
        applyConfig(null, null);
        const query = new URLSearchParams(location.search);
        document.body.style.background = '#3b4a5a';
        if (query.has('staff')) handlers.state({ staff: true, slow: 0 });
        addSuggestions([{ name: '/ooc', help: 'Write out of character', params: [{ name: 'text' }] }, { name: '/me', help: '' }, { name: '/chatmute', help: 'Mute a player in chat', params: [{ name: 'id' }, { name: 'minutes' }, { name: 'reason' }] }], true);
        if (query.has('demo')) {
            addSystem('Welcome to the server.');
            addPlayerMessage({ id: 1, channel: 'global', source: 12, name: 'Marco Rossi', text: 'Anyone at Legion Square?' });
            addPlayerMessage({ id: 2, channel: 'ooc', source: 7, name: 'Lena Fischer', text: 'brb, 5 minutes' });
            addPlayerMessage({ id: 3, channel: 'global', source: 3, name: 'Patrick', badge: { label: 'Admin', color: '#E5484D' }, text: 'Restart at 18:00, please park your vehicles.' });
            addLegacy({ color: [255, 196, 107], args: ['* Marco Rossi opens the trunk'] });
            if (query.has('staff')) addPlayerMessage({ id: 4, channel: 'team', source: 5, name: 'Jules', badge: { label: 'Mod', color: '#4C9AFF' }, text: 'Ticket 14 is done.' });
            if (query.has('announce')) addAnnouncement('Server restart in 10 minutes.');
        }
        if (query.has('open')) openChat();
        window.PepperChatDemo = { handlers, openChat };
    }
})();

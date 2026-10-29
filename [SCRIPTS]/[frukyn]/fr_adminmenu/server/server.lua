local RES = GetCurrentResourceName()
local STORE_PATH = 'data/store.json'
local startedAt = os.time()


local store = {
    bans = {},
    warns = {},
    notes = {},
    admins = {},
    players = {},
    settings = { webhook = '', categories = { audit = true, bans = true, economy = true, chat = false } },
    counters = { ban = 0, warn = 0, report = 0 },
}

do
    local raw = LoadResourceFile(RES, STORE_PATH)
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for key in pairs(store) do
                if decoded[key] ~= nil then store[key] = decoded[key] end
            end
        end
    end
end

local dirty = false
local function markDirty() dirty = true end

local function flushStore()
    dirty = false
    SaveResourceFile(RES, STORE_PATH, json.encode(store), -1)
end

CreateThread(function()
    while true do
        Wait(15000)
        if dirty then flushStore() end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == RES then flushStore() end
end)


local function notify(src, message, ntype, duration)
    lib.notify(src, {
        title = Config.NotifyTitle,
        description = message,
        type = ntype or 'inform',
        position = Config.NotifyPosition,
        duration = duration,
    })
end

local function trim(str) return (tostring(str or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function fmtDuration(sec)
    sec = math.max(0, math.floor(sec))
    local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
    if d > 0 then return ('%d d %d h'):format(d, h) end
    if h > 0 then return ('%d h %d min'):format(h, m) end
    return ('%d min'):format(m)
end

local function fmtAgo(ts)
    if os.time() - ts < 60 then return 'právě teď' end
    return 'před ' .. fmtDuration(os.time() - ts)
end

local function fmtDateTime(ts) return os.date('%d.%m.%Y %H:%M', ts) end

local function toClient(target, name, payload)
    TriggerClientEvent('fr_admin:client:do', target, name, payload or {})
end

local function targetId(p)
    local id = tonumber(p.id or p.playerId)
    if id and GetPlayerName(id) then return id end
end

local function playerCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function allPlayers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = tonumber(id) end
    return out
end

-- Identifikátory ----------------------------------------------------------------
local ID_ORDER = { 'license', 'license2', 'discord', 'steam', 'fivem', 'xbl', 'live' }

local function identifierMap(src)
    local map = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local kind = id:match('^(%w+):')
        if kind then map[kind] = id end
    end
    return map
end

local function getLicense(src) return identifierMap(src).license end

local function banIdentifiers(src)
    local map, out = identifierMap(src), {}
    for _, kind in ipairs(ID_ORDER) do
        if map[kind] then out[#out + 1] = map[kind] end
    end
    for i = 0, GetNumPlayerTokens(src) - 1 do
        out[#out + 1] = 'token:' .. GetPlayerToken(src, i)
    end
    return out
end

local function idSet(src)
    local set = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do set[id] = true end
    return set
end

local function sendWebhook(url, title, text, color)
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'FR Admin',
        embeds = { {
            title = title,
            description = text,
            color = color or 6382847,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

local function audit(category, text)
    local settings = store.settings
    if not settings.webhook or settings.webhook == '' then return end
    if settings.categories and settings.categories[category] == false then return end
    sendWebhook(settings.webhook, 'Admin: ' .. category, text)
end

local onDuty = {}

local function isOwner(src)
    if IsPlayerAceAllowed(src, 'fradmin.owner') then return true end
    local ids = idSet(src)
    for _, id in ipairs(Config.Owners) do
        if ids[id] then return true end
    end
    return false
end

local function findAdminEntry(src)
    local ids = idSet(src)
    for _, entry in ipairs(store.admins) do
        if ids[entry.identifier] then return entry end
    end
end

-- vrací: perms (tabulka), roleKey, roleLabel
local function permsOf(src)
    local perms = {}
    if isOwner(src) then
        for _, perm in ipairs(Config.AllPerms) do perms[perm] = true end
        return perms, 'owner', 'Majitel'
    end

    local entry = findAdminEntry(src)
    if entry then
        local role = Config.Roles[entry.role]
        local source = entry.perms or (role and role.perms) or {}
        for perm, enabled in pairs(source) do
            if enabled then perms[perm] = true end
        end
        perms.use = true
        return perms, entry.role, role and role.label or 'Admin'
    end

    local any = false
    for _, perm in ipairs(Config.AllPerms) do
        if IsPlayerAceAllowed(src, 'fradmin.' .. perm) then
            perms[perm] = true
            any = true
        end
    end
    if any then perms.use = true end
    return perms, any and 'ace' or 'player', any and 'Admin' or 'Hráč'
end

local function hasPerm(src, perm)
    local perms = permsOf(src)
    return perms[perm] == true
end

-- nikdo kromě majitele nesmí zasahovat do majitele
local function canTarget(actor, target)
    if actor == target then return true end
    return not isOwner(target) or isOwner(actor)
end

exports('hasPermission', hasPerm)

local function forEachAdmin(fn)
    for _, id in ipairs(allPlayers()) do
        if hasPerm(id, 'use') then fn(id) end
    end
end


local joinTimes = {}

local function touchPlayer(src)
    local license = getLicense(src)
    if not license then return end
    local now = os.time()
    local rec = store.players[license]
    if not rec then
        rec = { first = now, playtime = 0 }
        store.players[license] = rec
    end
    rec.name, rec.last = GetPlayerName(src), now
    markDirty()
end

AddEventHandler('playerJoining', function()
    local src = source
    joinTimes[src] = os.time()
    touchPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local license = getLicense(src)
    if license and joinTimes[src] and store.players[license] then
        local rec = store.players[license]
        rec.playtime = (rec.playtime or 0) + (os.time() - joinTimes[src])
        rec.last = os.time()
        markDirty()
    end
    joinTimes[src], onDuty[src] = nil, nil
end)

for _, id in ipairs(allPlayers()) do
    joinTimes[id] = os.time()
    touchPlayer(id)
end

CreateThread(function()
    while true do
        Wait(60000)
        for _, id in ipairs(allPlayers()) do touchPlayer(id) end
    end
end)


local DURATIONS = { ['1h'] = 3600, ['1d'] = 86400, ['7d'] = 7 * 86400, ['30d'] = 30 * 86400 }

local function banActive(ban) return not ban.expires or ban.expires > os.time() end

local function expiresLabel(ban)
    if not ban.expires then return 'Permanentní' end
    return 'Za ' .. fmtDuration(ban.expires - os.time())
end

local function findActiveBan(idList)
    local wanted = {}
    for _, id in ipairs(idList) do wanted[id] = true end
    for _, ban in ipairs(store.bans) do
        if banActive(ban) then
            for _, id in ipairs(ban.ids) do
                if wanted[id] then return ban end
            end
        end
    end
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    local ban = findActiveBan(banIdentifiers(src))
    if ban then
        deferrals.done(('Jsi zabanován.\nDůvod: %s\nVyprší: %s\nID banu: %s'):format(ban.reason, expiresLabel(ban),
            ban.id))
    else
        deferrals.done()
    end
end)

local function warnCountFor(license)
    local n = 0
    for _, warn in ipairs(store.warns) do
        if warn.license == license then n = n + 1 end
    end
    return n
end

-- ═════════════════════════════════════════════════════════════════════════════
--  REPORTY (v paměti)
-- ═════════════════════════════════════════════════════════════════════════════
local reports = {}
local REPORT_CATEGORIES = { rdm = 'RDM / Trolling', bug = 'Herní bug', rulebreak = 'Porušení pravidel', other = 'Ostatní' }
local lastReport = {}

local function findReport(id)
    for index, report in ipairs(reports) do
        if tostring(report.id) == tostring(id) then return report, index end
    end
end

local function refreshAdmins()
    forEachAdmin(function(id) TriggerClientEvent('fr_admin:client:refresh', id) end)
end

local function createReport(src, name, title, category, manual, byAdmin)
    store.counters.report = store.counters.report + 1
    local report = {
        id = store.counters.report,
        src = src,
        name = name,
        title = title,
        category = REPORT_CATEGORIES[category] and category or 'other',
        createdAt = os.time(),
        coords = src and GetPlayerName(src) and playerCoords(src) or nil,
        manual = manual,
        by = byAdmin,
    }
    reports[#reports + 1] = report
    markDirty()
    return report
end

RegisterNetEvent('fr_admin:server:report', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local title = trim(data.title):sub(1, 200)
    if title == '' then return end

    if lastReport[src] and os.time() - lastReport[src] < 30 then
        return notify(src, 'Další report můžeš poslat až za chvíli.', 'error')
    end
    lastReport[src] = os.time()

    local report = createReport(src, GetPlayerName(src), title, data.category, false)
    notify(src, ('Tvůj report #%d byl odeslán administrátorům.'):format(report.id), 'success')
    forEachAdmin(function(id)
        notify(id, ('Nový report #%d od %s: %s'):format(report.id, GetPlayerName(src), title), 'warning', 8000)
        TriggerClientEvent('fr_admin:client:refresh', id)
    end)
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  NAPLÁNOVANÝ RESTART
-- ═════════════════════════════════════════════════════════════════════════════
local restartState = nil

local function kickEveryone(reason, except)
    for _, id in ipairs(allPlayers()) do
        if id ~= except then DropPlayer(id, reason) end
    end
end

CreateThread(function()
    while true do
        Wait(5000)
        if restartState then
            local remaining = restartState.at - os.time()
            for _, minutes in ipairs(restartState.warnMinutes) do
                if not restartState.warned[minutes] and remaining <= minutes * 60 then
                    restartState.warned[minutes] = true
                    local text = ('Server se restartuje za %d min.'):format(minutes)
                    if restartState.message ~= '' then text = text .. '\n' .. restartState.message end
                    lib.notify(-1,
                        {
                            title = 'Restart serveru',
                            description = text,
                            type = 'warning',
                            duration = 12000,
                            position =
                                Config.NotifyPosition
                        })
                end
            end
            if remaining <= 0 then
                restartState = nil
                kickEveryone(Config.RestartKickReason)
                Wait(3000)
                ExecuteCommand(Config.ShutdownCommand)
            end
        end
    end
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  DATA PRO UI
-- ═════════════════════════════════════════════════════════════════════════════
local function buildDashboard()
    local cutoff = os.time() - 86400
    local connected, newPlayers = 0, 0
    for _, rec in pairs(store.players) do
        if (rec.last or 0) >= cutoff then connected = connected + 1 end
        if (rec.first or 0) >= cutoff then newPlayers = newPlayers + 1 end
    end

    local activeBans, bans24h = 0, 0
    for _, ban in ipairs(store.bans) do
        if banActive(ban) then activeBans = activeBans + 1 end
        if ban.created >= cutoff then bans24h = bans24h + 1 end
    end

    local admins = 0
    for id in pairs(onDuty) do
        if GetPlayerName(id) then admins = admins + 1 end
    end

    return {
        online = #GetPlayers(),
        max = GetConvarInt('sv_maxclients', 48),
        activeAdmins = admins,
        pendingReports = #reports,
        status = 'Online',
        uptime = fmtDuration(os.time() - startedAt),
        connected24h = connected,
        new24h = newPlayers,
        activeBans = activeBans,
        activeWarns = #store.warns,
        bans24h = bans24h,
        restartIn = restartState and math.max(0, restartState.at - os.time()) or nil,
    }
end

local function buildPlayers()
    local list = {}
    for _, src in ipairs(allPlayers()) do
        local info = Bridge.getInfo(src) or {}
        local license = getLicense(src)
        local _, _, roleLabel = permsOf(src)
        local isAdmin = hasPerm(src, 'use')
        list[#list + 1] = {
            id = src,
            name = GetPlayerName(src),
            charName = info.charName,
            group = info.group or (isAdmin and roleLabel or 'player'),
            ping = GetPlayerPing(src),
            phone = info.phone,
            states = info.states,
            isAdmin = isAdmin,
            whitelisted = false,
            hasNote = license ~= nil and store.notes[license] ~= nil,
            hasWarn = license ~= nil and warnCountFor(license) > 0,
        }
    end
    return list
end

local function buildBans()
    local list = {}
    for i = #store.bans, 1, -1 do
        local ban = store.bans[i]
        if banActive(ban) then
            list[#list + 1] = {
                id = ban.id,
                name = ban.name,
                identifier = ban.ids[1] or '–',
                reason = ban.reason,
                createdLabel = os.date('%d.%m. %H:%M', ban.created),
                expiresLabel = expiresLabel(ban),
                permanent = ban.expires == nil,
                admin = ban.admin,
            }
        end
    end
    return list
end

local function buildWarns()
    local list, perLicense = {}, {}
    for _, warn in ipairs(store.warns) do
        perLicense[warn.license] = (perLicense[warn.license] or 0) + 1
        list[#list + 1] = {
            id = warn.id,
            name = warn.name,
            reason = warn.reason,
            index = perLicense[warn.license],
            whenLabel = fmtDateTime(warn.at),
            admin = warn.admin,
        }
    end
    return list
end

local function buildReports()
    local list = {}
    for i = #reports, 1, -1 do
        local report = reports[i]
        local online = report.src and GetPlayerName(report.src)
        list[#list + 1] = {
            id = report.id,
            title = report.title,
            categoryLabel = REPORT_CATEGORIES[report.category],
            playerName = report.name,
            playerId = online and report.src or nil,
            whenLabel = fmtAgo(report.createdAt),
            assignedTo = report.assignedTo,
        }
    end
    return list
end

local function buildAdmins()
    local list = {}
    for _, id in ipairs(Config.Owners) do
        list[#list + 1] = { name = 'Owner', identifier = id, role = 'owner', roleLabel = 'Majitel', protected = true }
    end
    for _, entry in ipairs(store.admins) do
        local role = Config.Roles[entry.role]
        list[#list + 1] = {
            name = entry.name,
            identifier = entry.identifier,
            role = entry.role,
            roleLabel = role and role.label or entry.role,
            perms = entry.perms or (role and role.perms) or {},
        }
    end
    return list
end

local function buildPayload(src)
    local perms, _, roleLabel = permsOf(src)
    local data = {
        me = { name = GetPlayerName(src), roleLabel = roleLabel, perms = perms, onDuty = onDuty[src] == true },
        dashboard = buildDashboard(),
    }
    if perms.players then data.players = buildPlayers() end
    if perms.ban then data.bans, data.warns = buildBans(), buildWarns() end
    if perms.use then data.reports = buildReports() end
    if perms.staffmanage then data.admins = buildAdmins() end
    if perms.server then data.settings = store.settings end
    return data
end

lib.callback.register('fr_admin:open', function(src)
    if not hasPerm(src, 'use') then
        notify(src, 'Nemáš oprávnění otevřít admin menu.', 'error')
        return nil
    end
    return buildPayload(src)
end)

lib.callback.register('fr_admin:requestData', function(src)
    if not hasPerm(src, 'use') then return nil end
    return buildPayload(src)
end)

lib.callback.register('fr_admin:getPlayerDetail', function(src, rawId)
    if not hasPerm(src, 'players') then return nil end
    local target = targetId({ id = rawId })
    if not target then return nil end

    local license = getLicense(target)
    local rec = license and store.players[license] or {}
    local session = os.time() - (joinTimes[target] or os.time())
    local map = identifierMap(target)

    local ipPrefix = (GetPlayerEndpoint(target) or ''):match('^(%d+%.%d+)')
    local ip = ipPrefix and (ipPrefix .. '.xx.xx') or ''
    local identifiers = {
        { label = 'Server ID', value = tostring(target) },
        { label = 'Username', value = GetPlayerName(target) },
        { label = 'Steam', value = map.steam or '–' },
        { label = 'Fivem', value = map.fivem or '–' },
        { label = 'License', value = map.license or '–' },
        { label = 'Discord', value = map.discord or '–' },
        { label = 'IP', value = ip ~= '' and ip or '–' },
    }

    local warns, index = {}, 0
    for _, warn in ipairs(store.warns) do
        if warn.license == license then
            index = index + 1
            warns[#warns + 1] = {
                index = index,
                reason = warn.reason,
                admin = warn.admin,
                whenLabel = fmtDateTime(warn
                    .at)
            }
        end
    end

    local note = license and store.notes[license]
    return {
        sessionTime = fmtDuration(session),
        playTime = fmtDuration((rec.playtime or 0) + session),
        joinDate = rec.first and os.date('%d.%m.%Y', rec.first) or '–',
        hasWl = false,
        identifiers = identifiers,
        note = note and note.text or '',
        warns = warns,
    }
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  AKCE
-- ═════════════════════════════════════════════════════════════════════════════
local Actions = {}

-- A(název, oprávnění, funkce(src, payload) -> ok, zpráva, { notifyOk = bool, cat = 'audit'|'bans'|'economy'|'chat', silent = bool })
local function A(name, perm, fn, opts)
    Actions[name] = { perm = perm, fn = fn, opts = opts or {} }
end

-- ── Vlastní postava (efekt běží na klientovi, oznámení hlásí klient) ──────────
for _, name in ipairs({ 'toggleNoclip', 'toggleGodmode', 'toggleInvis' }) do
    A(name, 'use', function(src)
        toClient(src, name)
        return true
    end, { silent = true })
end

A('reviveSelf', 'use', function(src)
    toClient(src, 'heal')
    return true
end)

for _, name in ipairs({ 'repairVeh', 'refuelVeh', 'maxTuneVeh', 'deleteVeh' }) do
    A(name, 'vehicles', function(src)
        toClient(src, name)
        return true
    end)
end

A('tpWaypoint', 'use', function(src)
    toClient(src, 'tpWaypoint')
    return true
end)

A('tpCoords', 'use', function(src, p)
    local x, y, z = tostring(p.coords or ''):match('(-?%d+%.?%d*)%s*[,; ]%s*(-?%d+%.?%d*)%s*[,; ]%s*(-?%d+%.?%d*)')
    if not x then return false, 'Neplatné souřadnice. Použij formát: x, y, z' end
    toClient(src, 'teleport', { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
    return true
end)

A('tpLegion', 'use', function(src)
    local c = Config.Teleports.legion
    toClient(src, 'teleport', { x = c.x, y = c.y, z = c.z })
    return true
end)

A('tpSandy', 'use', function(src)
    local c = Config.Teleports.sandy
    toClient(src, 'teleport', { x = c.x, y = c.y, z = c.z })
    return true
end)

-- ── Správa hráče ──────────────────────────────────────────────────────────────
A('healPlayer', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš oživit.' end
    Bridge.revive(target)
    toClient(target, 'heal')
    return true, ('Hráč %s byl oživen.'):format(GetPlayerName(target))
end, { notifyOk = true })

local function teleportAdminTo(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'K tomuto hráči se nemůžeš teleportovat.' end
    local c = playerCoords(target)
    toClient(src, 'teleport', { x = c.x, y = c.y, z = c.z })
    return true, ('Teleportováno k hráči %s.'):format(GetPlayerName(target))
end
A('gotoPlayer', 'players', teleportAdminTo, { notifyOk = true })
A('gotoReportPlayer', 'use', teleportAdminTo, { notifyOk = true })

A('bringPlayer', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš přitáhnout.' end
    local c = playerCoords(src)
    toClient(target, 'teleport', { x = c.x, y = c.y, z = c.z })
    return true, ('Hráč %s byl přitažen k tobě.'):format(GetPlayerName(target))
end, { notifyOk = true })

A('spectatePlayer', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš sledovat.' end
    if target == src then return false, 'Sám sebe sledovat nemůžeš.' end
    local c = playerCoords(target)
    toClient(src, 'spectate', { target = target, x = c.x, y = c.y, z = c.z })
    return true
end, { silent = true })

A('screenshotPlayer', 'players', function(src, p)
    if GetResourceState('screenshot-basic') ~= 'started' then
        return false, 'Pro screenshoty musí běžet resource screenshot-basic.'
    end
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Od tohoto hráče nemůžeš pořídit screenshot.' end
    exports['screenshot-basic']:requestClientScreenshot(target, { encoding = 'jpg', quality = 0.4 }, function(err, data)
        if err or not data then return notify(src, 'Screenshot se nepodařilo pořídit.', 'error') end
        TriggerClientEvent('fr_admin:client:showScreenshot', src, data, GetPlayerName(target))
    end)
    return true, 'Screenshot se pořizuje…'
end, { notifyOk = true })

A('toggleFreeze', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš zamknout.' end
    toClient(target, 'freeze', { state = p.state == true })
    return true
end, { silent = true })

A('forceCommand', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Na tohoto hráče nemůžeš vynutit příkaz.' end
    local command = tostring(p.command or '')
    if not Config.AllowedForceCommands[command] then
        return false,
            'Tento příkaz nelze vynutit (viz Config.AllowedForceCommands).'
    end
    toClient(target, 'forceCommand', { command = command })
    return true
end, { silent = true })

A('forceLogout', 'players', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš vyhodit.' end
    DropPlayer(target, ('Byl jsi odpojen administrátorem %s.'):format(GetPlayerName(src)))
    return true
end)

A('saveStaffNote', 'players', function(src, p)
    local target = targetId(p)
    local license = target and getLicense(target)
    if not license then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Poznámku k tomuto hráči nemůžeš upravit.' end
    local text = trim(p.note):sub(1, 500)
    if text == '' then
        store.notes[license] = nil
    else
        store.notes[license] = { text = text, by = GetPlayerName(src), at = os.time() }
    end
    markDirty()
    return true
end)

-- ── Bany a varování ───────────────────────────────────────────────────────────
A('addWarn', 'ban', function(src, p)
    local target = targetId(p)
    local license = target and getLicense(target)
    if not license then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Tomuto hráči nemůžeš udělit varování.' end
    local reason = trim(p.reason):sub(1, 200)
    if reason == '' then return false, 'Zadej důvod varování.' end

    store.counters.warn = store.counters.warn + 1
    store.warns[#store.warns + 1] = {
        id = 'W' .. store.counters.warn,
        license = license,
        name = GetPlayerName(target),
        reason = reason,
        admin = GetPlayerName(src),
        at = os.time(),
    }
    markDirty()
    notify(target, 'Obdržel jsi varování: ' .. reason, 'warning', 10000)

    if warnCountFor(license) >= Config.MaxWarns then
        notify(src, ('%s má už %d varování – zvaž ban.'):format(GetPlayerName(target), Config.MaxWarns), 'warning', 8000)
    end
    return true
end, { cat = 'bans' })

A('clearWarn', 'ban', function(_, p)
    for index, warn in ipairs(store.warns) do
        if warn.id == tostring(p.id) then
            table.remove(store.warns, index)
            markDirty()
            return true
        end
    end
    return false, 'Varování nenalezeno.'
end, { cat = 'bans' })

A('banPlayer', 'ban', function(src, p)
    local reason = trim(p.reason):sub(1, 200)
    if reason == '' then return false, 'Zadej důvod banu.' end
    local duration = tostring(p.duration or 'perm')
    if duration ~= 'perm' and not DURATIONS[duration] then return false, 'Neplatná délka banu.' end

    local target = targetId(p)
    local ids, name
    if target then
        if target == src then return false, 'Nemůžeš zabanovat sám sebe.' end
        if not canTarget(src, target) then return false, 'Tohoto hráče nemůžeš zabanovat.' end
        ids, name = banIdentifiers(target), GetPlayerName(target)
    else
        local raw = trim(p.id)
        if not raw:find('^%w+:') then
            return false,
                'Hráč není online. Pro offline ban zadej identifikátor (např. license:…).'
        end
        ids, name = { raw }, raw
    end

    store.counters.ban = store.counters.ban + 1
    local ban = {
        id = 'B' .. store.counters.ban,
        name = name,
        ids = ids,
        reason = reason,
        admin = GetPlayerName(src),
        created = os.time(),
        expires = DURATIONS[duration] and (os.time() + DURATIONS[duration]) or nil,
    }
    store.bans[#store.bans + 1] = ban
    markDirty()

    if target then
        DropPlayer(target,
            ('Byl jsi zabanován.\nDůvod: %s\nVyprší: %s\nID banu: %s'):format(reason, expiresLabel(ban), ban.id))
    end
    audit('bans', ('**%s** zabanoval **%s** (%s)\nDůvod: %s'):format(ban.admin, name, duration, reason))
    return true
end, { cat = 'bans', silent = true, selfAudit = true })

A('unbanPlayer', 'ban', function(src, p)
    for index, ban in ipairs(store.bans) do
        if ban.id == tostring(p.id) then
            table.remove(store.bans, index)
            markDirty()
            audit('bans', ('**%s** odbanoval **%s** (%s)'):format(GetPlayerName(src), ban.name, ban.id))
            return true
        end
    end
    return false, 'Ban nenalezen.'
end, { cat = 'bans', silent = true, selfAudit = true })

A('editBan', 'ban', function(_, p)
    local reason = trim(p.reason):sub(1, 200)
    if reason == '' then return false, 'Zadej důvod.' end
    for _, ban in ipairs(store.bans) do
        if ban.id == tostring(p.id) then
            ban.reason = reason
            markDirty()
            return true
        end
    end
    return false, 'Ban nenalezen.'
end, { cat = 'bans', silent = true })

-- ── Ekonomika ─────────────────────────────────────────────────────────────────
A('setPlayerMoney', 'economy', function(src, p)
    local target = targetId(p)
    if not target then return false, 'Hráč není online.' end
    if not canTarget(src, target) then return false, 'Finance tohoto hráče nemůžeš upravit.' end
    local amount = math.floor(tonumber(p.amount) or 0)
    if amount <= 0 or amount > 1000000000 then return false, 'Neplatná částka.' end
    local account = ({ cash = 'cash', bank = 'bank', black = 'black' })[p.account]
    if not account then return false, 'Neplatný typ účtu.' end

    local fn = p.mode == 'remove' and Bridge.removeMoney or Bridge.addMoney
    if not fn(target, account, amount) then
        return false, 'Peníze se nepodařilo upravit (framework není napojen – viz server/bridge.lua).'
    end
    audit('economy',
        ('**%s** %s hráči **%s** $%d (%s)'):format(GetPlayerName(src), p.mode == 'remove' and 'odebral' or 'přidal',
            GetPlayerName(target), amount, account))
    return true
end, { cat = 'economy', silent = true, selfAudit = true })

-- ── Vozidla ve světě (podle SPZ) ──────────────────────────────────────────────
local function findVehicleByPlate(plate)
    plate = trim(plate):upper()
    if plate == '' then return nil end
    for _, veh in ipairs(GetAllVehicles()) do
        if trim(GetVehicleNumberPlateText(veh)):upper() == plate then return veh end
    end
end

local function vehicleOp(op)
    return function(_, p)
        local veh = findVehicleByPlate(p.plate or p.id)
        if not veh then return false, 'Vozidlo není ve světě (musí být vyspawnované).' end
        local owner = NetworkGetEntityOwner(veh)
        if op == 'delete' then
            DeleteEntity(veh)
        elseif op == 'lock' then
            SetVehicleDoorsLocked(veh, p.locked and 2 or 1)
        else
            if op == 'refuel' then Entity(veh).state:set('fuel', 100.0, true) end
            TriggerClientEvent('fr_admin:client:vehicleOp', owner, NetworkGetNetworkIdFromEntity(veh), op)
        end
        return true
    end
end
A('repairVehicle', 'vehicles', vehicleOp('repair'), { silent = true })
A('refuelVehicle', 'vehicles', vehicleOp('refuel'), { silent = true })
A('deleteVehicle', 'vehicles', vehicleOp('delete'), { silent = true })
A('toggleVehicleLock', 'vehicles', vehicleOp('lock'), { silent = true })

A('gotoVehicle', 'vehicles', function(src, p)
    local veh = findVehicleByPlate(p.plate or p.id)
    if not veh then return false, 'Vozidlo není ve světě.' end
    local c = GetEntityCoords(veh)
    toClient(src, 'teleport', { x = c.x, y = c.y, z = c.z })
    return true, 'Teleportováno k vozidlu.'
end, { notifyOk = true })

-- ── Svět a server ─────────────────────────────────────────────────────────────
A('wipeVehicles', 'vehicles', function()
    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        local occupied = false
        for seat = -1, 6 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped and ped ~= 0 then
                occupied = true
                break
            end
        end
        if not occupied then
            DeleteEntity(veh)
            removed = removed + 1
        end
    end
    return true, ('Smazáno opuštěných vozidel: %d'):format(removed)
end, { notifyOk = true })

A('wipePeds', 'vehicles', function()
    local removed = 0
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) then
            DeleteEntity(ped)
            removed = removed + 1
        end
    end
    return true, ('Smazáno NPC: %d'):format(removed)
end, { notifyOk = true })

local function setTime(hour)
    return function()
        if Config.SetTime then Config.SetTime(hour) else toClient(-1, 'setTime', { hour = hour }) end
        return true, ('Čas nastaven na %02d:00.'):format(hour)
    end
end
A('setTimeNoon', 'server', setTime(12), { notifyOk = true })
A('setTimeNight', 'server', setTime(0), { notifyOk = true })

A('clearServerChat', 'chat', function()
    TriggerClientEvent('chat:clear', -1)
    return true, 'Chat byl vyčištěn.'
end, { notifyOk = true })

A('sendAnnouncement', 'chat', function(src, p)
    local message = trim(p.message):sub(1, 300)
    if message == '' then return false, 'Zpráva je prázdná.' end
    lib.notify(-1, {
        title = 'Oznámení serveru',
        description = message,
        type = 'inform',
        icon = 'bullhorn',
        duration = 12000,
        position = Config.NotifyPosition,
    })
    audit('audit', ('**%s** poslal oznámení: %s'):format(GetPlayerName(src), message))
    return true
end, { silent = true, selfAudit = true })

A('restartWarning', 'server', function()
    lib.notify(-1, {
        title = 'Restart serveru',
        description = 'Server se brzy restartuje. Dokonči prosím rozdělané aktivity.',
        type = 'warning',
        duration = 12000,
        position = Config.NotifyPosition,
    })
    return true, 'Varování o restartu bylo odesláno.'
end, { notifyOk = true })

A('kickAll', 'server', function(src)
    kickEveryone('Všichni hráči byli vyhozeni administrátorem.', src)
    return true, 'Všichni ostatní hráči byli vyhozeni.'
end, { notifyOk = true })

A('offserver', 'server', function()
    kickEveryone('Server byl vypnut administrátorem.')
    SetTimeout(3000, function() ExecuteCommand(Config.ShutdownCommand) end)
    return true, 'Server se vypíná…'
end, { notifyOk = true })

A('scheduleRestart', 'server', function(_, p)
    local delay = math.floor(tonumber(p.delay) or 0)
    if delay < 30 or delay > 2 * 86400 then return false, 'Neplatný čas restartu.' end

    local warnMinutes, warned = {}, {}
    for _, minutes in ipairs(type(p.warnMinutes) == 'table' and p.warnMinutes or {}) do
        minutes = tonumber(minutes)
        if minutes and minutes > 0 then
            warnMinutes[#warnMinutes + 1] = minutes
            if minutes * 60 >= delay then warned[minutes] = true end -- varování, které už „proběhlo“
        end
    end

    restartState = {
        at = os.time() + delay,
        warnMinutes = warnMinutes,
        warned = warned,
        message = trim(p.message):sub(1,
            200)
    }
    return true
end, { silent = true })

A('cancelScheduledRestart', 'server', function()
    restartState = nil
    return true
end, { silent = true })

-- ── Duty, admini, reporty, webhook ────────────────────────────────────────────
A('toggleAdminDuty', 'use', function(src, p)
    onDuty[src] = p.state == true or nil
    return true
end, { silent = true })

local function canGrant(src, perms)
    if isOwner(src) then return true end
    local mine = permsOf(src)
    for perm, enabled in pairs(perms) do
        if enabled and not mine[perm] then return false end
    end
    return true
end

A('addAdmin', 'staffmanage', function(src, p)
    local name, identifier = trim(p.name):sub(1, 50), trim(p.identifier)
    local role = Config.Roles[p.role]
    if name == '' or not identifier:find('^%w+:%S+$') then
        return false,
            'Zadej jméno a identifikátor ve tvaru typ:hodnota (např. license:…).'
    end
    if not role then return false, 'Neznámá role.' end
    if not canGrant(src, role.perms) then return false, 'Nemůžeš udělit práva, která sám nemáš.' end
    for _, entry in ipairs(store.admins) do
        if entry.name == name or entry.identifier == identifier then return false, 'Tento admin už existuje.' end
    end
    store.admins[#store.admins + 1] = { name = name, identifier = identifier, role = p.role }
    markDirty()
    return true
end, { cat = 'audit', silent = true })

A('removeAdmin', 'staffmanage', function(_, p)
    for index, entry in ipairs(store.admins) do
        if entry.name == tostring(p.admin) then
            table.remove(store.admins, index)
            markDirty()
            return true
        end
    end
    return false, 'Admin nenalezen.'
end, { cat = 'audit', silent = true })

A('saveAdminPermissions', 'staffmanage', function(src, p)
    if type(p.permissions) ~= 'table' then return false, 'Neplatná data.' end
    local valid = {}
    for _, perm in ipairs(Config.AllPerms) do valid[perm] = true end
    local cleaned = { use = true }
    for perm, enabled in pairs(p.permissions) do
        if valid[perm] then cleaned[perm] = enabled == true end
    end
    if not canGrant(src, cleaned) then return false, 'Nemůžeš udělit práva, která sám nemáš.' end
    for _, entry in ipairs(store.admins) do
        if entry.name == tostring(p.admin) then
            entry.perms = cleaned
            markDirty()
            return true
        end
    end
    return false, 'Admin nenalezen.'
end, { cat = 'audit', silent = true })

A('createManualReport', 'use', function(src, p)
    local title = trim(p.title):sub(1, 200)
    local ref = trim(p.playerRef):sub(1, 60)
    if title == '' or ref == '' then return false, 'Vyplň hráče i předmět reportu.' end

    local target = tonumber(ref) and GetPlayerName(tonumber(ref)) and tonumber(ref) or nil
    createReport(target, target and GetPlayerName(target) or ref, title, p.category, true, GetPlayerName(src))
    return true
end, { silent = true })

A('closeReport', 'use', function(src, p)
    local report, index = findReport(p.id)
    if not report then return false, 'Report nenalezen.' end
    table.remove(reports, index)
    if report.src and GetPlayerName(report.src) then
        notify(report.src, ('Tvůj report #%d byl uzavřen administrátorem %s.'):format(report.id, GetPlayerName(src)),
            'success')
    end
    return true
end, { silent = true })

A('gotoReportLocation', 'use', function(src, p)
    local report = findReport(p.id)
    if not report then return false, 'Report nenalezen.' end
    report.assignedTo = GetPlayerName(src)
    if report.src and GetPlayerName(report.src) then
        notify(report.src, ('Tvůj report #%d převzal %s.'):format(report.id, GetPlayerName(src)), 'inform')
    end
    if report.coords then
        toClient(src, 'teleport', { x = report.coords.x, y = report.coords.y, z = report.coords.z })
    end
    refreshAdmins()
    return true, ('Report #%d převzat.'):format(report.id)
end, { notifyOk = true })

A('sendReportChatMessage', 'use', function(src, p)
    local report = findReport(p.id)
    if not report then return false, 'Report nenalezen.' end
    local message = trim(p.message):sub(1, 300)
    if message == '' then return false, 'Zpráva je prázdná.' end
    if not (report.src and GetPlayerName(report.src)) then return false, 'Hráč už není online.' end
    notify(report.src, message, 'inform', 12000)
    return true
end, { silent = true, cat = 'chat' })

A('saveWebhookConfig', 'server', function(_, p)
    local url = trim(p.url)
    if url ~= '' and not url:find('^https://discord[app]*%.com/api/webhooks/') then
        return false, 'Webhook musí být Discord URL (https://discord.com/api/webhooks/…).'
    end
    local categories = type(p.categories) == 'table' and p.categories or {}
    store.settings = {
        webhook = url,
        categories = {
            audit = categories.audit ~= false,
            bans = categories.bans ~= false,
            economy = categories.economy ~= false,
            chat = categories.chat == true,
        },
    }
    markDirty()
    return true
end, { silent = true })

A('testWebhook', 'server', function(src)
    if store.settings.webhook == '' then return false, 'Webhook není nastaven.' end
    sendWebhook(store.settings.webhook, 'Test webhooku', ('Testovací zpráva od **%s**.'):format(GetPlayerName(src)))
    return true
end, { silent = true })

-- ═════════════════════════════════════════════════════════════════════════════
--  VSTUPNÍ BOD: všechny akce z NUI procházejí tady (ověření oprávnění na serveru)
-- ═════════════════════════════════════════════════════════════════════════════
lib.callback.register('fr_admin:execute', function(src, p)
    if type(p) ~= 'table' or type(p.action) ~= 'string' then return { ok = false } end

    local def = Actions[p.action]
    if not def then
        notify(src, 'Neznámá akce: ' .. p.action:sub(1, 40), 'error')
        return { ok = false }
    end
    if not hasPerm(src, def.perm) then
        notify(src, 'Nemáš oprávnění pro tuto akci.', 'error')
        return { ok = false }
    end

    local success, ok, message = pcall(def.fn, src, p)
    if not success then
        print(('[%s] Chyba v akci %s: %s'):format(RES, p.action, ok))
        notify(src, 'Akce selhala (chyba na serveru, viz konzole).', 'error')
        return { ok = false }
    end
    if ok == false then
        notify(src, message or 'Akce se nezdařila.', 'error')
        return { ok = false, msg = message }
    end
    if def.opts.notifyOk then notify(src, message or 'Hotovo.', 'success') end

    if not def.opts.selfAudit and p.action ~= 'toggleAdminDuty' and p.action ~= 'sendReportChatMessage' then
        audit(def.opts.cat or 'audit', ('**%s** (%d) provedl `%s`'):format(GetPlayerName(src), src, p.action))
    end
    return { ok = true }
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  STAFF CHAT
-- ═════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('fr_admin:server:staffMessage', function(message)
    local src = source
    if not hasPerm(src, 'use') then return end
    message = trim(message):sub(1, 300)
    if message == '' then return end

    local from = GetPlayerName(src)
    forEachAdmin(function(id)
        if id ~= src then TriggerClientEvent('fr_admin:client:staffChat', id, from, message) end
    end)
    audit('chat', ('**%s**: %s'):format(from, message))
end)

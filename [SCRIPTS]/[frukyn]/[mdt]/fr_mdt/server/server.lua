local Ox = require '@ox_core.lib.init'

local unitStatuses = {}

-- Automatické ověření a vytvoření databázových tabulek
local function ensureDatabase()
    local tables = {
        [[
            CREATE TABLE IF NOT EXISTS `mdt_incidents` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `title` VARCHAR(150) NOT NULL,
                `description` LONGTEXT NULL,
                `creator_id` INT NOT NULL,
                `creator_name` VARCHAR(100) NOT NULL,
                `suspects` LONGTEXT NULL,
                `officers` LONGTEXT NULL,
                `victims` LONGTEXT NULL,
                `evidence` LONGTEXT NULL,
                `total_fine` INT DEFAULT 0,
                `total_jail` INT DEFAULT 0,
                `status` VARCHAR(20) DEFAULT 'open',
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_warrants` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `suspect_id` INT NOT NULL,
                `suspect_name` VARCHAR(100) NOT NULL,
                `reason` VARCHAR(255) NOT NULL,
                `charges` LONGTEXT NULL,
                `creator_name` VARCHAR(100) NOT NULL,
                `status` VARCHAR(20) DEFAULT 'active',
                `expires_at` DATETIME NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_warrant_suspect` (`suspect_id`),
                INDEX `idx_warrant_status` (`status`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_weapons` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `serial` VARCHAR(50) NOT NULL UNIQUE,
                `model` VARCHAR(50) NOT NULL,
                `label` VARCHAR(100) NOT NULL,
                `owner_id` INT NULL,
                `owner_name` VARCHAR(100) NULL,
                `is_stolen` TINYINT(1) DEFAULT 0,
                `ballistics_notes` TEXT NULL,
                `registered_by` VARCHAR(100) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_weapon_serial` (`serial`),
                INDEX `idx_weapon_owner` (`owner_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_bolos` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `type` VARCHAR(20) NOT NULL,
                `title` VARCHAR(100) NOT NULL,
                `target_name` VARCHAR(100) NULL,
                `plate` VARCHAR(20) NULL,
                `reason` TEXT NOT NULL,
                `danger_level` VARCHAR(20) DEFAULT 'medium',
                `creator_name` VARCHAR(100) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_citizen_notes` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `charId` INT NOT NULL,
                `note` TEXT NOT NULL,
                `author_name` VARCHAR(100) NOT NULL,
                `tags` VARCHAR(255) NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_notes_char` (`charId`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_vehicle_notes` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `plate` VARCHAR(12) NOT NULL,
                `note` TEXT NOT NULL,
                `is_stolen` TINYINT(1) DEFAULT 0,
                `author_name` VARCHAR(100) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY `uniq_plate` (`plate`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_bulletins` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `title` VARCHAR(150) NOT NULL,
                `content` TEXT NOT NULL,
                `author_name` VARCHAR(100) NOT NULL,
                `is_pinned` TINYINT(1) DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_user_settings` (
                `charId` INT PRIMARY KEY,
                `callsign` VARCHAR(20) NOT NULL,
                `department` VARCHAR(50) DEFAULT 'LSPD',
                `role` VARCHAR(30) DEFAULT 'officer',
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mdt_logs` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `officer_id` INT NOT NULL,
                `officer_name` VARCHAR(100) NOT NULL,
                `action` VARCHAR(50) NOT NULL,
                `details` TEXT NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_logs_action` (`action`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    }

    for _, query in ipairs(tables) do
        MySQL.query.await(query)
    end
    print('^2[fr_mdt] Database tables verified and ready.^7')
end

CreateThread(ensureDatabase)

-- Audit logging
local function logAction(officerId, officerName, action, details)
    MySQL.insert([[
        INSERT INTO mdt_logs (officer_id, officer_name, action, details)
        VALUES (?, ?, ?, ?)
    ]], { officerId or 0, officerName or 'Systém', action, details or '' })
end

-- Pomocná robustní funkce pro zjištění frakcí/skupin hráče v ox_core
local function getPlayerGroups(src, player)
    player = player or Ox.GetPlayer(src)
    local groups = {}
    if not player then return groups end

    local charId = player.charId or (player.get and player:get('charId'))

    -- 1. Zkusíme metodu player:getGroup(name) pro známé autorizované frakce
    for jobName, _ in pairs(Config.AuthorizedJobs) do
        local ok, grade = pcall(function()
            if player.getGroup then
                return player:getGroup(jobName)
            end
        end)
        if ok and grade ~= nil then
            if type(grade) == 'table' then
                groups[jobName] = tonumber(grade.grade or grade.level or grade.rank) or 0
            else
                groups[jobName] = tonumber(grade) or 0
            end
        end
    end

    -- 2. Zkusíme přímou tabulku player.groups
    if type(player.groups) == 'table' then
        for name, grade in pairs(player.groups) do
            if groups[name] == nil then
                groups[name] = type(grade) == 'table' and (tonumber(grade.grade) or 0) or (tonumber(grade) or 0)
            end
        end
    end

    -- 3. Zkusíme metodu player:getGroups() přes pcall
    pcall(function()
        if player.getGroups then
            local res = player:getGroups()
            if type(res) == 'table' then
                for name, grade in pairs(res) do
                    if groups[name] == nil then
                        groups[name] = type(grade) == 'table' and (tonumber(grade.grade) or 0) or (tonumber(grade) or 0)
                    end
                end
            end
        end
    end)

    -- 4. StateBag (activeGroup v ox_core)
    local activeGroup = Player(src).state.activeGroup
    if activeGroup and groups[activeGroup] == nil then
        groups[activeGroup] = 0
    end

    -- 5. Databázový fallback (z tabulky character_groups) pro 100% spolehlivost
    if charId then
        local ok, dbRows = pcall(function()
            return MySQL.query.await('SELECT `name`, `grade` FROM `character_groups` WHERE `charId` = ?', { charId })
        end)
        if ok and dbRows then
            for _, row in ipairs(dbRows) do
                if groups[row.name] == nil then
                    groups[row.name] = tonumber(row.grade) or 0
                end
            end
        end
    end

    return groups
end

-- Ověření oprávnění k MDT
local function isAuthorized(src)
    local player = Ox.GetPlayer(src)
    if not player then return false, nil, nil end

    local groups = getPlayerGroups(src, player)

    for jobName, data in pairs(Config.AuthorizedJobs) do
        if groups[jobName] ~= nil and groups[jobName] >= (data.minGrade or 0) then
            return true, jobName, data
        end
    end

    -- Server admin fallback (ACE nebo ox group admin)
    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'admin') or groups['admin'] ~= nil then
        return true, 'police', Config.AuthorizedJobs['police'] or { label = 'Police Department', badge = 'LSPD', minGrade = 0 }
    end

    return false, nil, nil
end

-- Získání informací o důstojníkovi
local function getOfficerProfile(src)
    local player = Ox.GetPlayer(src)
    if not player then return nil end

    local firstName = player.firstName or (player.get and player:get('firstName')) or player.name or GetPlayerName(src)
    local lastName = player.lastName or (player.get and player:get('lastName')) or ''
    local charId = player.charId or (player.get and player:get('charId')) or src

    local setting = MySQL.single.await('SELECT callsign, department, role FROM mdt_user_settings WHERE charId = ?', { charId })
    local callsign = setting and setting.callsign or ('1-A-%s'):format(charId % 100)
    local department = setting and setting.department or 'LSPD'
    local role = setting and setting.role or 'officer'

    local _, jobName, jobData = isAuthorized(src)

    return {
        charId = charId,
        name = ('%s %s'):format(firstName, lastName),
        callsign = callsign,
        department = department,
        role = role,
        job = jobName or 'police',
        badge = jobData and jobData.badge or 'POLICE',
        status = unitStatuses[src] or '10-8'
    }
end

-- 1. Načtení dat pro hlavní Dashboard
lib.callback.register('fr_mdt:server:getDashboardData', function(source)
    local auth, job = isAuthorized(source)
    if not auth then return nil end

    local profile = getOfficerProfile(source)

    -- Roster přihlášených jednotek ve službě
    local units = {}
    for _, pid in ipairs(GetPlayers()) do
        local targetSrc = tonumber(pid)
        local tAuth, tJob, tData = isAuthorized(targetSrc)
        if tAuth then
            local tPlayer = Ox.GetPlayer(targetSrc)
            if tPlayer then
                local tFirst = tPlayer.firstName or (tPlayer.get and tPlayer:get('firstName')) or GetPlayerName(targetSrc)
                local tLast = tPlayer.lastName or (tPlayer.get and tPlayer:get('lastName')) or ''
                local tName = ('%s %s'):format(tFirst, tLast)
                local tCallsign = Player(targetSrc).state.callsign or ('1-A-%s'):format((tPlayer.charId or targetSrc) % 100)
                table.insert(units, {
                    source = targetSrc,
                    name = tName,
                    callsign = tCallsign,
                    department = tData and tData.badge or 'IZS',
                    status = unitStatuses[targetSrc] or '10-8'
                })
            end
        end
    end

    -- Aktivní zatykače
    local warrants = MySQL.query.await([[
        SELECT id, suspect_name, reason, creator_name, expires_at
        FROM mdt_warrants
        WHERE status = 'active' AND expires_at > NOW()
        ORDER BY id DESC LIMIT 5
    ]]) or {}

    -- Aktivní BOLO
    local bolos = MySQL.query.await([[
        SELECT id, type, title, target_name, plate, danger_level
        FROM mdt_bolos
        ORDER BY id DESC LIMIT 5
    ]]) or {}

    -- Nástěnka / Oznámení
    local bulletins = MySQL.query.await([[
        SELECT id, title, content, author_name, is_pinned, DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_bulletins
        ORDER BY is_pinned DESC, id DESC LIMIT 10
    ]]) or {}

    -- Aktivní dispatch hovory
    local dispatchCalls = {}
    if GetResourceState('fr_dispatch') == 'started' then
        dispatchCalls = exports['fr_dispatch']:GetActiveCalls() or {}
    end

    return {
        profile = profile,
        units = units,
        warrants = warrants,
        bolos = bolos,
        bulletins = bulletins,
        dispatchCalls = dispatchCalls,
        tenCodes = Config.TenCodes,
        divisions = Config.Divisions
    }
end)

-- 2. Vyhledávání občanů
lib.callback.register('fr_mdt:server:searchCitizens', function(source, query)
    local auth = isAuthorized(source)
    if not auth or not query or query == '' then return {} end

    local officer = getOfficerProfile(source)
    logAction(officer.charId, officer.name, 'SEARCH_CITIZEN', ('Vyhledávání: "%s"'):format(query))

    local q = ('%%%s%%'):format(query)
    local rows = MySQL.query.await([[
        SELECT c.charId, c.firstName, c.lastName, DATE_FORMAT(c.dateOfBirth, '%d.%m.%Y') as dob, c.gender, c.phoneNumber,
               (SELECT COUNT(1) FROM mdt_warrants w WHERE w.suspect_id = c.charId AND w.status = 'active') as activeWarrants
        FROM characters c
        WHERE CONCAT(c.firstName, ' ', c.lastName) LIKE ? OR c.charId = ? OR c.phoneNumber LIKE ?
        LIMIT 25
    ]], { q, tonumber(query) or -1, q }) or {}

    return rows
end)

-- 3. Detail občana (profil, registrované zbraně, vozidla, trestní rejstřík, poznámky)
lib.callback.register('fr_mdt:server:getCitizenDetail', function(source, charId)
    local auth = isAuthorized(source)
    if not auth or not charId then return nil end

    charId = tonumber(charId)

    local citizen = MySQL.single.await([[
        SELECT c.charId, c.firstName, c.lastName, DATE_FORMAT(c.dateOfBirth, '%d.%m.%Y') as dob, c.gender, c.phoneNumber
        FROM characters c
        WHERE c.charId = ? LIMIT 1
    ]], { charId })

    if not citizen then return nil end

    -- Registrovaná vozidla
    local vehicles = MySQL.query.await([[
        SELECT v.id, v.plate, v.model, v.fr_state, v.fr_impound_reason,
               COALESCE(vn.is_stolen, 0) as is_stolen
        FROM vehicles v
        LEFT JOIN mdt_vehicle_notes vn ON vn.plate = v.plate
        WHERE v.owner = ?
    ]], { charId }) or {}

    -- Registrované zbraně občana
    local weapons = MySQL.query.await([[
        SELECT id, serial, label, model, is_stolen, DATE_FORMAT(created_at, '%d.%m.%Y') as registered_date
        FROM mdt_weapons
        WHERE owner_id = ?
    ]], { charId }) or {}

    -- Poznámky a tagy občana
    local notes = MySQL.query.await([[
        SELECT id, note, tags, author_name, DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_citizen_notes
        WHERE charId = ?
        ORDER BY id DESC
    ]], { charId }) or {}

    -- Trestní záznamy
    local incidents = MySQL.query.await([[
        SELECT id, title, total_fine, total_jail, status, DATE_FORMAT(created_at, '%d.%m.%Y') as created_at
        FROM mdt_incidents
        WHERE JSON_SEARCH(suspects, 'one', ?, NULL, '$[*].charId') IS NOT NULL
        ORDER BY id DESC LIMIT 15
    ]], { tostring(charId) }) or {}

    -- Aktivní zatykače
    local warrants = MySQL.query.await([[
        SELECT id, reason, charges, creator_name, expires_at, status
        FROM mdt_warrants
        WHERE suspect_id = ?
        ORDER BY id DESC
    ]], { charId }) or {}

    return {
        citizen = citizen,
        vehicles = vehicles,
        weapons = weapons,
        notes = notes,
        incidents = incidents,
        warrants = warrants
    }
end)

-- 4. Uložení poznámky k občanovi
lib.callback.register('fr_mdt:server:saveCitizenNote', function(source, charId, noteText, tags)
    local auth = isAuthorized(source)
    if not auth or not charId or not noteText or noteText == '' then return false end

    local officer = getOfficerProfile(source)
    local id = MySQL.insert.await([[
        INSERT INTO mdt_citizen_notes (charId, note, author_name, tags)
        VALUES (?, ?, ?, ?)
    ]], { tonumber(charId), noteText, officer.name, tags or '' })

    logAction(officer.charId, officer.name, 'ADD_CITIZEN_NOTE', ('Přidána poznámka k ID %s: "%s"'):format(charId, noteText))
    return id ~= nil
end)

-- 5. Vyhledávání vozidel
lib.callback.register('fr_mdt:server:searchVehicles', function(source, query)
    local auth = isAuthorized(source)
    if not auth or not query or query == '' then return {} end

    local officer = getOfficerProfile(source)
    logAction(officer.charId, officer.name, 'SEARCH_VEHICLE', ('Vyhledávání vozidla: "%s"'):format(query))

    local q = ('%%%s%%'):format(query:gsub('%s+', ''))
    local rows = MySQL.query.await([[
        SELECT v.id, v.plate, v.model, v.owner,
               CONCAT(c.firstName, ' ', c.lastName) as ownerName,
               COALESCE(vn.is_stolen, 0) as is_stolen
        FROM vehicles v
        LEFT JOIN characters c ON c.charId = v.owner
        LEFT JOIN mdt_vehicle_notes vn ON vn.plate = v.plate
        WHERE REPLACE(v.plate, ' ', '') LIKE ? OR v.model LIKE ?
        LIMIT 25
    ]], { q, ('%%%s%%'):format(query) }) or {}

    return rows
end)

-- 6. Detail vozidla
lib.callback.register('fr_mdt:server:getVehicleDetail', function(source, plate)
    local auth = isAuthorized(source)
    if not auth or not plate then return nil end

    plate = (tostring(plate):upper():gsub('^%s*(.-)%s*$', '%1'))

    local veh = MySQL.single.await([[
        SELECT v.id, v.plate, v.vin, v.model, v.class, v.fr_state, v.fr_impound_reason, v.owner,
               CONCAT(c.firstName, ' ', c.lastName) as ownerName
        FROM vehicles v
        LEFT JOIN characters c ON c.charId = v.owner
        WHERE v.plate = ? LIMIT 1
    ]], { plate })

    if not veh then return nil end

    local noteData = MySQL.single.await([[
        SELECT note, is_stolen, author_name, DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_vehicle_notes
        WHERE plate = ? LIMIT 1
    ]], { plate })

    return {
        vehicle = veh,
        note = noteData and noteData.note or '',
        isStolen = noteData and (noteData.is_stolen == 1) or false,
        noteAuthor = noteData and noteData.author_name or nil
    }
end)

-- 7. Nastavení BOLO (kradené vozidlo)
lib.callback.register('fr_mdt:server:setVehicleStolen', function(source, plate, isStolen)
    local auth = isAuthorized(source)
    if not auth or not plate then return false end

    local officer = getOfficerProfile(source)
    plate = (tostring(plate):upper():gsub('^%s*(.-)%s*$', '%1'))

    MySQL.query.await([[
        INSERT INTO mdt_vehicle_notes (plate, note, is_stolen, author_name)
        VALUES (?, '', ?, ?)
        ON DUPLICATE KEY UPDATE is_stolen = VALUES(is_stolen), author_name = VALUES(author_name)
    ]], { plate, isStolen and 1 or 0, officer.name })

    logAction(officer.charId, officer.name, 'TOGGLE_VEHICLE_BOLO', ('SPZ [%s] označeno kradené: %s'):format(plate, tostring(isStolen)))
    return true
end)

-- 8. Uložení poznámky k vozidlu
lib.callback.register('fr_mdt:server:saveVehicleNote', function(source, plate, note)
    local auth = isAuthorized(source)
    if not auth or not plate then return false end

    local officer = getOfficerProfile(source)
    plate = (tostring(plate):upper():gsub('^%s*(.-)%s*$', '%1'))

    MySQL.query.await([[
        INSERT INTO mdt_vehicle_notes (plate, note, is_stolen, author_name)
        VALUES (?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE note = VALUES(note), author_name = VALUES(author_name)
    ]], { plate, note or '', officer.name })

    return true
end)

-- ========================================================
-- REGISTR ZBRANÍ & BALISTIKA
-- ========================================================
lib.callback.register('fr_mdt:server:searchWeapons', function(source, query)
    local auth = isAuthorized(source)
    if not auth or not query or query == '' then return {} end

    local officer = getOfficerProfile(source)
    logAction(officer.charId, officer.name, 'SEARCH_WEAPON', ('Hledání zbraně: "%s"'):format(query))

    local q = ('%%%s%%'):format(query)
    return MySQL.query.await([[
        SELECT id, serial, label, model, owner_name, owner_id, is_stolen, DATE_FORMAT(created_at, '%d.%m.%Y') as registered_date
        FROM mdt_weapons
        WHERE serial LIKE ? OR label LIKE ? OR owner_name LIKE ?
        LIMIT 25
    ]], { q, q, q }) or {}
end)

lib.callback.register('fr_mdt:server:getWeaponDetail', function(source, serial)
    local auth = isAuthorized(source)
    if not auth or not serial then return nil end

    return MySQL.single.await([[
        SELECT id, serial, label, model, owner_id, owner_name, is_stolen, ballistics_notes, registered_by,
               DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_weapons
        WHERE serial = ? LIMIT 1
    ]], { serial })
end)

lib.callback.register('fr_mdt:server:registerWeapon', function(source, data)
    local auth = isAuthorized(source)
    if not auth or not data or not data.serial or not data.model then return false end

    local officer = getOfficerProfile(source)
    local serial = (tostring(data.serial):upper():gsub('^%s*(.-)%s*$', '%1'))

    local id = MySQL.insert.await([[
        INSERT INTO mdt_weapons (serial, model, label, owner_id, owner_name, is_stolen, ballistics_notes, registered_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        serial,
        data.model,
        data.label or data.model,
        tonumber(data.ownerId) or nil,
        data.ownerName or 'Neznámý',
        data.isStolen and 1 or 0,
        data.ballistics or '',
        officer.name
    })

    logAction(officer.charId, officer.name, 'REGISTER_WEAPON', ('Zaregistrována zbraň %s (SN: %s) pro %s'):format(data.label or data.model, serial, data.ownerName or 'N/A'))
    return id ~= nil
end)

lib.callback.register('fr_mdt:server:setWeaponStolen', function(source, serial, isStolen)
    local auth = isAuthorized(source)
    if not auth or not serial then return false end

    local officer = getOfficerProfile(source)
    MySQL.update.await('UPDATE mdt_weapons SET is_stolen = ? WHERE serial = ?', { isStolen and 1 or 0, serial })
    logAction(officer.charId, officer.name, 'WEAPON_STOLEN_STATUS', ('Zbraň SN: %s označena jako kradená: %s'):format(serial, tostring(isStolen)))
    return true
end)

lib.callback.register('fr_mdt:server:saveWeaponBallistics', function(source, serial, notes)
    local auth = isAuthorized(source)
    if not auth or not serial then return false end

    local officer = getOfficerProfile(source)
    MySQL.update.await('UPDATE mdt_weapons SET ballistics_notes = ? WHERE serial = ?', { notes or '', serial })
    logAction(officer.charId, officer.name, 'UPDATE_BALLISTICS', ('Aktualizována balistika u zbraně SN: %s'):format(serial))
    return true
end)

-- ========================================================
-- AKTIVNÍ BOLOS
-- ========================================================
lib.callback.register('fr_mdt:server:getBolos', function(source)
    local auth = isAuthorized(source)
    if not auth then return {} end

    return MySQL.query.await([[
        SELECT id, type, title, target_name, plate, reason, danger_level, creator_name,
               DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_bolos
        ORDER BY id DESC
    ]]) or {}
end)

lib.callback.register('fr_mdt:server:createBolo', function(source, data)
    local auth = isAuthorized(source)
    if not auth or not data or not data.title then return false end

    local officer = getOfficerProfile(source)
    local id = MySQL.insert.await([[
        INSERT INTO mdt_bolos (type, title, target_name, plate, reason, danger_level, creator_name)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.type or 'person',
        data.title,
        data.targetName or '',
        data.plate or '',
        data.reason or '',
        data.dangerLevel or 'medium',
        officer.name
    })

    logAction(officer.charId, officer.name, 'CREATE_BOLO', ('Vydáno BOLO [%s]: %s'):format(data.type, data.title))
    return id ~= nil
end)

lib.callback.register('fr_mdt:server:deleteBolo', function(source, boloId)
    local auth = isAuthorized(source)
    if not auth or not boloId then return false end

    local officer = getOfficerProfile(source)
    MySQL.query.await('DELETE FROM mdt_bolos WHERE id = ?', { tonumber(boloId) })
    logAction(officer.charId, officer.name, 'DELETE_BOLO', ('Smazáno BOLO #%s'):format(boloId))
    return true
end)

-- ========================================================
-- SPISY & INCIDENTY
-- ========================================================
lib.callback.register('fr_mdt:server:getIncidents', function(source, search)
    local auth = isAuthorized(source)
    if not auth then return {} end

    local query = 'SELECT id, title, creator_name, total_fine, total_jail, status, DATE_FORMAT(created_at, "%d.%m.%Y %H:%M") as created_at FROM mdt_incidents'
    local params = {}

    if search and search ~= '' then
        query = query .. ' WHERE title LIKE ? OR id = ? ORDER BY id DESC LIMIT 40'
        params = { ('%%%s%%'):format(search), tonumber(search) or -1 }
    else
        query = query .. ' ORDER BY id DESC LIMIT 40'
    end

    return MySQL.query.await(query, params) or {}
end)

lib.callback.register('fr_mdt:server:getIncidentDetail', function(source, incidentId)
    local auth = isAuthorized(source)
    if not auth or not incidentId then return nil end

    local row = MySQL.single.await([[
        SELECT id, title, description, creator_id, creator_name, suspects, officers, victims, evidence,
               total_fine, total_jail, status, DATE_FORMAT(created_at, '%d.%m.%Y %H:%M') as created_at
        FROM mdt_incidents
        WHERE id = ? LIMIT 1
    ]], { tonumber(incidentId) })

    if not row then return nil end

    row.suspects = row.suspects and json.decode(row.suspects) or {}
    row.officers = row.officers and json.decode(row.officers) or {}
    row.victims = row.victims and json.decode(row.victims) or {}

    return row
end)

lib.callback.register('fr_mdt:server:saveIncident', function(source, data)
    local auth = isAuthorized(source)
    if not auth or not data or not data.title then return false end

    local officer = getOfficerProfile(source)
    local suspectsJson = json.encode(data.suspects or {})
    local officersJson = json.encode(data.officers or {})
    local victimsJson = json.encode(data.victims or {})

    if data.id then
        MySQL.update.await([[
            UPDATE mdt_incidents
            SET title = ?, description = ?, suspects = ?, officers = ?, victims = ?,
                evidence = ?, total_fine = ?, total_jail = ?, status = ?
            WHERE id = ?
        ]], {
            data.title, data.description or '', suspectsJson, officersJson, victimsJson,
            data.evidence or '', tonumber(data.totalFine) or 0, tonumber(data.totalJail) or 0,
            data.status or 'open', tonumber(data.id)
        })
        logAction(officer.charId, officer.name, 'EDIT_INCIDENT', ('Upraven spis #%s (%s)'):format(data.id, data.title))
        return data.id
    else
        local newId = MySQL.insert.await([[
            INSERT INTO mdt_incidents
                (title, description, creator_id, creator_name, suspects, officers, victims, evidence, total_fine, total_jail, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            data.title, data.description or '', officer.charId, officer.name,
            suspectsJson, officersJson, victimsJson, data.evidence or '',
            tonumber(data.totalFine) or 0, tonumber(data.totalJail) or 0, data.status or 'open'
        })
        logAction(officer.charId, officer.name, 'CREATE_INCIDENT', ('Vytvořen nový spis #%s (%s)'):format(newId, data.title))
        return newId
    end
end)

-- ========================================================
-- ZATYKAČE
-- ========================================================
lib.callback.register('fr_mdt:server:getWarrants', function(source)
    local auth = isAuthorized(source)
    if not auth then return {} end

    return MySQL.query.await([[
        SELECT id, suspect_id, suspect_name, reason, charges, creator_name, status,
               DATE_FORMAT(expires_at, '%d.%m.%Y') as expires_at,
               DATE_FORMAT(created_at, '%d.%m.%Y') as created_at
        FROM mdt_warrants
        ORDER BY status = 'active' DESC, id DESC LIMIT 40
    ]]) or {}
end)

lib.callback.register('fr_mdt:server:createWarrant', function(source, data)
    local auth = isAuthorized(source)
    if not auth or not data or not data.suspectId then return false end

    local officer = getOfficerProfile(source)
    local days = tonumber(data.days) or Config.WarrantDurationDays
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))

    local id = MySQL.insert.await([[
        INSERT INTO mdt_warrants (suspect_id, suspect_name, reason, charges, creator_name, status, expires_at)
        VALUES (?, ?, ?, ?, ?, 'active', ?)
    ]], {
        tonumber(data.suspectId),
        data.suspectName or 'Neznámý',
        data.reason or 'Zatykač',
        json.encode(data.charges or {}),
        officer.name,
        expiresAt
    })

    logAction(officer.charId, officer.name, 'CREATE_WARRANT', ('Vydán zatykač na %s (ID %s)'):format(data.suspectName, data.suspectId))
    return id ~= nil
end)

lib.callback.register('fr_mdt:server:setWarrantStatus', function(source, warrantId, newStatus)
    local auth = isAuthorized(source)
    if not auth or not warrantId then return false end

    local officer = getOfficerProfile(source)
    MySQL.update.await('UPDATE mdt_warrants SET status = ? WHERE id = ?', { newStatus, tonumber(warrantId) })
    logAction(officer.charId, officer.name, 'UPDATE_WARRANT', ('Zatykač #%s změněn na status %s'):format(warrantId, newStatus))
    return true
end)

-- ========================================================
-- ADMINISTRACE & AUDIT LOGY & OPRÁVNĚNÍ
-- ========================================================
lib.callback.register('fr_mdt:server:getStaffList', function(source)
    local auth = isAuthorized(source)
    if not auth then return {} end

    local profile = getOfficerProfile(source)
    if profile.role ~= 'admin' and profile.role ~= 'command' then
        return {}
    end

    local rows = MySQL.query.await([[
        SELECT c.charId, c.firstName, c.lastName, cg.name as job_name, cg.grade as job_grade,
               COALESCE(us.callsign, 'N/A') as callsign,
               COALESCE(us.department, 'LSPD') as department,
               COALESCE(us.role, 'officer') as mdt_role
        FROM characters c
        INNER JOIN character_groups cg ON cg.charId = c.charId AND cg.name IN ('police', 'sheriff', 'doj', 'ambulance')
        LEFT JOIN mdt_user_settings us ON us.charId = c.charId
        ORDER BY us.role = 'admin' DESC, cg.grade DESC, c.lastName ASC
    ]]) or {}

    return rows
end)

lib.callback.register('fr_mdt:server:setOfficerRole', function(source, targetCharId, newRole)
    local auth = isAuthorized(source)
    if not auth or not targetCharId or not newRole then return false end

    local officer = getOfficerProfile(source)
    if officer.role ~= 'admin' and officer.role ~= 'command' then
        return false
    end

    MySQL.query.await([[
        INSERT INTO mdt_user_settings (charId, callsign, role)
        VALUES (?, '1-A-01', ?)
        ON DUPLICATE KEY UPDATE role = VALUES(role)
    ]], { tonumber(targetCharId), newRole })

    logAction(officer.charId, officer.name, 'CHANGE_ROLE', ('Změněna role pro CharID %s na: %s'):format(targetCharId, newRole))
    return true
end)

lib.callback.register('fr_mdt:server:getAuditLogs', function(source, search)
    local auth = isAuthorized(source)
    if not auth then return {} end

    local officer = getOfficerProfile(source)
    if officer.role ~= 'admin' and officer.role ~= 'command' and officer.role ~= 'supervisor' then
        return {}
    end

    local query = 'SELECT id, officer_name, action, details, DATE_FORMAT(created_at, "%d.%m.%Y %H:%M:%S") as created_at FROM mdt_logs'
    local params = {}

    if search and search ~= '' then
        query = query .. ' WHERE action LIKE ? OR officer_name LIKE ? OR details LIKE ? ORDER BY id DESC LIMIT 50'
        local q = ('%%%s%%'):format(search)
        params = { q, q, q }
    else
        query = query .. ' ORDER BY id DESC LIMIT 50'
    end

    return MySQL.query.await(query, params) or {}
end)

-- Nástěnka - Přidat / Smazat bulletin
lib.callback.register('fr_mdt:server:saveBulletin', function(source, title, content, isPinned)
    local auth = isAuthorized(source)
    if not auth or not title or not content then return false end

    local officer = getOfficerProfile(source)
    local id = MySQL.insert.await([[
        INSERT INTO mdt_bulletins (title, content, author_name, is_pinned)
        VALUES (?, ?, ?, ?)
    ]], { title, content, officer.name, isPinned and 1 or 0 })

    logAction(officer.charId, officer.name, 'CREATE_BULLETIN', ('Zveřejněno oznámení: %s'):format(title))
    return id ~= nil
end)

lib.callback.register('fr_mdt:server:deleteBulletin', function(source, bulletinId)
    local auth = isAuthorized(source)
    if not auth or not bulletinId then return false end

    local officer = getOfficerProfile(source)
    MySQL.query.await('DELETE FROM mdt_bulletins WHERE id = ?', { tonumber(bulletinId) })
    logAction(officer.charId, officer.name, 'DELETE_BULLETIN', ('Smazáno oznámení #%s'):format(bulletinId))
    return true
end)

-- Nastavení vlastního volacího znaku (callsign)
lib.callback.register('fr_mdt:server:updateCallsign', function(source, newCallsign)
    local auth = isAuthorized(source)
    if not auth or not newCallsign or newCallsign == '' then return false end

    local player = Ox.GetPlayer(source)
    if not player then return false end

    newCallsign = newCallsign:sub(1, 20):upper()
    Player(source).state:set('callsign', newCallsign, true)

    MySQL.query.await([[
        INSERT INTO mdt_user_settings (charId, callsign)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE callsign = VALUES(callsign)
    ]], { player.charId, newCallsign })

    return true
end)

-- Změna statusu jednotky (10-8, 10-7, 10-6)
lib.callback.register('fr_mdt:server:setUnitStatus', function(source, status)
    local auth = isAuthorized(source)
    if not auth then return false end

    unitStatuses[source] = status or '10-8'
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    unitStatuses[src] = nil
end)

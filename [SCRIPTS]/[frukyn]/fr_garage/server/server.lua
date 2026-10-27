local reservations, mileage, releaseLocks = {}, {}, {}

local function log(...)
    if Config.Debug then print('[fr_garage]', ...) end
end

local function trimPlate(p)
    return (tostring(p or ''):upper():gsub('^%s*(.-)%s*$', '%1'))
end

local function decode(v, fallback)
    if type(v) == 'table' then return v end
    if not v then return fallback end
    local ok, r = pcall(json.decode, v)
    return ok and r or fallback
end

local function getPlayer(src)
    return exports.ox_core:GetPlayer(src)
end

local function identifier(src)
    local p = getPlayer(src)
    local charId = p and (p.charId or p.charid)
    return charId and tostring(charId) or GetPlayerIdentifierByType(src, 'license')
end

local function groupLevel(src, group)
    local p = getPlayer(src)
    if not p then return nil end

    if p.getGroup then
        local ok, grade = pcall(function() return p:getGroup(group) end)
        if ok and grade ~= nil then
            if type(grade) == 'table' then return tonumber(grade.grade or grade.level or grade.rank) or 0 end
            if type(grade) == 'number' then return grade end
            return 0
        end
    end

    local groups = p.groups
    if type(groups) == 'table' then
        local g = groups[group]
        if type(g) == 'table' then return tonumber(g.grade or g.level or g.rank) or 0 end
        if type(g) == 'number' then return g end
        if g ~= nil then return 0 end
    end

    local charId = p.charId or p.charid
    if charId then
        local dbRow = MySQL.single.await('SELECT `grade` FROM `character_groups` WHERE `charId` = ? AND `name` = ? LIMIT 1', { charId, group })
        if dbRow and dbRow.grade ~= nil then
            return tonumber(dbRow.grade) or 0
        end
    end

    return nil
end

local function hasJob(src, jobs)
    for name, min in pairs(jobs or {}) do
        local grade = groupLevel(src, name)
        if grade and grade >= min then return true end
    end
    return false
end

local function garageAccess(src, g)
    if not g then return false end
    if g.kind == 'faction' then
        local level = groupLevel(src, g.group)
        if level == nil then
            return false
        end
        return true
    end
    if g.kind == 'property' then return false end
    return true
end

local function withinGarage(src, id, extra)
    local g = Config.Garages[id]
    if not g then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - g.coords) <= (g.radius + (extra or 0))
end

local function classToType(class)
    class = tonumber(class)
    if class == 14 then return 'boat' end
    if class == 15 or class == 16 then return 'air' end
    return 'car'
end

local function effectiveState(row)
    if row.fr_state == 'impound' then return 'impound' end
    if row.stored == nil or row.stored == '' then return 'out' end
    return 'stored'
end

local function normalizeRow(row)
    if not row then return nil end

    local props = decode(row.data, {})
    row.props = props
    row.damage = decode(row.fr_damage, {})
    row.group_name = row.group_name or row.group
    row.vehicle_name = row.fr_vehicle_name
    row.job_min_grade = tonumber(row.fr_job_min_grade) or 0
    row.fuel = tonumber(row.fr_fuel) or tonumber(props.fuelLevel) or Config.DefaultFuel
    row.fuel_type = row.fr_fuel_type
    row.dirty_fuel = tonumber(row.fr_dirty_fuel) or 0
    row.mileage = tonumber(row.fr_mileage) or 0
    row.state = effectiveState(row)
    row.garage = row.stored
    row.entity_netid = row.fr_entity_netid
    row.impound_reason = row.fr_impound_reason
    row.impound_by_job = row.fr_impound_by_job
    row.impound_expire = row.fr_impound_expire
    row.impound_blocked = tonumber(row.fr_impound_blocked) or 0
    row.impound_class = row.fr_impound_class
    row.impound_since = row.fr_impound_since
    
    local vehicleType = row.fr_vehicle_type
    if vehicleType == '' then vehicleType = nil end
    row.vehicle_type = vehicleType or props.type or classToType(row.class or props.class) or 'car'

    if not props.model then props.model = joaat(row.model) end
    if not props.plate then props.plate = row.plate end
    if not props.class and row.class then props.class = tonumber(row.class) end

    return row
end

local function canAccessVehicle(src, row)
    if tostring(row.owner or '') == tostring(identifier(src) or '') then return true end

    local groupName = row.group_name or row.group
    if groupName and groupName ~= '' then
        return groupLevel(src, groupName) ~= nil
    end

    return false
end

local function hasKey(src, plate)
    local items = exports.ox_inventory:Search(src, 'slots', Config.KeyItem) or {}
    for _, item in pairs(items) do
        local m = item.metadata or {}
        if trimPlate(m.plate) == plate and (not m.expires or tonumber(m.expires) > os.time()) then return true end
    end
    return false
end

local function columnExists(column)
    return (MySQL.scalar.await([[
        SELECT COUNT(1)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vehicles' AND COLUMN_NAME = ?
    ]], { column }) or 0) > 0
end

local function ensureColumn(column, definition)
    if not columnExists(column) then
        MySQL.query.await(('ALTER TABLE `vehicles` ADD COLUMN `%s` %s'):format(column, definition))
    end
end

local function ensureIndex(name, definition)
    local exists = (MySQL.scalar.await([[
        SELECT COUNT(1)
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vehicles' AND INDEX_NAME = ?
    ]], { name }) or 0) > 0

    if not exists then
        pcall(function()
            MySQL.query.await(('ALTER TABLE `vehicles` ADD INDEX `%s` %s'):format(name, definition))
        end)
    end
end

local function ensureDatabase()
    ensureColumn('fr_vehicle_name', 'VARCHAR(80) NULL DEFAULT NULL')
    ensureColumn('fr_vehicle_type', 'VARCHAR(12) NULL DEFAULT NULL')
    ensureColumn('fr_job_min_grade', 'INT NOT NULL DEFAULT 0')
    ensureColumn('fr_damage', 'LONGTEXT NULL DEFAULT NULL')
    ensureColumn('fr_fuel', 'FLOAT NOT NULL DEFAULT 100')
    ensureColumn('fr_fuel_type', 'VARCHAR(32) NULL DEFAULT NULL')
    ensureColumn('fr_dirty_fuel', 'TINYINT(1) NOT NULL DEFAULT 0')
    ensureColumn('fr_mileage', 'DOUBLE NOT NULL DEFAULT 0')
    ensureColumn('fr_state', 'VARCHAR(12) NULL DEFAULT NULL')
    ensureColumn('fr_impound_reason', 'VARCHAR(255) NULL DEFAULT NULL')
    ensureColumn('fr_impound_by_job', 'VARCHAR(64) NULL DEFAULT NULL')
    ensureColumn('fr_impound_expire', 'BIGINT NULL DEFAULT NULL')
    ensureColumn('fr_impound_blocked', 'TINYINT(1) NOT NULL DEFAULT 0')
    ensureColumn('fr_impound_class', 'INT NULL DEFAULT NULL')
    ensureColumn('fr_impound_since', 'BIGINT NULL DEFAULT NULL')
    ensureColumn('fr_entity_netid', 'BIGINT NULL DEFAULT NULL')

    ensureIndex('idx_fr_vehicles_state', '(`fr_state`)')
    ensureIndex('idx_fr_vehicles_type', '(`fr_vehicle_type`)')
    print('[fr_garage] Database ready')
end

local function getVehicleByPlate(plate)
    return normalizeRow(MySQL.single.await('SELECT * FROM `vehicles` WHERE `plate` = ? LIMIT 1', { plate }))
end

local function getVehicleById(id)
    return normalizeRow(MySQL.single.await('SELECT * FROM `vehicles` WHERE `id` = ? LIMIT 1', { tonumber(id) }))
end

local function generateVIN()
    local chars = '0123456789ABCDEFGHJKLMNPRSTUVWXYZ'
    local vin = ''
    for i = 1, 17 do
        local rand = math.random(1, #chars)
        vin = vin .. chars:sub(rand, rand)
    end
    return vin
end

CreateThread(ensureDatabase)

-- Callback pro kontrolu frakčních práv klienta
lib.callback.register('fr_garage:checkAccess', function(src, garageId)
    local g = Config.Garages[garageId]
    return garageAccess(src, g)
end)

lib.callback.register('fr_garage:list', function(src, garageId)
    local g = Config.Garages[garageId]
    if not g then return {} end

    if not garageAccess(src, g) or not withinGarage(src, garageId, 10.0) then
        return {}
    end

    local id = identifier(src)
    local rows

    if g.kind == 'faction' then
        rows = MySQL.query.await('SELECT * FROM `vehicles` WHERE `group` = ? AND `stored` = ? ORDER BY `fr_vehicle_name`, `plate`', { g.group, garageId })
    else
        rows = MySQL.query.await('SELECT * FROM `vehicles` WHERE `owner` = ? AND `stored` = ? AND (`group` IS NULL OR `group` = "") ORDER BY `fr_vehicle_name`, `plate`', { tonumber(id) or id, garageId })
    end

    local result = {}
    local factionLevel = g.kind == 'faction' and (groupLevel(src, g.group) or 0) or 999

    for _, raw in ipairs(rows or {}) do
        local r = normalizeRow(raw)

        if r.vehicle_type == g.type then
            if r.state == 'out' and r.entity_netid then
                local ent = NetworkGetEntityFromNetworkId(tonumber(r.entity_netid))
                if ent == 0 or not DoesEntityExist(ent) then
                    MySQL.update('UPDATE `vehicles` SET `stored` = ?, `fr_state` = "stored", `fr_entity_netid` = NULL WHERE `id` = ? AND `stored` IS NULL', { garageId, r.id })
                    r.state = 'stored'
                    r.garage = garageId
                    r.entity_netid = nil
                end
            end

            local canUseFactionVehicle = r.group_name ~= g.group or factionLevel >= (tonumber(r.job_min_grade) or 0)
            if g.kind ~= 'faction' or canUseFactionVehicle then
                r.canTransfer = (tostring(r.owner or '') == tostring(id or '') and g.kind == 'faction' and factionLevel >= (Config.FactionManagerGrade[g.group] or 4)) or false
                result[#result + 1] = r
            end
        end
    end

    return result
end)

lib.callback.register('fr_garage:store', function(src, garageId, data)
    local g = Config.Garages[garageId]
    if not garageAccess(src, g) or not withinGarage(src, garageId, 10.0) or type(data) ~= 'table' then return false end

    local plate = trimPlate(data.plate)
    if #plate < 1 or #plate > 12 then return false end

    local row = getVehicleByPlate(plate)
    if not row or not canAccessVehicle(src, row) or row.state == 'impound' then return false end

    if g.kind == 'faction' and row.group_name ~= g.group then return false end
    if g.kind ~= 'faction' and row.group_name and row.group_name ~= '' then return false end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0
        or GetPedInVehicleSeat(veh, -1) ~= ped
        or trimPlate(GetVehicleNumberPlateText(veh)) ~= plate
        or #(GetEntityCoords(veh) - g.coords) > g.radius + 10
    then
        return false
    end

    local props = data.props or {}
    props.plate = plate
    props.model = props.model or joaat(row.model)
    props.class = props.class or row.class

    local damage = data.damage or {}
    local fuel = math.max(0, math.min(100, tonumber(data.fuel) or tonumber(row.fuel) or Config.DefaultFuel))
    local currentMileage = tonumber(row.mileage) or 0
    mileage[plate] = nil

    MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = ?, `fr_state` = "stored", `fr_entity_netid` = NULL, `data` = ?, `fr_damage` = ?,
            `fr_fuel` = ?, `fr_fuel_type` = ?, `fr_dirty_fuel` = ?, `fr_mileage` = ?, `fr_vehicle_type` = ?
        WHERE `id` = ?
    ]], {
        garageId,
        json.encode(props),
        json.encode(damage),
        fuel,
        Config.Fuel.getType(veh) or '',
        Config.Fuel.getDirty(veh) and 1 or 0,
        currentMileage,
        g.type,
        row.id
    })

    DeleteEntity(veh)
    return true
end)

lib.callback.register('fr_garage:take', function(src, garageId, id)
    local g = Config.Garages[garageId]
    if not garageAccess(src, g) or not withinGarage(src, garageId, 10.0) then return nil end

    local row = getVehicleById(id)
    if not row or not canAccessVehicle(src, row) then return nil end
    if row.state == 'impound' then return { error = 'impound' } end
    if row.state == 'out' then return { error = 'out' } end

    local level = g.kind == 'faction' and (groupLevel(src, g.group) or -1) or 999
    if row.group_name == g.group and level < (tonumber(row.job_min_grade) or 0) then return nil end

    local spawn
    for _, s in ipairs(g.spawns or {}) do
        local clear = true
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - vec3(s.x, s.y, s.z)) < Config.SpawnClearance then
                clear = false
                break
            end
        end

        if clear then
            spawn = s
            break
        end
    end

    if not spawn then return { error = 'blocked' } end

    local changed = MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = NULL, `fr_state` = "out", `fr_entity_netid` = NULL
        WHERE `id` = ? AND `stored` IS NOT NULL AND (`fr_state` IS NULL OR `fr_state` <> "impound")
    ]], { row.id })

    if changed ~= 1 then return { error = 'out' } end

    reservations[row.plate] = { src = src, garage = garageId, expires = os.time() + 45 }
    return { vehicle = row, spawn = spawn }
end)

RegisterNetEvent('fr_garage:spawned', function(id, netId)
    local src = source
    local row = getVehicleById(id)
    if not row or row.state ~= 'out' then return end

    local r = reservations[row.plate]
    if not r or r.src ~= src then return end

    reservations[row.plate] = nil
    MySQL.update('UPDATE `vehicles` SET `fr_entity_netid` = ? WHERE `id` = ?', { tonumber(netId), tonumber(id) })
end)

RegisterNetEvent('fr_garage:spawnFailed', function(id)
    local src = source
    local row = getVehicleById(id)
    if not row then return end

    local r = reservations[row.plate]
    if r and r.src == src then
        reservations[row.plate] = nil
        MySQL.update('UPDATE `vehicles` SET `stored` = ?, `fr_state` = "stored" WHERE `id` = ? AND `stored` IS NULL', { r.garage, tonumber(id) })
    end
end)

lib.callback.register('fr_garage:rename', function(src, id, name)
    local row = getVehicleById(id)
    if not row or not canAccessVehicle(src, row) then return false end

    name = tostring(name or ''):sub(1, 80)
    MySQL.update('UPDATE `vehicles` SET `fr_vehicle_name` = ? WHERE `id` = ?', { name ~= '' and name or nil, row.id })
    return true
end)

lib.callback.register('fr_garage:transfer', function(src, id, group, minGrade)
    local row = getVehicleById(id)
    if not row or tostring(row.owner or '') ~= tostring(identifier(src) or '') then return false end

    local grade = groupLevel(src, group)
    if grade == nil or grade < (Config.FactionManagerGrade[group] or 4) then return false end

    minGrade = math.max(0, math.min(100, tonumber(minGrade) or 0))
    MySQL.update('UPDATE `vehicles` SET `group` = ?, `fr_job_min_grade` = ? WHERE `id` = ?', { group, minGrade, row.id })
    return true
end)

RegisterNetEvent('fr_garage:shareKey', function(target, plate, seconds)
    local src = source
    target = tonumber(target)
    plate = trimPlate(plate)
    seconds = math.min(86400, math.max(60, tonumber(seconds) or Config.KeyShareSeconds))

    local row = getVehicleByPlate(plate)
    if not row or not canAccessVehicle(src, row) or not target or not GetPlayerName(target) then return end

    exports.ox_inventory:AddItem(target, Config.KeyItem, 1, { plate = plate, expires = os.time() + seconds, sharedBy = identifier(src) })
end)

RegisterNetEvent('fr_garage:toggleLock', function(netId, plate)
    local src = source
    plate = trimPlate(plate)
    if not hasKey(src, plate) then return end

    local row = getVehicleByPlate(plate)
    if not row or row.state ~= 'out' then return end
    if row.entity_netid and tonumber(row.entity_netid) ~= tonumber(netId) then return end

    local ent = NetworkGetEntityFromNetworkId(tonumber(netId))
    local ped = GetPlayerPed(src)
    if ent == 0 or not DoesEntityExist(ent) or ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(ent)) > 8.0 then return end

    TriggerClientEvent('fr_garage:lockResult', src, tonumber(netId))
end)

exports('GetImpoundedVehicles', function(groupName)
    local rows
    if groupName then
        rows = MySQL.query.await('SELECT * FROM `vehicles` WHERE `fr_state` = "impound" AND `group` = ?', { groupName })
    else
        rows = MySQL.query.await('SELECT * FROM `vehicles` WHERE `fr_state` = "impound"')
    end

    for i = 1, #(rows or {}) do normalizeRow(rows[i]) end
    return rows or {}
end)

exports('SetImpoundReason', function(plate, reason, job, expire, blocked)
    return MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = ?, `fr_state` = "impound", `fr_entity_netid` = NULL, `fr_impound_reason` = ?,
            `fr_impound_by_job` = ?, `fr_impound_expire` = ?, `fr_impound_blocked` = ?, `fr_impound_since` = COALESCE(`fr_impound_since`, ?)
        WHERE `plate` = ?
    ]], {
        Config.Impound.storeName or 'impound',
        tostring(reason or ''):sub(1, 255),
        job or '',
        expire and tonumber(expire) or nil,
        blocked and 1 or 0,
        os.time(),
        trimPlate(plate)
    }) > 0
end)

exports('ReleaseImpound', function(plate)
    return MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = ?, `fr_state` = "stored", `fr_impound_reason` = NULL, `fr_impound_by_job` = NULL,
            `fr_impound_expire` = NULL, `fr_impound_blocked` = 0, `fr_impound_since` = NULL
        WHERE `plate` = ? AND `fr_state` = "impound"
    ]], { Config.Impound.releaseGarage or Config.DefaultGarage or 'legion', trimPlate(plate) }) > 0
end)

RegisterNetEvent('fr_garage:impoundNearby', function(plate, reason, blocked)
    local src = source
    if blocked then
        if not hasJob(src, Config.Impound.blockJobs) then return end
    elseif not hasJob(src, Config.Impound.towJobs) then
        return
    end

    plate = trimPlate(plate)
    local row = getVehicleByPlate(plate)
    if not row then return end

    local ped = GetPlayerPed(src)
    local target
    for _, veh in ipairs(GetAllVehicles()) do
        if trimPlate(GetVehicleNumberPlateText(veh)) == plate and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= 10.0 then
            target = veh
            break
        end
    end

    if not target then return end

    local jobSet = blocked and Config.Impound.blockJobs or Config.Impound.towJobs
    local job
    for name in pairs(jobSet) do
        if groupLevel(src, name) then
            job = name
            break
        end
    end

    MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = ?, `fr_state` = "impound", `fr_entity_netid` = NULL, `fr_impound_reason` = ?,
            `fr_impound_by_job` = ?, `fr_impound_blocked` = ?, `fr_impound_class` = ?, `fr_impound_since` = ?
        WHERE `plate` = ?
    ]], {
        Config.Impound.storeName or 'impound',
        tostring(reason or 'Odtah'):sub(1, 255),
        job,
        blocked and 1 or 0,
        tonumber(row.props.class or row.class),
        os.time(),
        plate
    })

    DeleteEntity(target)
end)

lib.callback.register('fr_garage:releaseImpound', function(src, id)
    id = tonumber(id)
    if not id or releaseLocks[id] then return { error = 'busy' } end

    local row = getVehicleById(id)
    if not row or row.state ~= 'impound' or not canAccessVehicle(src, row) then return nil end
    if row.impound_blocked == 1 then return { error = 'blocked' } end
    if row.impound_expire and tonumber(row.impound_expire) > os.time() then return { error = 'expired' } end

    releaseLocks[id] = true
    local fee = Config.Impound.feesByClass[tonumber(row.impound_class) or -1] or 1000
    if row.impound_since then
        fee = fee + math.floor(math.max(0, os.time() - tonumber(row.impound_since)) / 86400) * Config.Impound.feePerDay
    end

    if not exports.ox_inventory:RemoveItem(src, Config.Impound.moneyItem, fee) then
        releaseLocks[id] = nil
        return { error = 'money', fee = fee }
    end

    local changed = MySQL.update.await([[
        UPDATE `vehicles`
        SET `stored` = ?, `fr_state` = "stored", `fr_impound_reason` = NULL, `fr_impound_by_job` = NULL,
            `fr_impound_expire` = NULL, `fr_impound_blocked` = 0
        WHERE `id` = ? AND `fr_state` = "impound"
    ]], { Config.Impound.releaseGarage or Config.DefaultGarage or 'legion', row.id })

    if changed ~= 1 then
        exports.ox_inventory:AddItem(src, Config.Impound.moneyItem, fee)
        releaseLocks[id] = nil
        return { error = 'busy' }
    end

    releaseLocks[id] = nil
    return { ok = true }
end)

RegisterNetEvent('fr_garage:mileage', function(netId, plate, x, y, z)
    local src = source
    plate = trimPlate(plate)

    local row = getVehicleByPlate(plate)
    if not row or row.state ~= 'out' then return end
    if row.entity_netid and tonumber(row.entity_netid) ~= tonumber(netId) then return end

    local ent = NetworkGetEntityFromNetworkId(tonumber(netId))
    if ent == 0 or not DoesEntityExist(ent) or GetPedInVehicleSeat(ent, -1) ~= GetPlayerPed(src) then return end

    local pos = GetEntityCoords(ent)
    if #(pos - vec3(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)) > 15 then return end

    local prev = mileage[plate]
    if prev and os.time() - prev.at < 10 then return end

    mileage[plate] = { x = pos.x, y = pos.y, z = pos.z, at = os.time() }
    if prev then
        local d = #(pos - vec3(prev.x, prev.y, prev.z))
        if d > 0.5 and d < 2000 then
            MySQL.update('UPDATE `vehicles` SET `fr_mileage` = `fr_mileage` + ? WHERE `id` = ? AND `stored` IS NULL', { d / 1000, row.id })
        end
    end
end)

exports('GiveKey', function(target, plate, metadata)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false end

    metadata = metadata or {}
    metadata.plate = trimPlate(plate)
    return exports.ox_inventory:AddItem(target, Config.KeyItem, 1, metadata) == true
end)

exports('RegisterVehicle', function(owner, data)
    if type(data) ~= 'table' or not data.plate or not data.model then return false end

    local plate = trimPlate(data.plate)
    local existing = getVehicleByPlate(plate)
    local netId = tonumber(data.netId)
    local state = netId and 'out' or 'stored'
    local stored = state == 'out' and nil or (data.garage or Config.DefaultGarage or 'legion')
    local props = data.props or {}

    props.plate = plate
    props.model = props.model or joaat(data.model)
    props.class = props.class or tonumber(data.class)
    props.type = data.type or props.type or classToType(props.class)

    if existing then
        MySQL.update.await([[
            UPDATE `vehicles`
            SET `owner` = COALESCE(?, `owner`), `group` = COALESCE(?, `group`), `model` = ?, `class` = ?, `data` = ?, `stored` = ?,
                `fr_state` = ?, `fr_entity_netid` = ?, `fr_vehicle_type` = ?, `fr_fuel` = ?
            WHERE `id` = ?
        ]], {
            tonumber(owner),
            data.group,
            tostring(data.model),
            tonumber(data.class) or props.class,
            json.encode(props),
            stored,
            state,
            netId,
            props.type,
            tonumber(data.fuel) or Config.DefaultFuel,
            existing.id
        })

        return existing.id
    end

    return MySQL.insert.await([[
        INSERT INTO `vehicles` (`plate`, `vin`, `owner`, `group`, `model`, `class`, `data`, `stored`, `fr_state`, `fr_entity_netid`, `fr_vehicle_type`, `fr_fuel`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        plate,
        data.vin or generateVIN(),
        tonumber(owner),
        data.group,
        tostring(data.model),
        tonumber(data.class) or props.class,
        json.encode(props),
        stored,
        state,
        netId,
        props.type,
        tonumber(data.fuel) or Config.DefaultFuel
    }) or false
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()

        for plate, r in pairs(reservations) do
            if r.expires < now then
                reservations[plate] = nil
                MySQL.update('UPDATE `vehicles` SET `stored` = ?, `fr_state` = "stored" WHERE `plate` = ? AND `stored` IS NULL AND `fr_entity_netid` IS NULL', { r.garage, plate })
            end
        end
    end
end)
local Ox = require '@ox_core.lib.init'

local activeCalls = {}
local callCounter = 100
local liveUnits = {}

-- Pomocná funkce pro získání jména a volacího znaku hráče
-- Pomocná robustní funkce pro zjištění frakcí hráče v ox_core
local function getPlayerGroups(src, player)
    player = player or Ox.GetPlayer(src)
    local groups = {}
    if not player then return groups end

    local charId = player.charId or (player.get and player:get('charId'))

    -- 1. player:getGroup(name)
    for jobName, _ in pairs(Config.EmergencyJobs) do
        local ok, grade = pcall(function()
            if player.getGroup then
                return player:getGroup(jobName)
            end
        end)
        if ok and grade ~= nil then
            groups[jobName] = tonumber(grade) or 0
        end
    end

    -- 2. player.groups tabulka
    if type(player.groups) == 'table' then
        for name, grade in pairs(player.groups) do
            if groups[name] == nil then
                groups[name] = tonumber(grade) or 0
            end
        end
    end

    -- 3. player:getGroups() metoda
    pcall(function()
        if player.getGroups then
            local res = player:getGroups()
            if type(res) == 'table' then
                for name, grade in pairs(res) do
                    if groups[name] == nil then
                        groups[name] = tonumber(grade) or 0
                    end
                end
            end
        end
    end)

    -- 4. StateBag (activeGroup)
    local activeGroup = Player(src).state.activeGroup
    if activeGroup and groups[activeGroup] == nil then
        groups[activeGroup] = 0
    end

    -- 5. Databáze (character_groups)
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

-- Pomocná funkce pro získání jména a volacího znaku hráče
local function getPlayerEmergencyInfo(src)
    local player = Ox.GetPlayer(src)
    if not player then
        return { name = GetPlayerName(src), callsign = '1-ADAM-01', job = 'police' }
    end

    local firstName = player.firstName or (player.get and player:get('firstName')) or GetPlayerName(src)
    local lastName = player.lastName or (player.get and player:get('lastName')) or ''
    local charId = player.charId or (player.get and player:get('charId')) or src
    local callsign = Player(src).state.callsign or ('1-A-%s'):format(charId % 100)

    local playerJob = nil
    local groups = getPlayerGroups(src, player)
    for jobName in pairs(Config.EmergencyJobs) do
        if groups[jobName] ~= nil then
            playerJob = jobName
            break
        end
    end

    return {
        name = ('%s %s'):format(firstName, lastName),
        callsign = callsign,
        job = playerJob or 'police',
        charId = charId
    }
end

-- Ověření, zda je hráč na službě v IZS
local function isPlayerEmergencyDuty(src, requireMedic)
    local player = Ox.GetPlayer(src)
    if not player then return false end

    local groups = getPlayerGroups(src, player)
    local targetJobs = requireMedic and Config.MedicJobs or Config.EmergencyJobs

    for jobName in pairs(targetJobs) do
        if groups[jobName] ~= nil then
            return true, jobName
        end
    end

    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'admin') or groups['admin'] ~= nil then
        return true, 'police'
    end

    return false
end

-- Odeslání hlášení všem relevantním složkám
local function broadcastAlert(alertData)
    callCounter = callCounter + 1
    alertData.id = callCounter
    alertData.time = os.date('%H:%M:%S')
    alertData.timestamp = os.time()
    alertData.responders = {}
    alertData.status = 'active'

    table.insert(activeCalls, 1, alertData)
    if #activeCalls > 50 then
        table.remove(activeCalls, #activeCalls)
    end

    local isMedicAlert = (alertData.alertType == 'medic_call' or alertData.alertType == 'officer_down')
    local onlinePlayers = GetPlayers()

    for _, playerId in ipairs(onlinePlayers) do
        local src = tonumber(playerId)
        local isDuty, job = isPlayerEmergencyDuty(src, false)

        if isDuty then
            -- Lékařské výzvy dostává EMS i policie, policejní jen bezpečnostní složky
            if not isMedicAlert and job == 'ambulance' then
                -- Ambulance neposlouchá střelbu apod., pokud to není zapnuto
            else
                TriggerClientEvent('fr_dispatch:client:notify', src, alertData)
            end
        end
    end

    return alertData.id
end

-- Reakce jednotky na hovor
RegisterNetEvent('fr_dispatch:server:respondToCall', function(callId)
    local src = source
    local info = getPlayerEmergencyInfo(src)

    for _, call in ipairs(activeCalls) do
        if call.id == callId then
            local alreadyResponding = false
            for _, r in ipairs(call.responders) do
                if r.source == src then
                    alreadyResponding = true
                    break
                end
            end

            if not alreadyResponding then
                table.insert(call.responders, {
                    source = src,
                    name = info.name,
                    callsign = info.callsign
                })
                call.status = 'responding'

                -- Upozornění pro ostatní kolegy
                local onlinePlayers = GetPlayers()
                for _, pid in ipairs(onlinePlayers) do
                    local targetSrc = tonumber(pid)
                    if isPlayerEmergencyDuty(targetSrc, false) then
                        TriggerClientEvent('ox_lib:notify', targetSrc, {
                            title = 'Dispatch',
                            description = ('[%s] %s reaguje na hovor #%s (%s)'):format(info.callsign, info.name, call.id, call.title or ''),
                            type = 'inform',
                            icon = 'fa-solid fa-car-side'
                        })
                    end
                end
            end
            break
        end
    end
end)

-- Hlášení střelby
RegisterNetEvent('fr_dispatch:server:reportGunshots', function(data)
    local src = source
    local alertType = data.inVehicle and 'shots_fired_vehicle' or 'shots_fired'
    local cfg = Config.Alerts[alertType]

    broadcastAlert({
        alertType = alertType,
        code = cfg.code,
        title = cfg.title,
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = data.coords,
        street = data.street,
        zone = data.zone,
        vehicle = data.vehicle,
        description = data.inVehicle and ('Střelba z jedoucího vozidla (%s, SPZ: %s)'):format(data.vehicle.model, data.vehicle.plate) or 'Hlášena střelba z pěší zbraně na veřejnosti'
    })
end)

-- Hlášení autonehody
RegisterNetEvent('fr_dispatch:server:reportCrash', function(data)
    local cfg = Config.Alerts['car_crash']

    broadcastAlert({
        alertType = 'car_crash',
        code = cfg.code,
        title = cfg.title,
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = data.coords,
        street = data.street,
        zone = data.zone,
        description = ('Těžká havárie vozidla %s [%s] v rychlosti cca %s km/h'):format(data.model, data.plate, data.speed)
    })
end)

-- Panic button (/panic)
RegisterNetEvent('fr_dispatch:server:sendPanic', function(data)
    local src = source
    local isDuty, job = isPlayerEmergencyDuty(src, false)
    if not isDuty then
        return TriggerClientEvent('ox_lib:notify', src, { title = 'Dispatch', description = 'Tlačítko Panic mohou použít pouze složky IZS.', type = 'error' })
    end

    local info = getPlayerEmergencyInfo(src)
    local cfg = Config.Alerts['panic_button']

    broadcastAlert({
        alertType = 'panic_button',
        code = cfg.code,
        title = ('%s - %s'):format(cfg.title, info.callsign),
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = data.coords,
        street = data.street,
        zone = data.zone,
        caller = ('[%s] %s'):format(info.callsign, info.name),
        description = ('DŮSTOJNÍK [%s] %s AKTIVOVAL TÍSŇOVÉ TLAČÍTKO V NOUZI!'):format(info.callsign, info.name)
    })
end)

-- Policista v bezvědomí (10-13)
RegisterNetEvent('fr_dispatch:server:officerDown', function(data)
    local src = source
    local isDuty, job = isPlayerEmergencyDuty(src, false)
    if not isDuty then return end

    local info = getPlayerEmergencyInfo(src)
    local cfg = Config.Alerts['officer_down']

    broadcastAlert({
        alertType = 'officer_down',
        code = cfg.code,
        title = ('10-13: %s'):format(info.callsign),
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = data.coords,
        street = data.street,
        zone = data.zone,
        caller = ('[%s] %s'):format(info.callsign, info.name),
        description = ('Kolega [%s] %s upadl do bezvědomí / zraněn! Okamžitá lékařská pomoc vyžadována.'):format(info.callsign, info.name)
    })
end)

-- Občanské linky 158 / 155
RegisterNetEvent('fr_dispatch:server:citizenCall', function(alertType, message, coords, street, zone)
    local src = source
    local player = Ox.GetPlayer(src)
    local callerName = player and (player.get('firstName') .. ' ' .. player.get('lastName')) or GetPlayerName(src)
    local phone = player and (player.get('phoneNumber') or 'Neznámé') or 'Neznámé'
    local cfg = Config.Alerts[alertType] or Config.Alerts['citizen_call']

    broadcastAlert({
        alertType = alertType,
        code = cfg.code,
        title = cfg.title,
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = coords,
        street = street,
        zone = zone,
        caller = ('%s (Tel: %s)'):format(callerName, phone),
        description = message
    })
end)

-- Vlastní volání alertu (pro unijob, robbery apod.)
RegisterNetEvent('fr_dispatch:server:customAlert', function(data)
    local cfg = Config.Alerts[data.alertType] or {
        code = data.code or '10-00',
        title = data.title or 'Výzva',
        icon = data.icon or 'fa-solid fa-bell',
        color = data.color or '#3498db',
        priority = data.priority or 1
    }

    broadcastAlert({
        alertType = data.alertType or 'custom',
        code = cfg.code,
        title = data.title or cfg.title,
        icon = cfg.icon,
        color = cfg.color,
        priority = cfg.priority,
        coords = data.coords,
        street = data.street,
        zone = data.zone,
        caller = data.caller or 'Automatický systém',
        description = data.description or 'Hlášení systému'
    })
end)

-- Synchronizace live GPS jednotek na mapě
RegisterNetEvent('fr_dispatch:server:updateUnitCoords', function(data)
    local src = source
    local info = getPlayerEmergencyInfo(src)

    liveUnits[src] = {
        source = src,
        name = info.name,
        callsign = info.callsign,
        job = data.job or info.job,
        coords = data.coords,
        heading = data.heading,
        inVehicle = data.inVehicle,
        updated = os.time()
    }
end)

-- Smyčka pro rozesílání live jednotek
CreateThread(function()
    while true do
        Wait(Config.LiveBlipInterval)
        local now = os.time()
        local unitList = {}

        for src, u in pairs(liveUnits) do
            if (now - u.updated) > 10 or not GetPlayerName(src) then
                liveUnits[src] = nil
            else
                table.insert(unitList, u)
            end
        end

        local onlinePlayers = GetPlayers()
        for _, pid in ipairs(onlinePlayers) do
            local src = tonumber(pid)
            if isPlayerEmergencyDuty(src, false) then
                TriggerClientEvent('fr_dispatch:client:syncUnits', src, unitList)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    liveUnits[src] = nil
end)

-- Serverové exporty
exports('CustomAlert', function(data)
    return broadcastAlert(data)
end)

exports('GetActiveCalls', function()
    return activeCalls
end)

exports('GetLiveUnits', function()
    local list = {}
    for _, u in pairs(liveUnits) do
        table.insert(list, u)
    end
    return list
end)

exports('CloseCall', function(callId)
    for i, call in ipairs(activeCalls) do
        if call.id == tonumber(callId) then
            call.status = 'closed'
            return true
        end
    end
    return false
end)

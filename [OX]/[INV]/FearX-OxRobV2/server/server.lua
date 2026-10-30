local Ox = require '@ox_core.lib.init'

local robCooldowns = {}
local targetCooldowns = {}
local activeRobberies = {}
--[[ //TODO: implement a more secure webhook solution

local function SendWebhook(webhookConfig, title, description, fields)
    if not webhookConfig.Enable or webhookConfig.URL == '' then return end

    local payload = {
        username = webhookConfig.BotName,
        avatar_url = webhookConfig.BotAvatar ~= '' and webhookConfig.BotAvatar or nil,
        embeds = {{
            title = title,
            description = description,
            color = webhookConfig.Color or 16711680,
            fields = fields or {},
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = {text = 'FearX-OxRobV2'}
        }}
    }

    PerformHttpRequest(webhookConfig.URL, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end
]]
local function GetIdentifiers(playerId)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(playerId) - 1 do
        local id = GetPlayerIdentifier(playerId, i)
        if id then
            local idType = id:match('^([^:]+):')
            if idType == 'steam' or idType == 'license' or idType == 'discord' then
                ids[#ids + 1] = id
            end
        end
    end
    return #ids > 0 and table.concat(ids, '\n') or 'None'
end

local function LogExploit(src, targetId, distance, maxDist)
    local name = GetPlayerName(src) or 'Unknown'
    local targetName = GetPlayerName(targetId) or 'Unknown'

    SendWebhook(ServerConfig.Webhooks.ExploitLog, 'ROBBERY EXPLOIT DETECTED', ('**%s** tried to rob from **%.1fm** away (max: %.1fm)'):format(name, distance, maxDist), {
        {name = 'Exploiter', value = ('%s (ID: %s)'):format(name, src), inline = true},
        {name = 'Target', value = ('%s (ID: %s)'):format(targetName, targetId), inline = true},
        {name = 'Distance', value = ('%.1fm / %.1fm'):format(distance, maxDist), inline = true},
        {name = 'Identifiers', value = GetIdentifiers(src), inline = false}
    })
end

local function LogAntiCheat(src, violationType)
    local name = GetPlayerName(src) or 'Unknown'

    SendWebhook(ServerConfig.Webhooks.AntiCheatLog, 'ANTI-CHEAT VIOLATION', ('**%s** triggered: %s'):format(name, violationType), {
        {name = 'Player', value = ('%s (ID: %s)'):format(name, src), inline = true},
        {name = 'Type', value = violationType, inline = true},
        {name = 'Identifiers', value = GetIdentifiers(src), inline = false}
    })
end

local function LogRobbery(src, targetId)
    local name = GetPlayerName(src) or 'Unknown'
    local targetName = GetPlayerName(targetId) or 'Unknown'

    SendWebhook(ServerConfig.Webhooks.RobberyLog, 'ROBBERY COMPLETED', ('**%s** robbed **%s**'):format(name, targetName), {
        {name = 'Robber', value = ('%s (ID: %s)'):format(name, src), inline = true},
        {name = 'Victim', value = ('%s (ID: %s)'):format(targetName, targetId), inline = true},
        {name = 'Robber Identifiers', value = GetIdentifiers(src), inline = false},
        {name = 'Victim Identifiers', value = GetIdentifiers(targetId), inline = false}
    })
end

local function IsOnCooldown(id, cooldownTable)
    local expiry = cooldownTable[id]
    if not expiry then return false end
    if os.time() >= expiry then
        cooldownTable[id] = nil
        return false
    end
    return true
end

local function SetCooldowns(robberId, targetId)
    local expiry = os.time() + Config.RobCooldown
    robCooldowns[robberId] = expiry
    targetCooldowns[targetId] = expiry
end

local function IsValidPlayer(id)
    return type(id) == 'number' and Ox.GetPlayer(id) ~= nil
end

local stateKeys = {'isDead', 'dead', 'invBusy', 'isDown', 'inLaststand', 'laststand'}

local function ClearTargetBlockingStates(targetId)
    local saved = {}
    local targetState = Player(targetId).state

    for i = 1, #stateKeys do
        local key = stateKeys[i]
        local val = targetState[key]
        if val then
            saved[key] = val
            targetState:set(key, false, true)
        end
    end

    return saved
end

local function RestoreTargetStates(targetId, saved)
    if not saved or not GetPlayerName(targetId) then return end

    local targetState = Player(targetId).state
    for key, val in pairs(saved) do
        targetState:set(key, val, true)
    end
end

local function ValidateRobbery(src, targetId)
    if not IsValidPlayer(targetId) then
        TriggerClientEvent('fearx-oxrob:client:notify', src, 'no_target', 'error')
        return false
    end

    if src == targetId then
        TriggerClientEvent('fearx-oxrob:client:notify', src, 'cant_rob_self', 'error')
        return false
    end

    if IsOnCooldown(src, robCooldowns) then
        TriggerClientEvent('fearx-oxrob:client:notify', src, 'rob_cooldown', 'error')
        return false
    end

    if IsOnCooldown(targetId, targetCooldowns) then
        TriggerClientEvent('fearx-oxrob:client:notify', src, 'target_cooldown', 'error')
        return false
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)

    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then
        TriggerClientEvent('fearx-oxrob:client:notify', src, 'no_target', 'error')
        return false
    end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(srcCoords - targetCoords)
    local maxAllowed = Config.RobDistance + Config.DistanceBuffer

    if distance > maxAllowed then
        local name = GetPlayerName(src) or 'Unknown'
        print(('[FEARX-OXROB-V2] EXPLOIT: %s (%s) distance rob %.1f/%.1f on %s'):format(name, src, distance, maxAllowed, targetId))
        LogExploit(src, targetId, distance, maxAllowed)
        TriggerClientEvent('fearx-oxrob:client:notify', targetId, 'exploit_attempt', 'error')
        DropPlayer(src, 'FearX-OxRobV2: Distance exploit')
        return false
    end

    return true
end

RegisterNetEvent('fearx-oxrob:server:startRob', function(targetId)
    local src = source
    if type(targetId) ~= 'number' then return end

    if not ValidateRobbery(src, targetId) then return end

    activeRobberies[src] = {target = targetId, startTime = os.time()}
    SetCooldowns(src, targetId)

    TriggerClientEvent('fearx-oxrob:client:beingRobbed', targetId)
end)

RegisterNetEvent('fearx-oxrob:server:completeRob', function(targetId)
    local src = source
    if type(targetId) ~= 'number' then return end

    local robbery = activeRobberies[src]
    if not robbery or robbery.target ~= targetId then return end
    if not IsValidPlayer(targetId) then return end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then return end

    local distance = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if distance > Config.RobDistance + Config.DistanceBuffer then return end

    activeRobberies[src] = nil

    LogRobbery(src, targetId)

    local savedStates = ClearTargetBlockingStates(targetId)

    TriggerClientEvent('fearx-oxrob:client:openInventory', src, targetId)

    SetTimeout(8000, function()
        RestoreTargetStates(targetId, savedStates)
    end)
end)

RegisterNetEvent('fearx-oxrob:server:cancelRob', function(targetId)
    local src = source
    if type(targetId) ~= 'number' then return end

    local robbery = activeRobberies[src]
    if robbery and robbery.target == targetId then
        activeRobberies[src] = nil
    end
end)

RegisterNetEvent('fearx-oxrob:server:targetHandsDown', function()
    local src = source
    local toRemove = {}

    for robberId, data in pairs(activeRobberies) do
        if data.target == src then
            toRemove[#toRemove + 1] = robberId
        end
    end

    for i = 1, #toRemove do
        local robberId = toRemove[i]
        TriggerClientEvent('fearx-oxrob:client:cancelRobbery', robberId)
        activeRobberies[robberId] = nil
    end
end)

RegisterNetEvent('fearx-oxrob:server:anticheat', function(violationType)
    local src = source
    if type(violationType) ~= 'string' then return end

    print(('[FEARX-OXROB-V2] ANTICHEAT: %s - %s'):format(src, violationType))
    LogAntiCheat(src, violationType)
    DropPlayer(src, 'FearX-OxRobV2: ' .. violationType)
end)

AddEventHandler('playerDropped', function()
    local src = source
    robCooldowns[src] = nil
    targetCooldowns[src] = nil
    activeRobberies[src] = nil
end)
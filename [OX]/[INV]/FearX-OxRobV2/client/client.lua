local Ox = require '@ox_core.lib.init'

local isRobbing = false
local lastRobTime = 0
local isHandsUp = false
local robberyCancelled = false

local function IsTargetDead(serverId, ped)
    local state = Player(serverId).state
    return IsEntityDead(ped) or state.isDead or state.dead or state.isDown
end

local function IsPlayerHandsUp(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return false end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return false end

    for i = 1, #Config.HandsUpAnims do
        local data = Config.HandsUpAnims[i]
        if IsEntityPlayingAnim(ped, data.dict, data.anim, 3) then
            return true
        end
    end
    return false
end

local function GetClosestPlayer()
    local coords = GetEntityCoords(cache.ped)
    local playerId = lib.getClosestPlayer(coords, Config.RobDistance, false)
    if playerId then
        return GetPlayerServerId(playerId)
    end
    return nil
end

local function StartRobbery(targetId)
    local robTime = math.random(Config.RobTimer.min * 1000, Config.RobTimer.max * 1000)
    local animData = Config.RobAnimations[math.random(1, #Config.RobAnimations)]

    isRobbing = true
    robberyCancelled = false
    lastRobTime = GetGameTimer()

    TriggerServerEvent('fearx-oxrob:server:startRob', targetId)

    CreateThread(function()
        while isRobbing and not robberyCancelled do
            Wait(500)

            local targetPlayer = GetPlayerFromServerId(targetId)
            if targetPlayer == -1 then
                robberyCancelled = true
                break
            end

            local targetPed = GetPlayerPed(targetPlayer)
            if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
                robberyCancelled = true
                break
            end

            if #(GetEntityCoords(cache.ped) - GetEntityCoords(targetPed)) > Config.RobDistance + 2.0 then
                lib.notify({description = Config.Locales['target_moved'], type = 'error'})
                robberyCancelled = true
                break
            end

            local isDead = IsTargetDead(targetId, targetPed)

            if Config.RobMode == 'alive' and isDead then
                lib.notify({description = Config.Locales['target_died'], type = 'error'})
                robberyCancelled = true
                break
            end

            if Config.RequireHandsUp and Config.RobMode ~= 'dead' and not isDead and not IsPlayerHandsUp(targetId) then
                lib.notify({description = Config.Locales['target_hands_down'], type = 'error'})
                robberyCancelled = true
                break
            end
        end

        if robberyCancelled then
            lib.cancelProgress()
        end
    end)

    local success = lib.progressBar({
        duration = robTime,
        label = Config.Locales['robbing_in_progress'],
        useWhileDead = false,
        canCancel = true,
        disable = {car = true, move = true, combat = true},
        anim = {dict = animData.dict, clip = animData.anim, flag = animData.flag}
    })

    local wasCancelled = robberyCancelled
    isRobbing = false

    ClearPedTasks(cache.ped)

    if wasCancelled or not success then
        lib.notify({description = Config.Locales['rob_cancelled'], type = 'error'})
        TriggerServerEvent('fearx-oxrob:server:cancelRob', targetId)
        return
    end

    TriggerServerEvent('fearx-oxrob:server:completeRob', targetId)
end

local function HandsUpCommand()
    if cache.vehicle then
        lib.notify({description = Config.Locales['no_vehicle_handsup'], type = 'error'})
        return
    end

    if isHandsUp then
        ClearPedTasks(cache.ped)
        isHandsUp = false
        lib.notify({description = Config.Locales['hands_down'], type = 'inform'})
        TriggerServerEvent('fearx-oxrob:server:targetHandsDown')
    else
        lib.requestAnimDict('missminuteman_1ig_2')
        TaskPlayAnim(cache.ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, 8.0, -1, 50, 0, false, false, false)
        isHandsUp = true
        lib.notify({description = Config.Locales['hands_up'], type = 'inform'})
    end
end

local function CustomStealCommand()
    if isRobbing then return end

    if GetGameTimer() - lastRobTime < (Config.AntiSpam * 1000) then
        lib.notify({description = Config.Locales['anti_spam'], type = 'error'})
        return
    end

    if cache.vehicle then
        lib.notify({description = Config.Locales['robber_in_vehicle'], type = 'error'})
        return
    end

    local targetId = GetClosestPlayer()
    if not targetId then
        lib.notify({description = Config.Locales['no_target'], type = 'error'})
        return
    end

    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer == -1 then
        lib.notify({description = Config.Locales['no_target'], type = 'error'})
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then
        lib.notify({description = Config.Locales['no_target'], type = 'error'})
        return
    end

    if IsPedInAnyVehicle(targetPed, false) then
        lib.notify({description = Config.Locales['target_in_vehicle'], type = 'error'})
        return
    end

    local isDead = IsTargetDead(targetId, targetPed)

    if Config.RobMode == 'alive' and isDead then
        lib.notify({description = Config.Locales['target_is_dead'], type = 'error'})
        return
    elseif Config.RobMode == 'dead' and not isDead then
        lib.notify({description = Config.Locales['target_not_dead'], type = 'error'})
        return
    end

    if Config.RequireHandsUp and Config.RobMode ~= 'dead' and not isDead and not IsPlayerHandsUp(targetId) then
        lib.notify({description = Config.Locales['hands_not_up'], type = 'error'})
        return
    end

    StartRobbery(targetId)
end

CreateThread(function()
    RegisterCommand('steal', CustomStealCommand, false)
    RegisterCommand('handsup', HandsUpCommand, false)
    RegisterKeyMapping('handsup', 'Toggle hands up', 'keyboard', 'x')
    TriggerEvent('chat:removeSuggestion', '/steal')
    TriggerEvent('chat:addSuggestion', '/steal', 'Rob a nearby player')
end)

CreateThread(function()
    while true do
        if isHandsUp then
            Wait(200)
            if IsEntityDead(cache.ped) then
                isHandsUp = false
                TriggerServerEvent('fearx-oxrob:server:targetHandsDown')
            end
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('fearx-oxrob:client:beingRobbed', function()
    lib.notify({description = Config.Locales['robbery_started'], type = 'error'})
end)

RegisterNetEvent('fearx-oxrob:client:cancelRobbery', function()
    if isRobbing then
        robberyCancelled = true
    end
end)

RegisterNetEvent('fearx-oxrob:client:openInventory', function(targetId)
    if type(targetId) ~= 'number' then return end
    Wait(100)
    exports.ox_inventory:openNearbyInventory()
end)

RegisterNetEvent('fearx-oxrob:client:notify', function(message, msgType)
    lib.notify({description = Config.Locales[message] or message, type = msgType or 'inform'})
end)
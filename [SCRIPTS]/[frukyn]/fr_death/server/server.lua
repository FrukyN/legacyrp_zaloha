local Ox = require '@ox_core.lib.init'

local function setPlayerDeath(source, status)
    local player = Ox.GetPlayer(source)
    if not player then return end

    player.set('isDead', status)

    Player(source).state:set('isDead', status, true)
end

RegisterNetEvent('fr_death:server:setDeathStatus', function(status)
    local src = source
    if status ~= true then
        print(('^1[ANTI-CHEAT] Hráč ID %s se pokusil sám sebe oživit přes net event!^0'):format(src))
        return
    end

    setPlayerDeath(src, true)
end)

RegisterNetEvent('fr_death:server:respawnInHospital', function()
    local src = source
    local isDead = Player(src).state.isDead

    if not isDead then return end

    setPlayerDeath(src, false)

    if Config.WipeInventoryOnRespawn and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:ClearInventory(src)
    end

    local c = Config.HospitalCoords
    TriggerClientEvent('fr_death:client:revive', src, vec3(c.x, c.y, c.z), c.w)
end)

AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    local player = Ox.GetPlayer(source)
    if player then
        local deadMetadata = player.get('isDead') or false
        Player(source).state:set('isDead', deadMetadata, true)
    end
end)

lib.addCommand('revive', {
    help = 'Oživí hráče z bezvědomí',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'ID hráče (nech prázdné pro sebe)',
            optional = true
        }
    }
}, function(source, args)
    local target = args.target or source
    local hasPermission = false

    if source == 0 then
        hasPermission = true
    else
        for group, _ in pairs(Config.AdminGroups) do
            if IsPlayerAceAllowed(source, tostring(group)) then
                hasPermission = true
                break
            end
        end
           end

    if not hasPermission and source > 0 then
        local player = Ox.GetPlayer(source)
        if player then
            local groups = player.getGroups()
            for jobName, minGrade in pairs(Config.EMSJobs) do
                if groups[jobName] and groups[jobName] >= minGrade then
                    hasPermission = true
                    break
                end
            end
        end
    end

    if not hasPermission then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Chyba',
            description = 'Nemáš oprávnění používat tento příkaz.',
            type = 'error'
        })
        return
    end

    if not GetPlayerPed(target) or GetPlayerPed(target) == 0 then
        return
    end

    setPlayerDeath(target, false)
    TriggerClientEvent('fr_death:client:revive', target)
end)

exports('RevivePlayer', function(targetSource)
    if not Player(targetSource).state.isDead then return false end
    setPlayerDeath(targetSource, false)
    TriggerClientEvent('fr_death:client:revive', targetSource)
    return true
end)
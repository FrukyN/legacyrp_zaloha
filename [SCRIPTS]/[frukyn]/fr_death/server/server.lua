local Ox = require '@ox_core.lib.init'

-- Zápis stavu smrti a synchronizace přes StateBags + uložení do DB
local function setPlayerDeath(source, status)
    local player = Ox.GetPlayer(source)
    if not player then return end

    -- Uložení do metadat postavy v ox_core (přežije odpojení/restart)
    player.set('isDead', status)

    -- StateBag pro rychlý přístup z ostatních skriptů (klientských i serverových)
    Player(source).state:set('isDead', status, true)
end

-- Hráč nahlásil smrt
RegisterNetEvent('fr_death:server:setDeathStatus', function(status)
    local src = source
    -- Bezpečnostní pojistka: Klient může sám sobě nastavit POUZE smrt (true).
    if status ~= true then
        print(('^1[ANTI-CHEAT] Hráč ID %s se pokusil sám sebe oživit přes net event!^0'):format(src))
        return
    end

    setPlayerDeath(src, true)
end)

-- Respawn v nemocnici po vypršení času
RegisterNetEvent('fr_death:server:respawnInHospital', function()
    local src = source
    local isDead = Player(src).state.isDead

    if not isDead then return end

    setPlayerDeath(src, false)
    
    local c = Config.HospitalCoords
    TriggerClientEvent('fr_death:client:revive', src, vec3(c.x, c.y, c.z), c.w)
end)

-- Načtení stavu při výběru postavy v ox_core
AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    local player = Ox.GetPlayer(source)
    if player then
        local deadMetadata = player.get('isDead') or false
        Player(source).state:set('isDead', deadMetadata, true)
    end
end)

-- Podpora pro txAdmin Heal (vyléčení jednotlivce i celého serveru)
AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
    if GetInvokingResource() ~= 'monitor' then return end
    if not eventData or not eventData.id then return end

    if eventData.id == -1 then
        -- Whole server heal (Vyléčení všech na serveru)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src and Player(src).state.isDead then
                setPlayerDeath(src, false)
                TriggerClientEvent('fr_death:client:revive', src)
            end
        end
    else
        -- Vyléčení konkrétního hráče
        local target = eventData.id
        if Player(target).state.isDead then
            setPlayerDeath(target, false)
            TriggerClientEvent('fr_death:client:revive', target)
        end
    end
end)

-- Zabezpečený příkaz /revive (pro Adminy a EMS)
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
            if IsPlayerAceAllowed(source, group) then
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

-- Serverový export pro oživení z jiných skriptů
exports('RevivePlayer', function(targetSource)
    if not Player(targetSource).state.isDead then return false end
    setPlayerDeath(targetSource, false)
    TriggerClientEvent('fr_death:client:revive', targetSource)
    return true
end)
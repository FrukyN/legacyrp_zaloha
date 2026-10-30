local Ox = require '@ox_core.lib.init'

-- 1. Registrace všech skladů z Configu při startu
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for jobName, jobData in pairs(Config.Jobs) do
        if jobData.stashes then
            for _, stash in ipairs(jobData.stashes) do
                -- Formát groups pro ox_inventory: { ['police'] = 1 }
                local groups = { [jobName] = stash.minGrade or 1 }
                
                -- owner = false -> frakční (shared) | owner = true -> osobní dle charId
                local owner = not stash.shared 

                exports.ox_inventory:RegisterStash(
                    stash.id,
                    stash.label,
                    stash.slots,
                    stash.weight,
                    owner,
                    groups,
                    stash.coords
                )
            end
        end
    end
end)

-- 2. Duty systém (ox_core inService)
RegisterNetEvent('unijob:server:toggleDuty', function(jobName)
    local src = source
    local player = Ox.GetPlayer(src)
    if not player then return end

    local grade = player.getGroup(jobName)
    if not grade then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Nemáš tuto práci!' })
    end

    local currentService = player.get('inService')
    if currentService == jobName then
        player.set('inService', false, true)
        TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = 'Odešel jsi ze služby.' })
    else
        player.set('inService', jobName, true)
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Nastoupil jsi do služby.' })
    end
end)

-- 3. Tichý alarm (Příprava pro napojení na dispatch)
RegisterNetEvent('unijob:server:silentAlarm', function(jobName, coords)
    local src = source
    local jobConfig = Config.Jobs[jobName]
    if not jobConfig then return end

    -- ZDE NAPOJ SVŮJ DISPATCH SYSTÉM
    print(('[SILENT ALARM] Spuštěn tichý alarm u frakce: %s na souřadnicích: %s'):format(jobConfig.label, tostring(coords)))

    -- Základní notifikace pro všechny policisty ve službě
    local players = Ox.GetPlayers({ inService = 'police' })
    for i = 1, #players do
        local cop = players[i]
        TriggerClientEvent('ox_lib:notify', cop.source, {
            title = 'Tichý alarm!',
            description = ('Byl spuštěn tichý poplach v objektu: %s'):format(jobConfig.label),
            type = 'error',
            duration = 8000
        })
    end
end)

-- 4. Poutání (vyžaduje item pouta)
RegisterNetEvent('unijob:server:cuffPlayer', function(targetId)
    local src = source
    local count = exports.ox_inventory:Search(src, 'count', Config.Items.Cuffs)
    
    if count < 1 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Nemáš u sebe pouta!' })
    end

    local targetState = Player(targetId).state
    if targetState.isCuffed then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Osoba už je spoutaná!' })
    end

    -- Odebrání pout z inventáře
    if exports.ox_inventory:RemoveItem(src, Config.Items.Cuffs, 1) then
        targetState:set('isCuffed', true, true)
        TriggerClientEvent('unijob:client:getCuffed', targetId, src)
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Spoutal jsi osobu.' })
    end
end)

-- 5. Odpoutání (vyžaduje item klíč a vrací pouta do inventáře)
RegisterNetEvent('unijob:server:uncuffPlayer', function(targetId)
    local src = source
    local count = exports.ox_inventory:Search(src, 'count', Config.Items.Key)
    
    if count < 1 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Nemáš klíček od pout!' })
    end

    local targetState = Player(targetId).state
    if not targetState.isCuffed then return end

    targetState:set('isCuffed', false, true)
    -- Vrácení pout tomu, kdo osobu odpoutal
    exports.ox_inventory:AddItem(src, Config.Items.Cuffs, 1)

    TriggerClientEvent('unijob:client:getUncuffed', targetId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Odpoutal jsi osobu.' })
end)

-- 6. Vložení / Vyndání osoby z vozidla
RegisterNetEvent('unijob:server:putInVehicle', function(targetId, vehNetId)
    local targetState = Player(targetId).state
    if not targetState.isCuffed then return end
    TriggerClientEvent('unijob:client:putInVehicle', targetId, vehNetId)
end)

RegisterNetEvent('unijob:server:takeOutVehicle', function(targetId)
    local targetState = Player(targetId).state
    if not targetState.isCuffed then return end
    TriggerClientEvent('unijob:client:takeOutVehicle', targetId)
end)

-- 7. Eskortování (vedení spoutané osoby)
RegisterNetEvent('unijob:server:escortPlayer', function(targetId)
    local src = source
    local targetState = Player(targetId).state
    if not targetState.isCuffed then return end

    if targetState.escortedBy then
        -- Zrušení eskortu
        targetState:set('escortedBy', nil, true)
        TriggerClientEvent('unijob:client:stopEscort', targetId)
    else
        -- Zahájení eskortu
        targetState:set('escortedBy', src, true)
        TriggerClientEvent('unijob:client:startEscort', targetId, src)
    end
end)

-- 8. Prohledání osoby (ox_inventory)
RegisterNetEvent('unijob:server:searchPlayer', function(targetId)
    local src = source
    local targetState = Player(targetId).state
    
    if not targetState.isCuffed then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Osoba musí být spoutaná!' })
    end

    -- Vynutí otevření inventáře cílového hráče
    exports.ox_inventory:forceOpenInventory(src, 'player', targetId)
    TriggerClientEvent('ox_lib:notify', targetId, { type = 'warning', description = 'Někdo tě prohledává!' })
end)
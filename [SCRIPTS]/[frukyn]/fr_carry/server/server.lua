local activeCarries = {} -- [carrierId] = targetId
local carriedBy = {}     -- [targetId] = carrierId
local pendingRequests = {} -- [targetId] = true (ochrana proti spamu žádostí)

-- Pomocná funkce pro kontrolu vzdálenosti na serveru
local function isNearPlayer(src, target, maxDist)
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)

    if not DoesEntityExist(srcPed) or not DoesEntityExist(targetPed) then
        return false
    end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)

    return #(srcCoords - targetCoords) <= maxDist
end

-- Funkce pro bezpečné ukončení carry stavu
local function clearCarry(playerId)
    local targetId = activeCarries[playerId]
    local carrierId = carriedBy[playerId]

    if targetId then
        activeCarries[playerId] = nil
        carriedBy[targetId] = nil

        if GetPlayerEndpoint(playerId) then
            Player(playerId).state:set('carryingTarget', nil, true)
        end
        if GetPlayerEndpoint(targetId) then
            Player(targetId).state:set('carriedBy', nil, true)
        end
    elseif carrierId then
        activeCarries[carrierId] = nil
        carriedBy[playerId] = nil

        if GetPlayerEndpoint(carrierId) then
            Player(carrierId).state:set('carryingTarget', nil, true)
        end
        if GetPlayerEndpoint(playerId) then
            Player(playerId).state:set('carriedBy', nil, true)
        end
    end
end

-- Žádost o vzetí na záda
RegisterNetEvent('fr_carry:server:request', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or src == targetId or not GetPlayerEndpoint(targetId) then return end

    -- Kontrola, zda už někdo z nich není v carry stavu
    if activeCarries[src] or carriedBy[src] or activeCarries[targetId] or carriedBy[targetId] then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Carry',
            description = 'Někdo z vás už je zaneprázdněn.',
            type = 'error'
        })
    end

    -- Anti-spam kontrola
    if pendingRequests[targetId] then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Carry',
            description = 'Tento hráč už má aktivní žádost.',
            type = 'warning'
        })
    end

    -- Server-side kontrola vzdálenosti (proti exploitům)
    if not isNearPlayer(src, targetId, 4.0) then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Carry',
            description = 'Hráč je příliš daleko.',
            type = 'error'
        })
    end

    -- Získání jména přes ox_core (pokud není dostupné, použije se FiveM nick)
    local oxPlayer = Ox.GetPlayer(src)
    local requesterName = (oxPlayer and oxPlayer.get('name')) or GetPlayerName(src)

    pendingRequests[targetId] = true

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Carry',
        description = 'Žádost o přenesení byla odeslána.',
        type = 'inform'
    })

    -- Odeslání dotazu cílovému hráči přes ox_lib callback
    local accepted = lib.callback.await('fr_carry:client:askPermission', targetId, requesterName)
    pendingRequests[targetId] = nil

    if not accepted then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Carry',
            description = 'Hráč žádost odmítl.',
            type = 'error'
        })
    end

    -- Opětovná kontrola vzdálenosti a stavů po odkliknutí dialogu
    if not isNearPlayer(src, targetId, 4.0) then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Carry',
            description = 'Hráč se mezitím vzdálil.',
            type = 'error'
        })
    end

    if activeCarries[src] or carriedBy[src] or activeCarries[targetId] or carriedBy[targetId] then
        return
    end

    -- Aktivace carry přes State Bags
    activeCarries[src] = targetId
    carriedBy[targetId] = src

    Player(src).state:set('carryingTarget', targetId, true)
    Player(targetId).state:set('carriedBy', src, true)
end)

-- Ukončení nošení
RegisterNetEvent('fr_carry:server:stop', function()
    local src = source
    clearCarry(src)
end)

-- Vyčištění při odpojení hráče
AddEventHandler('playerDropped', function()
    local src = source
    pendingRequests[src] = nil
    clearCarry(src)
end)
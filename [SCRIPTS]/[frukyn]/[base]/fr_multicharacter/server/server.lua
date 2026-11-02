local pendingOrigins = {}

local function getSlotLimit(source)
    local limit = GetConvarInt('ox:characterSlots', Config.baseSlots or 1)

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier and identifier:match('discord:') then
            local discordId = identifier:gsub('discord:', '')
            for _, unlock in ipairs(Config.slotUnlocks or {}) do
                if tostring(unlock.role) == tostring(discordId) then
                    limit = limit + (unlock.slots or 0)
                end
            end
        end
    end

    return limit
end

local function giveOriginRewards(source, originName)
    local origin = Config.origins[originName]
    if not origin then return end

    if exports.ox_inventory then
        if origin.startMoney then
            exports.ox_inventory:AddItem(source, 'money', origin.startMoney)
        end

        for _, item in ipairs(origin.items or {}) do
            if item and item.name then
                exports.ox_inventory:AddItem(source, item.name, item.count or 1)
            end
        end
    end
end

RegisterNetEvent('fr_multicharacter:prepareCharacter', function(data)
    local source = source
    if not data or type(data) ~= 'table' then
        pendingOrigins[source] = Config.defaultOrigin
        return
    end

    pendingOrigins[source] = data.origin or Config.defaultOrigin
end)

RegisterNetEvent('fr_multicharacter:requestSlotLimit', function()
    local src = source
    TriggerClientEvent('fr_multicharacter:slotLimit', src, getSlotLimit(src))
end)

RegisterNetEvent('fr_multicharacter:enrichCharacters', function(charList)
    local src = source
    local limit = getSlotLimit(src)

    if not charList or type(charList) ~= 'table' then
        TriggerClientEvent('fr_multicharacter:openEnrichedSelection', src, {}, limit)
        return
    end

    for _, char in ipairs(charList) do
        if char.charId then
            -- 1. Získání data narození a pohlaví z databáze
            local charRes = MySQL.single.await('SELECT DATE_FORMAT(`dateOfBirth`, "%d.%m.%Y") AS `dateOfBirth`, `gender` FROM `characters` WHERE `charId` = ?', { char.charId })
            if charRes then
                char.date = charRes.dateOfBirth or char.date
                char.gender = charRes.gender or char.gender
            end

            -- 2. Získání práce (frakcí) z databáze
            local groupsRes = MySQL.query.await('SELECT `name` FROM `character_groups` WHERE `charId` = ?', { char.charId })
            if groupsRes and #groupsRes > 0 then
                char.groups = {}
                for _, g in ipairs(groupsRes) do
                    char.groups[g.name] = 1
                end
            end

            -- 3. Získání vzhledu z illenium-appearance (tabulka playerskins)
            local skinRes = MySQL.single.await('SELECT `skin` FROM `playerskins` WHERE `citizenid` = ? OR `citizenid` = ? ORDER BY `active` DESC LIMIT 1', {
                tostring(char.charId),
                tostring(char.stateId or char.charId)
            })
            if skinRes and skinRes.skin then
                char.appearance = json.decode(skinRes.skin)
            end
        end
    end

    TriggerClientEvent('fr_multicharacter:openEnrichedSelection', src, charList, limit)
end)

AddEventHandler('ox:playerLoaded', function(playerId)
    local origin = pendingOrigins[playerId]
    if origin then
        giveOriginRewards(playerId, origin)
        pendingOrigins[playerId] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('[%s] ready'):format(GetCurrentResourceName()))
end)

exports('GetSlotLimit', function(source)
    return getSlotLimit(source)
end)
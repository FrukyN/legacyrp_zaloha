local Ox = require '@ox_core.lib.init'

local playerState, consumeCooldown, invalidAttempts, pendingUse = {}, {}, {}, {}

local statusNames = { 'hunger', 'thirst', 'stress', 'alcohol', 'drug' }

local function banPlayer(src, reason, details)
    if GetResourceState('ElectronAC') == 'started' then exports['ElectronAC']:banPlayer(src, reason, details or '{}', true) else DropPlayer(src, reason) end
end

local function clamp(value) return math.max(0, math.min(Config.MaxNeed, math.floor(value))) end
local function nowTs() return os.time() end

local function punishInvalid(src, reason, details)
    invalidAttempts[src] = (invalidAttempts[src] or 0) + 1
    if invalidAttempts[src] >= Config.MaxInvalidAttempts then banPlayer(src, reason, details) end
end

local function getNeeds(src)
    local player = Ox.GetPlayer(src)
    if not player then return end

    local needs = {}
    for i = 1, #statusNames do
        local name = statusNames[i]
        needs[name] = player.getStatus(name) or Config.Defaults[name] or 0
    end

    needs.lastDamageAt = playerState[src] and playerState[src].lastDamageAt or 0
    return needs
end

local function sendState(src)
    local needs = getNeeds(src)
    if needs then TriggerClientEvent('fr_needs:client:setState', src, needs) end
end

local function adjustStatus(src, key, amount, inverted)
    if not amount or amount == 0 then return end

    local player = Ox.GetPlayer(src)
    if not player then return end

    local value = math.abs(amount)
    local shouldAdd = amount > 0
    if inverted then shouldAdd = not shouldAdd end

    if shouldAdd then
        player.addStatus(key, value)
    else
        player.removeStatus(key, value)
    end
end

local function getSpoilageMeta(itemDef, metadata)
    local spoil = itemDef.spoilage
    metadata = metadata or {}

    if not spoil or not spoil.enabled then return metadata, nil, nil end

    local hours = tonumber(spoil.hours) or 48
    local createdAt = tonumber(metadata.createdAt) or nowTs()
    local spoilsAt = tonumber(metadata.spoilsAt) or (createdAt + hours * 3600)
    local left = spoilsAt - nowTs()
    local pct = math.max(0, math.floor((left / (hours * 3600)) * 100))

    metadata.createdAt = createdAt
    metadata.spoilsAt = spoilsAt
    metadata.freshness = pct
    metadata.state = left <= 0 and 'spoiled' or 'fresh'

    return metadata, left <= 0, pct
end

local function initOrUpdateSlotMeta(src, slotData, itemDef, maxUses)
    local metadata = slotData.metadata or {}
    local usesLeft = tonumber(metadata.usesLeft) or maxUses

    metadata.usesLeft = usesLeft
    metadata.maxUses = maxUses
    metadata.durability = math.floor((usesLeft / maxUses) * 100)
    metadata, _, _ = getSpoilageMeta(itemDef, metadata)

    exports.ox_inventory:SetMetadata(src, slotData.slot, metadata)
    exports.ox_inventory:SetDurability(src, slotData.slot, metadata.durability)
    return metadata, usesLeft
end

local function handleSpoiledItem(src, slot, itemName, itemDef, metadata)
    local spoil = itemDef.spoilage
    if not spoil or not spoil.enabled then return false end

    local _, isSpoiled = getSpoilageMeta(itemDef, metadata)
    if not isSpoiled then return false end

    exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)

    if spoil.onSpoil and spoil.onSpoil.action == 'replace' and spoil.onSpoil.item then
        exports.ox_inventory:AddItem(src, spoil.onSpoil.item, spoil.onSpoil.count or 1)
    end

    TriggerClientEvent('fr_needs:client:warn', src, 'Item se zkazil.')
    return true
end

local function applyGiveItems(src, itemDef)
    if not itemDef.giveItems then return true end
    for i = 1, #itemDef.giveItems do
        local gift = itemDef.giveItems[i]
        if not exports.ox_inventory:AddItem(src, gift.name, gift.count or 1, gift.metadata) then return false end
    end
    return true
end

local function applyItemEffects(src, itemName, itemDef, usesLeft, freshness)
    adjustStatus(src, 'hunger', itemDef.hunger or 0, true)
    adjustStatus(src, 'thirst', itemDef.thirst or 0, true)
    adjustStatus(src, 'stress', itemDef.stress or 0)
    adjustStatus(src, 'alcohol', itemDef.alcohol or 0)
    adjustStatus(src, 'drug', itemDef.drug or 0)
    TriggerClientEvent('fr_needs:client:consumed', src, itemName, usesLeft, freshness)
    sendState(src)
end

local function getRestrictionError(itemDef, clientState, src)
    clientState = clientState or {}
    if itemDef.denyInVehicle then local ped = GetPlayerPed(src) if ped and ped > 0 and GetVehiclePedIsIn(ped, false) ~= 0 then return 'Tento item nemuzes pouzit v aute.' end end
    if itemDef.denyWhileSwimming and clientState.isSwimming then return 'Tento item nemuzes pouzit ve vode.' end
    if itemDef.denyWhileSprinting and clientState.isSprinting then return 'Tento item nemuzes pouzit pri sprintu.' end
    return nil
end

local function getFirstSlot(src, itemName)
    local found = exports.ox_inventory:Search(src, 1, itemName)
    if type(found) ~= 'table' then return nil end
    for _, v in pairs(found) do if v and v.slot and (v.count or 0) > 0 then return v end end
    return nil
end

local function beginUsePrompt(src, itemName)
    local itemDef = Config.Items[itemName]
    if not itemDef then return punishInvalid(src, 'fr_needs: invalid item', json.encode({ item = itemName })) end

    local now = GetGameTimer()
    if consumeCooldown[src] and consumeCooldown[src] > now then return TriggerClientEvent('fr_needs:client:warn', src, 'Pockej chvili pred dalsim pouzitim.') end

    local slotData = getFirstSlot(src, itemName)
    if not slotData then return punishInvalid(src, 'fr_needs: missing slot', json.encode({ item = itemName })) end

    local maxUses = math.max(1, tonumber(itemDef.uses) or 1)
    local metadata, usesLeft = initOrUpdateSlotMeta(src, slotData, itemDef, maxUses)

    if handleSpoiledItem(src, slotData.slot, itemName, itemDef, metadata) then return end

    local freshness = tonumber(metadata.freshness) or 100
    local token = ('%s:%s:%s'):format(src, itemName, math.random(111111, 999999))
    pendingUse[src] = { token = token, itemName = itemName, slot = slotData.slot, usesLeft = usesLeft, maxUses = maxUses, freshness = freshness, expiresAt = now + Config.UsePromptTimeoutMs }
    TriggerClientEvent('fr_needs:client:showUsePrompt', src, token, itemName, usesLeft, maxUses, freshness)
end

RegisterNetEvent('fr_needs:server:usePromptResult', function(token, action, clientState)
    local src = source
    local prompt = pendingUse[src]
    if not prompt then return end
    pendingUse[src] = nil

    if prompt.token ~= token then return punishInvalid(src, 'fr_needs: invalid use token', json.encode({ token = token })) end
    if GetGameTimer() > prompt.expiresAt then return TriggerClientEvent('fr_needs:client:warn', src, 'Pouziti itemu vyprselo.') end
    if action == 'hide' then return TriggerClientEvent('fr_needs:client:hidden', src) end
    if action ~= 'use' then return punishInvalid(src, 'fr_needs: invalid use action', json.encode({ action = action })) end

    local itemDef = Config.Items[prompt.itemName]
    if not itemDef then return end

    local restrictionError = getRestrictionError(itemDef, clientState, src)
    if restrictionError then return TriggerClientEvent('fr_needs:client:warn', src, restrictionError) end

    local current = exports.ox_inventory:GetSlot(src, prompt.slot)
    if not current or current.name ~= prompt.itemName then return punishInvalid(src, 'fr_needs: slot mismatch', json.encode({ slot = prompt.slot })) end

    local metadata, isSpoiled, freshness = getSpoilageMeta(itemDef, current.metadata)
    if isSpoiled then
        handleSpoiledItem(src, prompt.slot, prompt.itemName, itemDef, metadata)
        return
    end

    local usesLeft = prompt.usesLeft - 1
    if itemDef.remove then
        if usesLeft <= 0 then
            if not exports.ox_inventory:RemoveItem(src, prompt.itemName, 1, nil, prompt.slot) then return punishInvalid(src, 'fr_needs: remove failed', json.encode({ slot = prompt.slot })) end
        else
            metadata.usesLeft = usesLeft
            metadata.maxUses = prompt.maxUses
            metadata.durability = math.floor((usesLeft / prompt.maxUses) * 100)
            exports.ox_inventory:SetMetadata(src, prompt.slot, metadata)
            exports.ox_inventory:SetDurability(src, prompt.slot, metadata.durability)
        end
    end

    if not applyGiveItems(src, itemDef) then TriggerClientEvent('fr_needs:client:warn', src, 'Nemas misto pro nove itemy.') end
    consumeCooldown[src] = GetGameTimer() + Config.ConsumptionCooldownMs
    applyItemEffects(src, prompt.itemName, itemDef, math.max(0, usesLeft), freshness)
end)

lib.callback.register('fr_needs:server:getState', function(src) return getNeeds(src) end)

RegisterNetEvent('fr_needs:server:drinkStation', function(stationId)
    local src, station = source, Config.TargetDrinkStations[tonumber(stationId)]
    if not station then return punishInvalid(src, 'fr_needs: invalid station', json.encode({ stationId = stationId })) end
    adjustStatus(src, 'thirst', station.thirstGain or 0, true)
    adjustStatus(src, 'stress', -(station.stressRelief or 0))
    sendState(src)
end)

local function onPlayerLoaded(src)
    invalidAttempts[src] = 0
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end

    playerState[src] = { lastDamageAt = 0 }

    for i = 1, #statusNames do
        local name = statusNames[i]
        if player.getStatus(name) == nil then
            player.setStatus(name, Config.Defaults[name] or 0)
        end
    end

    sendState(src)
end

local function onPlayerDropped(src)
    playerState[src], consumeCooldown[src], invalidAttempts[src], pendingUse[src] = nil, nil, nil, nil
end

AddEventHandler('ox:playerLoaded', function(src)
    onPlayerLoaded(src)
end)

AddEventHandler('ox:playerLogout', function(src)
    onPlayerDropped(src)
end)

AddEventHandler('playerDropped', function()
    onPlayerDropped(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
end)

local function ensureOxStatus(name, data)
    local exists = MySQL.scalar.await('SELECT 1 FROM ox_statuses WHERE name = ? LIMIT 1', { name })

    if exists then
        MySQL.update.await('UPDATE ox_statuses SET `default` = ?, onTick = ? WHERE name = ?', { data.default or 0, data.onTick or 0, name })
    else
        MySQL.insert.await('INSERT INTO ox_statuses (`name`, `default`, onTick) VALUES (?, ?, ?)', { name, data.default or 0, data.onTick or 0 })
    end
end

local function ensureOxStatuses()
    for name, data in pairs(Config.OxStatuses or {}) do
        ensureOxStatus(name, data)
    end

    ExecuteCommand('reloadstatuses')
end

CreateThread(function()
    Wait(2000)
    ensureOxStatuses()
    Wait(500)

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and not playerState[src] then
            onPlayerLoaded(src)
        end
    end

    local itemFilter = {}
    for itemName in pairs(Config.Items) do
        itemFilter[itemName] = true
    end

    exports.ox_inventory:registerHook('usingItem', function(payload)
        local src = payload.source
        local item = payload.item
        if not src or not item or not item.name or not Config.Items[item.name] then return end
        beginUsePrompt(src, item.name)
        return false
    end, {
        itemFilter = itemFilter
    })
end)

CreateThread(function()
    while true do
        Wait(Config.SpoilageCheckInterval)
        for src in pairs(playerState) do
            for itemName, itemDef in pairs(Config.Items) do
                if itemDef.spoilage and itemDef.spoilage.enabled then
                    local found = exports.ox_inventory:Search(src, 1, itemName)
                    if type(found) == 'table' then
                        for _, slotData in pairs(found) do
                            if slotData and slotData.slot and (slotData.count or 0) > 0 then
                                local metadata, isSpoiled = getSpoilageMeta(itemDef, slotData.metadata)
                                if isSpoiled then
                                    handleSpoiledItem(src, slotData.slot, itemName, itemDef, metadata)
                                else
                                    exports.ox_inventory:SetMetadata(src, slotData.slot, metadata)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.ServerTick)
        local now = GetGameTimer()
        for src, runtime in pairs(playerState) do
            local needs = getNeeds(src)
            if needs and (needs.hunger >= Config.Starvation.hungerThreshold or needs.thirst >= Config.Starvation.thirstThreshold) then
                adjustStatus(src, 'stress', Config.Starvation.stressPerTick)
                if now - (runtime.lastDamageAt or 0) >= Config.Starvation.damageEveryMs then
                    runtime.lastDamageAt = now
                    TriggerClientEvent('fr_needs:client:applyDamage', src, Config.Starvation.damage)
                end
            end

            if needs and ((needs.alcohol > 0 and needs.alcohol <= Config.Withdrawal.threshold) or (needs.drug > 0 and needs.drug <= Config.Withdrawal.threshold)) then
                adjustStatus(src, 'stress', Config.Withdrawal.stressPerTick)
                if math.random(1, 100) <= Config.Withdrawal.stumbleChance then TriggerClientEvent('fr_needs:client:stumble', src) end
            end

            sendState(src)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.SaveInterval)
        for src in pairs(playerState) do sendState(src) end
    end
end)

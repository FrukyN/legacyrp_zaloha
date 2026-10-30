local createdBlips = {}
local externalBlips = {}
local lastJobCounts = {}

local function createSingleBlip(data)
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, data.scale or 0.8)
    SetBlipAsShortRange(blip, true)

    if data.dynamic then
        local count = lastJobCounts[data.job] or 0
        local minOnline = data.minOnline or 1
        local offlineColor = data.offlineColor or 39
        local onlineColor = data.onlineColor or 2

        local targetColor = (count >= minOnline) and onlineColor or offlineColor
        SetBlipColour(blip, targetColor)
    else
        SetBlipColour(blip, data.color or 0)
    end

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("<font face='ChakraPetch-Regular'>" .. (data.name or "Blip") .. "</font>")
    EndTextCommandSetBlipName(blip)

    return blip
end

local function updateAllDynamicBlips()
    -- 1. Aktualizace blipů z lokálního Config.Blips
    for i, data in ipairs(Config.Blips) do
        if data.dynamic and createdBlips[i] and DoesBlipExist(createdBlips[i]) then
            local count = lastJobCounts[data.job] or 0
            local targetColor = (count >= (data.minOnline or 1)) and (data.onlineColor or 2) or (data.offlineColor or 39)

            if GetBlipColour(createdBlips[i]) ~= targetColor then
                SetBlipColour(createdBlips[i], targetColor)
            end
        end
    end

    -- 2. Aktualizace blipů přidaných přes export (např. z ox_unijob)
    for id, item in pairs(externalBlips) do
        local data = item.data
        local blip = item.blip
        if data.dynamic and blip and DoesBlipExist(blip) then
            local count = lastJobCounts[data.job] or 0
            local targetColor = (count >= (data.minOnline or 1)) and (data.onlineColor or 2) or (data.offlineColor or 39)

            if GetBlipColour(blip) ~= targetColor then
                SetBlipColour(blip, targetColor)
            end
        end
    end
end

local function initBlips()
    -- Smazání a znovuvytvoření Config blipů
    for _, blip in pairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    createdBlips = {}

    for i, data in ipairs(Config.Blips) do
        createdBlips[i] = createSingleBlip(data)
    end

    -- Obnovení externích blipů (pokud už byly zaregistrovány)
    for id, item in pairs(externalBlips) do
        if DoesBlipExist(item.blip) then RemoveBlip(item.blip) end
        item.blip = createSingleBlip(item.data)
    end

    TriggerServerEvent('dynblips:request')
end

RegisterNetEvent('dynblips:update', function(jobCounts)
    lastJobCounts = jobCounts or {}
    updateAllDynamicBlips()
end)

RegisterNetEvent('ox:playerLoaded', function()
    initBlips()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    initBlips()
end)

-- ==========================================
-- EXPORTY PRO POUŽITÍ V JINÝCH SKRIPTECH
-- ==========================================

exports('RegisterBlip', function(id, data)
    if not id or not data or not data.coords then return false end

    -- Pokud blip s tímto ID už existuje, nejdřív ho smažeme
    if externalBlips[id] and DoesBlipExist(externalBlips[id].blip) then
        RemoveBlip(externalBlips[id].blip)
    end

    local blip = createSingleBlip(data)
    externalBlips[id] = {
        blip = blip,
        data = data
    }

    return blip
end)

exports('RemoveBlip', function(id)
    if externalBlips[id] then
        if DoesBlipExist(externalBlips[id].blip) then
            RemoveBlip(externalBlips[id].blip)
        end
        externalBlips[id] = nil
        return true
    end
    return false
end)
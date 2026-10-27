local createdBlips = {}

local function initBlips()
    for _, blip in pairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    createdBlips = {}

    for i, data in ipairs(Config.Blips) do
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, data.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, data.scale or 0.8)
        SetBlipAsShortRange(blip, true)

        if data.dynamic then
            SetBlipColour(blip, data.offlineColor)
        else
            SetBlipColour(blip, data.color or 0)
        end

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("<font face='ChakraPetch-Regular'>" .. data.name .. "</font>")
        EndTextCommandSetBlipName(blip)

        createdBlips[i] = blip
    end

    TriggerServerEvent('dynblips:request')
end

RegisterNetEvent('dynblips:update', function(jobCounts)
    for i, data in ipairs(Config.Blips) do
        if data.dynamic and createdBlips[i] and DoesBlipExist(createdBlips[i]) then
            local count = jobCounts[data.job] or 0
            local targetColor = (count >= data.minOnline) and data.onlineColor or data.offlineColor

            if GetBlipColour(createdBlips[i]) ~= targetColor then
                SetBlipColour(createdBlips[i], targetColor)
            end
        end
    end
end)

RegisterNetEvent('ox:playerLoaded', function()
    initBlips()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    initBlips()
end)

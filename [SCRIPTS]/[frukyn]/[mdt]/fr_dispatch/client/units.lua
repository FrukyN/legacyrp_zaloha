local unitBlips = {}
local isEmergency = false

-- Kontrola, zda hráč patří k IZS
local function checkEmergencyDuty()
    local groups = LocalPlayer.state.groups or {}
    local inService = LocalPlayer.state.inService

    for jobName in pairs(Config.EmergencyJobs) do
        if groups[jobName] and (inService == jobName or inService == true or inService == nil) then
            return true, jobName
        end
    end
    return false, nil
end

-- Aktualizace zobrazených jednotek na mapě
RegisterNetEvent('fr_dispatch:client:syncUnits', function(units)
    local isAuthorized, myJob = checkEmergencyDuty()
    if not isAuthorized then
        -- Pokud hráč není ve službě IZS, smažeme všechny live blipy
        for _, b in pairs(unitBlips) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
        unitBlips = {}
        return
    end

    local myServerId = cache.serverId

    -- Odstranění jednotek, které se odpojily
    for src, blip in pairs(unitBlips) do
        local exists = false
        for _, u in ipairs(units) do
            if u.source == src then
                exists = true
                break
            end
        end
        if not exists then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            unitBlips[src] = nil
        end
    end

    -- Vytvoření / aktualizace blipů
    for _, u in ipairs(units) do
        if u.source ~= myServerId and u.coords then
            local blip = unitBlips[u.source]
            if not blip or not DoesBlipExist(blip) then
                blip = AddBlipForCoord(u.coords.x, u.coords.y, u.coords.z)
                
                local sprite = 1
                local color = 3
                if u.job == 'ambulance' then
                    sprite = 153
                    color = 1
                elseif u.inVehicle then
                    sprite = 56
                    color = 3
                end

                SetBlipSprite(blip, sprite)
                SetBlipColour(blip, color)
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, true)
                ShowHeadingIndicatorOnBlip(blip, true)

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(("<font face='ChakraPetch-Regular'>[%s] %s</font>"):format(u.callsign or 'Jednotka', u.name or 'Důstojník'))
                EndTextCommandSetBlipName(blip)

                unitBlips[u.source] = blip
            else
                SetBlipCoords(blip, u.coords.x, u.coords.y, u.coords.z)
                if u.heading then
                    SetBlipRotation(blip, math.floor(u.heading))
                end
            end
        end
    end
end)

-- Periodické odesílání vlastní polohy na server pro synchronizaci
CreateThread(function()
    while true do
        Wait(Config.LiveBlipInterval)
        local isAuthorized, job = checkEmergencyDuty()
        if isAuthorized then
            local ped = cache.ped
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local inVehicle = IsPedInAnyVehicle(ped, false)

            TriggerServerEvent('fr_dispatch:server:updateUnitCoords', {
                coords = coords,
                heading = heading,
                inVehicle = inVehicle,
                job = job
            })
        end
    end
end)

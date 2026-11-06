local activeBlips = {}
local lastCall = nil
local lastGunshot = 0
local lastCrash = 0

-- Pomocná funkce pro získání názvu ulice a zóny
local function getLocationInfo(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    if crossingHash ~= 0 then
        streetName = streetName .. ' / ' .. GetStreetNameFromHashKey(crossingHash)
    end
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    return streetName, zone ~= 'NULL' and zone or ''
end

-- Vytvoření blipu na mapě
local function createCallBlip(data)
    local cfg = Config.Alerts[data.alertType] or {}
    local blipCfg = cfg.blip or { sprite = 161, color = 1, scale = 1.0 }

    -- Hlavní ikona
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, blipCfg.sprite or 161)
    SetBlipColour(blip, blipCfg.color or 1)
    SetBlipScale(blip, blipCfg.scale or 1.0)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, false)

    if blipCfg.flash then
        SetBlipFlashes(blip, true)
    end

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("<font face='ChakraPetch-Regular'>[%s] %s</font>"):format(cfg.code or '10-00', cfg.title or 'Výzva'))
    EndTextCommandSetBlipName(blip)

    -- Radius kruh pro oblast hledání
    local radiusBlip = nil
    if blipCfg.radius then
        radiusBlip = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, blipCfg.radius)
        SetBlipColour(radiusBlip, blipCfg.color or 1)
        SetBlipAlpha(radiusBlip, 120)
    end

    table.insert(activeBlips, {
        blip = blip,
        radius = radiusBlip,
        expires = GetGameTimer() + (Config.BlipDuration * 1000)
    })
end

-- Čištění vypršených blipů
CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for i = #activeBlips, 1, -1 do
            local item = activeBlips[i]
            if now >= item.expires then
                if DoesBlipExist(item.blip) then RemoveBlip(item.blip) end
                if item.radius and DoesBlipExist(item.radius) then RemoveBlip(item.radius) end
                table.remove(activeBlips, i)
            end
        end
    end
end)

-- Přijetí hlášení ze serveru
RegisterNetEvent('fr_dispatch:client:notify', function(callData)
    lastCall = callData

    -- Vytvoření blipu na minimapě
    createCallBlip(callData)

    -- Zobrazení NUI notifikace
    SendNUIMessage({
        action = 'newAlert',
        data = callData
    })
end)

-- Rychlá reakce na hovor klávesou G
local function respondToLastCall()
    if not lastCall or not lastCall.coords then
        lib.notify({ title = 'Dispatch', description = 'Není k dispozici žádná aktivní výzva.', type = 'warning' })
        return
    end

    -- Nastavení GPS
    SetNewWaypoint(lastCall.coords.x, lastCall.coords.y)
    lib.notify({
        title = 'Dispatch',
        description = ('GPS nastavena na hovor #%s: %s'):format(lastCall.id or '?', lastCall.title or ''),
        type = 'success',
        icon = 'fa-solid fa-location-dot'
    })

    -- Oznámení na server, že jednotka reaguje
    TriggerServerEvent('fr_dispatch:server:respondToCall', lastCall.id)
end

lib.addKeybind({
    name = 'dispatch_respond',
    description = 'Reagovat na poslední dispatch výzvu',
    defaultKey = Config.QuickRespondKey,
    onPressed = respondToLastCall
})

-- Tísňové tlačítko pro složky IZS (/panic nebo /1099)
RegisterCommand('panic', function()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local street, zone = getLocationInfo(coords)

    TriggerServerEvent('fr_dispatch:server:sendPanic', {
        coords = coords,
        street = street,
        zone = zone
    })
end, false)
RegisterKeyMapping('panic', 'Aktivovat tísňové tlačítko (Panic Button)', 'keyboard', '')

-- Občanská linka 158 (Policie)
RegisterCommand('158', function(source, args)
    local msg = table.concat(args, ' ')
    if not msg or msg:gsub('%s+', '') == '' then
        lib.notify({ title = 'Linka 158', description = 'Použití: /158 [zpráva]', type = 'error' })
        return
    end

    local coords = GetEntityCoords(cache.ped)
    local street, zone = getLocationInfo(coords)

    TriggerServerEvent('fr_dispatch:server:citizenCall', 'citizen_call', msg, coords, street, zone)
    lib.notify({ title = 'Linka 158', description = 'Tísňová zpráva byla odeslána policii.', type = 'success' })
end, false)

-- Občanská linka 155 (Záchranka)
RegisterCommand('155', function(source, args)
    local msg = table.concat(args, ' ')
    if not msg or msg:gsub('%s+', '') == '' then
        lib.notify({ title = 'Linka 155', description = 'Použití: /155 [zpráva]', type = 'error' })
        return
    end

    local coords = GetEntityCoords(cache.ped)
    local street, zone = getLocationInfo(coords)

    TriggerServerEvent('fr_dispatch:server:citizenCall', 'medic_call', msg, coords, street, zone)
    lib.notify({ title = 'Linka 155', description = 'Tísňová zpráva byla odeslána záchranné službě.', type = 'success' })
end, false)

-- Automatická detekce střelby
CreateThread(function()
    while true do
        local sleep = 500
        local ped = cache.ped

        if IsPedArmed(ped, 4) then
            sleep = 50
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if now - lastGunshot >= Config.Cooldowns.gunshot then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    local isIgnored = false

                    for i = 1, #Config.IgnoredWeapons do
                        if currentWeapon == Config.IgnoredWeapons[i] then
                            isIgnored = true
                            break
                        end
                    end

                    -- Kontrola tlumiče
                    if not isIgnored and not IsPedCurrentWeaponSilenced(ped) then
                        lastGunshot = now
                        local coords = GetEntityCoords(ped)
                        local street, zone = getLocationInfo(coords)
                        local inVeh = IsPedInAnyVehicle(ped, false)
                        local vehData = nil

                        if inVeh then
                            local veh = GetVehiclePedIsIn(ped, false)
                            local model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                            local plate = GetVehicleNumberPlateText(veh)
                            local color1, color2 = GetVehicleColours(veh)
                            vehData = {
                                model = model,
                                plate = plate,
                                color = ('Barva #%s'):format(color1)
                            }
                        end

                        TriggerServerEvent('fr_dispatch:server:reportGunshots', {
                            coords = coords,
                            street = street,
                            zone = zone,
                            inVehicle = inVeh,
                            vehicle = vehData
                        })
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- Automatická detekce těžké autonehody
CreateThread(function()
    while true do
        local sleep = 1000
        local veh = cache.vehicle

        if veh and cache.seat == -1 then
            sleep = 200
            local speed = GetEntitySpeed(veh) * 3.6 -- km/h
            if speed > 85.0 and HasEntityCollidedWithAnything(veh) then
                local now = GetGameTimer()
                if now - lastCrash > 30000 then
                    lastCrash = now
                    local coords = GetEntityCoords(veh)
                    local street, zone = getLocationInfo(coords)
                    local model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                    local plate = GetVehicleNumberPlateText(veh)

                    TriggerServerEvent('fr_dispatch:server:reportCrash', {
                        coords = coords,
                        street = street,
                        zone = zone,
                        model = model,
                        plate = plate,
                        speed = math.floor(speed)
                    })
                end
            end
        end

        Wait(sleep)
    end
end)

-- Detekce policisty / záchranáře v bezvědomí (10-13)
RegisterNetEvent('fr_death:client:revive', function()
    -- Při oživení reset
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, isDead)
    if isDead then
        local coords = GetEntityCoords(cache.ped)
        local street, zone = getLocationInfo(coords)
        TriggerServerEvent('fr_dispatch:server:officerDown', {
            coords = coords,
            street = street,
            zone = zone
        })
    end
end)

-- Exporty pro jiné skripty (např. vykrádačky obchodů, banky, unijob alarm)
exports('CustomAlert', function(data)
    if not data or not data.alertType then return end
    local coords = data.coords or GetEntityCoords(cache.ped)
    local street, zone = getLocationInfo(coords)

    data.coords = coords
    data.street = data.street or street
    data.zone = data.zone or zone

    TriggerServerEvent('fr_dispatch:server:customAlert', data)
end)

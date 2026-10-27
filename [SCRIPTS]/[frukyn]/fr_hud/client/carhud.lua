local compassZones = { "S", "JZ", "Z", "SZ", "S", "SV", "V", "JV", "J" }
local wasMinimapVisible = true

local cruiseActive = false
local limiterActive = false

local function GetCompassDirection(heading)
    local hash = math.floor((heading + 22.5) / 45.0)
    return compassZones[hash + 1] or "N/A"
end

-- ==========================================
-- LOGIKA BLINKRŮ
-- ==========================================

-- Levý blinkr (Výchozí: Šipka doleva)
RegisterCommand('blinkr_levy', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local state = GetVehicleIndicatorLights(veh)
        if state == 1 or state == 3 then
            SetVehicleIndicatorLights(veh, 1, false) -- Vypnout levý
        else
            SetVehicleIndicatorLights(veh, 1, true)  -- Zapnout levý
            SetVehicleIndicatorLights(veh, 0, false) -- Vypnout pravý
        end
    end
end, false)
RegisterKeyMapping('blinkr_levy', "<font face='ChakraPetch-Regular'>Levý blinkr</font>", 'keyboard', 'LEFT')

-- Pravý blinkr (Výchozí: Šipka doprava)
RegisterCommand('blinkr_pravy', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local state = GetVehicleIndicatorLights(veh)
        if state == 2 or state == 3 then
            SetVehicleIndicatorLights(veh, 0, false) -- Vypnout pravý
        else
            SetVehicleIndicatorLights(veh, 0, true)  -- Zapnout pravý
            SetVehicleIndicatorLights(veh, 1, false) -- Vypnout levý
        end
    end
end, false)
RegisterKeyMapping('blinkr_pravy', "<font face='ChakraPetch-Regular'>Pravý blinkr</font>", 'keyboard', 'RIGHT')

-- Výstražné blinkry (Výchozí: Backspace)
RegisterCommand('blinkr_vystrazne', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local state = GetVehicleIndicatorLights(veh)
        if state == 3 then
            -- Pokud blikají oba, vypneme je
            SetVehicleIndicatorLights(veh, 0, false)
            SetVehicleIndicatorLights(veh, 1, false)
        else
            -- Zapneme oba
            SetVehicleIndicatorLights(veh, 0, true)
            SetVehicleIndicatorLights(veh, 1, true)
        end
    end
end, false)
RegisterKeyMapping('blinkr_vystrazne', "<font face='ChakraPetch-Regular'>Výstražné blinkry</font>", 'keyboard', 'BACK')


-- ==========================================
-- LOGIKA TEMPOMATU & OMEZOVAČE
-- ==========================================
local function resetSpeed(veh)
    local maxSpeed = GetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveMaxFlatVel")
    SetEntityMaxSpeed(veh, maxSpeed > 0.0 and maxSpeed or 1000.0)
end

RegisterCommand('omezovac', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        if limiterActive then
            limiterActive = false
            resetSpeed(veh)
            lib.notify({ title = 'Omezovač', description = 'Vypnut', type = 'info' })
        else
            local speed = GetEntitySpeed(veh)
            if speed > 2.0 then
                limiterActive = true
                if cruiseActive then cruiseActive = false end
                SetEntityMaxSpeed(veh, speed)
                lib.notify({ title = 'Omezovač', description = 'Zapnut', type = 'success' })
            else
                lib.notify({ title = 'Omezovač', description = 'Jedeš příliš pomalu!', type = 'error' })
            end
        end
    end
end, false)
RegisterKeyMapping('omezovac', "<font face='ChakraPetch-Regular'>Zapnout/Vypnout Omezovač</font>", 'keyboard', 'o')

RegisterCommand('tempomat', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        if cruiseActive then
            cruiseActive = false
            resetSpeed(veh)
            lib.notify({ title = 'Tempomat', description = 'Vypnut', type = 'info' })
        else
            local speed = GetEntitySpeed(veh)
            if speed > 5.5 then
                cruiseActive = true
                if limiterActive then limiterActive = false end
                SetEntityMaxSpeed(veh, speed)
                lib.notify({ title = 'Tempomat', description = 'Zapnut', type = 'success' })
            else
                lib.notify({ title = 'Tempomat', description = 'Jedeš příliš pomalu!', type = 'error' })
            end
        end
    end
end, false)
RegisterKeyMapping('tempomat', "<font face='ChakraPetch-Regular'>Zapnout/Vypnout Tempomat</font>", 'keyboard', 'y')


-- ==========================================
-- VLÁKNO PRO FYZIKU (Auto plyn & Brzda)
-- ==========================================
CreateThread(function()
    while true do
        local sleep = 1000

        if cruiseActive or limiterActive then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                sleep = 0

                if cruiseActive then
                    SetControlNormal(0, 71, 1.0)

                    if IsControlPressed(2, 72) or IsControlPressed(2, 76) then
                        cruiseActive = false
                        resetSpeed(veh)
                        lib.notify({ title = 'Tempomat', description = 'Deaktivován', type = 'warning' })
                    end
                end
            else
                if cruiseActive or limiterActive then
                    cruiseActive = false
                    limiterActive = false
                end
            end
        end
        Wait(sleep)
    end
end)


-- ==========================================
-- HLAVNÍ VLÁKNO (NUI Aktualizace)
-- ==========================================
CreateThread(function()
    while true do
        local sleep = 2000
        local shouldShowRadar = false

        if FR_HUD.isVisible and not FR_HUD.inCinematic and not IsPauseMenuActive() then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                shouldShowRadar = true
                sleep = 150

                local veh = GetVehiclePedIsIn(ped, false)
                local speed = math.floor(GetEntitySpeed(veh) * 2.236936)
                local gear = GetVehicleCurrentGear(veh)
                local fuel = GetVehicleFuelLevel(veh)

                -- Čtení stavu blinkrů přímo z vozidla
                local indicatorState = GetVehicleIndicatorLights(veh)
                local leftBlinker = indicatorState == 1 or indicatorState == 3
                local rightBlinker = indicatorState == 2 or indicatorState == 3

                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
                local streetName = GetStreetNameFromHashKey(streetHash)

                SendNUIMessage({
                    action = "updateCarHud",
                    inVehicle = true,
                    speed = speed,
                    gear = gear == 0 and "R" or gear,
                    fuel = fuel,
                    leftBlinker = leftBlinker,
                    rightBlinker = rightBlinker,
                    compass = GetCompassDirection(heading),
                    street = streetName,
                    cruiseControl = cruiseActive,
                    speedLimiter = limiterActive
                })
            else
                SendNUIMessage({ action = "updateCarHud", inVehicle = false })
            end
        else
            SendNUIMessage({ action = "updateCarHud", inVehicle = false })
        end

        if shouldShowRadar ~= wasMinimapVisible then
            DisplayRadar(shouldShowRadar)
            wasMinimapVisible = shouldShowRadar
        end

        Wait(sleep)
    end
end)

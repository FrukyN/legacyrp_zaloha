local windowStates = {
    [0] = false, -- Levé přední (Řidič)
    [1] = false, -- Pravé přední (Spolujezdec)
    [2] = false, -- Levé zadní
    [3] = false  -- Pravé zadní
}

local function toggleWindow(windowId)
    local veh = cache.vehicle
    if veh then
        windowStates[windowId] = not windowStates[windowId]
        if windowStates[windowId] then
            RollDownWindow(veh, windowId)
        else
            RollUpWindow(veh, windowId)
        end
    end
end

local function changeSeat(seatIndex)
    local ped = cache.ped
    local veh = cache.vehicle
    if veh then
        if IsVehicleSeatFree(veh, seatIndex) then
            SetPedIntoVehicle(ped, veh, seatIndex)
        else
            lib.notify({title = 'Vozidlo', description = 'Toto místo je obsazené!', type = 'error'})
        end
    end
end

lib.registerRadial({
    id = 'vozidlo_okna',
    items = {
        { label = 'Levé přední', icon = 'arrow-down', onSelect = function() toggleWindow(0) end },
        { label = 'Pravé přední', icon = 'arrow-down', onSelect = function() toggleWindow(1) end },
        { label = 'Levé zadní', icon = 'arrow-down', onSelect = function() toggleWindow(2) end },
        { label = 'Pravé zadní', icon = 'arrow-down', onSelect = function() toggleWindow(3) end },
    }
})

lib.registerRadial({
    id = 'vozidlo_sedacky',
    items = {
        { label = 'Řidič', icon = 'car-side', onSelect = function() changeSeat(-1) end },
        { label = 'Spolujezdec', icon = 'chair', onSelect = function() changeSeat(0) end },
        { label = 'Levé zadní', icon = 'chair', onSelect = function() changeSeat(1) end },
        { label = 'Pravé zadní', icon = 'chair', onSelect = function() changeSeat(2) end },
    }
})

-- Hlavní menu vozidla
lib.registerRadial({
    id = 'vozidlo_main',
    items = {
        {
            label = 'Motor',
            icon = 'power-off',
            onSelect = function()
                local veh = cache.vehicle
                if veh then
                    local isRunning = GetIsVehicleEngineRunning(veh)
                    SetVehicleEngineOn(veh, not isRunning, false, true)
                end
            end
        },
        {
            label = 'Okna',
            icon = 'wind',
            menu = 'vozidlo_okna'
        },
        {
            label = 'Sedačky',
            icon = 'people-arrows',
            menu = 'vozidlo_sedacky'
        }
    }
})

lib.onCache('vehicle', function(vehicle)
    if vehicle then
        SetPedConfigFlag(cache.ped, 184, true)

        lib.addRadialItem({
            id = 'vozidlo',
            label = 'Vozidlo',
            icon = 'car',
            menu = 'vozidlo_main'
        })
    else
        SetPedConfigFlag(cache.ped, 184, false)
        lib.removeRadialItem('vozidlo')
    end
end)
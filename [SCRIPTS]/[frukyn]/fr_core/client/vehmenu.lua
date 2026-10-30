if IsPedInVehicle(PlayerPedId(), false) then
    lib.addRadialItem({ id = 'vozidlo', label = 'Vozidlo', icon = 'car', menu = 'vozidlo_main' })
end

local windowsDown = false
lib.registerRadial({
    id = 'vozidlo_main',
    items = {
        {
            label = 'Okna',
            icon = 'wind',
            onSelect = function()
                local veh = cache.vehicle
                if veh then
                    windowsDown = not windowsDown
                    if windowsDown then
                        RollDownWindow(veh, 0)
                        RollDownWindow(veh, 1)
                    else
                        RollUpWindow(veh, 0)
                        RollUpWindow(veh, 1)
                    end
                end
            end
        }
    }
})

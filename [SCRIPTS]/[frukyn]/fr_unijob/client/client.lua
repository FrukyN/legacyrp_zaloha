local isCuffed = false
local cuffLoopActive = false

-- 1. Vytvoření ox_target zón z Configu
CreateThread(function()
    for jobName, jobData in pairs(Config.Jobs) do
        
        -- Duty body
        if jobData.duty then
            for i, coords in ipairs(jobData.duty) do
                exports.ox_target:addSphereZone({
                    coords = coords,
                    radius = 1.2,
                    options = {
                        {
                            name = ('duty_%s_%s'):format(jobName, i),
                            icon = 'fa-solid fa-clipboard-user',
                            label = 'Přepnout službu (' .. jobData.label .. ')',
                            groups = jobName,
                            onSelect = function()
                                TriggerServerEvent('unijob:server:toggleDuty', jobName)
                            end
                        }
                    }
                })
            end
        end

        -- Šatny (illenium-appearance)
        if jobData.wardrobes then
            for i, coords in ipairs(jobData.wardrobes) do
                exports.ox_target:addSphereZone({
                    coords = coords,
                    radius = 1.2,
                    options = {
                        {
                            name = ('wardrobe_%s_%s'):format(jobName, i),
                            icon = 'fa-solid fa-shirt',
                            label = 'Šatna',
                            groups = jobName,
                            onSelect = function()
                                -- Otevře menu s uloženými outfity v illenium-appearance
                                TriggerEvent('illenium-appearance:client:openOutfitMenu')
                            end
                        }
                    }
                })
            end
        end

        -- Sklady (ox_inventory)
        if jobData.stashes then
            for _, stash in ipairs(jobData.stashes) do
                exports.ox_target:addSphereZone({
                    coords = stash.coords,
                    radius = 1.2,
                    options = {
                        {
                            name = ('stash_%s'):format(stash.id),
                            icon = 'fa-solid fa-box-open',
                            label = 'Otevřít: ' .. stash.label,
                            groups = { [jobName] = stash.minGrade or 1 },
                            onSelect = function()
                                exports.ox_inventory:openInventory('stash', stash.id)
                            end
                        }
                    }
                })
            end
        end

        -- Tiché alarmy
        if jobData.alarms then
            for i, coords in ipairs(jobData.alarms) do
                exports.ox_target:addSphereZone({
                    coords = coords,
                    radius = 0.8,
                    options = {
                        {
                            name = ('alarm_%s_%s'):format(jobName, i),
                            icon = 'fa-solid fa-bell',
                            label = 'Spustit tichý alarm',
                            groups = jobName,
                            onSelect = function()
                                if lib.progressCircle({
                                    duration = 1500,
                                    label = 'Aktivuji tichý alarm...',
                                    position = 'bottom',
                                    useWhileDead = false,
                                    canCancel = true,
                                    disable = { move = true, car = true, combat = true }
                                }) then
                                    TriggerServerEvent('unijob:server:silentAlarm', jobName, coords)
                                    lib.notify({ type = 'inform', description = 'Tichý alarm byl aktivován.' })
                                end
                            end
                        }
                    }
                })
            end
        end
        -- Boss Menu (propojeno přes nový export)
        if jobData.bossmenu then
            exports.ox_target:addSphereZone({
                coords = jobData.bossmenu.coords,
                radius = 1.2,
                options = {
                    {
                        name = ('bossmenu_%s'):format(jobName),
                        icon = 'fa-solid fa-briefcase',
                        label = 'Otevřít Boss Menu (' .. jobData.label .. ')',
                        groups = { [jobName] = jobData.bossmenu.minGrade or 1 },
                        onSelect = function()
                            exports.bossmenu:OpenBossMenu() -- Zavolání našeho nového exportu
                        end
                    }
                }
            })
        end

        if jobData.blip and jobData.blip.enabled then
            exports.fr_blips:RegisterBlip('unijob_' .. jobName, {
                name = jobData.blip.name or jobData.label,
                coords = jobData.blip.coords,
                sprite = jobData.blip.sprite,
                scale = jobData.blip.scale or 0.8,
                color = jobData.blip.color or 0,
                dynamic = jobData.blip.dynamic or false,
                job = jobName,
                minOnline = jobData.blip.minOnline or 1,
                offlineColor = jobData.blip.offlineColor or 39,
                onlineColor = jobData.blip.onlineColor or 2
            })
        end
    end
end)

-- 2. Globální interakce na hráče a vozidla (Pouta + Vozidlo)
CreateThread(function()
    -- Povolení skupin, které mají v configu canCuff = true
    local cuffGroups = {}
    for jobName, jobData in pairs(Config.Jobs) do
        if jobData.canCuff then
            cuffGroups[jobName] = 1
        end
    end

    -- Target na hráče
    exports.ox_target:addGlobalPlayer({
        {
            name = 'unijob_cuff',
            icon = 'fa-solid fa-handcuffs',
            label = 'Spoutat osobu',
            groups = cuffGroups,
            items = Config.Items.Cuffs,
            canInteract = function(entity)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return not Player(targetId).state.isCuffed
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                TriggerServerEvent('unijob:server:cuffPlayer', targetId)
            end
        },
        {
            name = 'unijob_uncuff',
            icon = 'fa-solid fa-key',
            label = 'Odpoutat osobu',
            items = Config.Items.Key, -- Odpoutat může kdokoliv, kdo má klíč (nebo přidej groups = cuffGroups)
            canInteract = function(entity)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return Player(targetId).state.isCuffed == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                TriggerServerEvent('unijob:server:uncuffPlayer', targetId)
            end
        },
        {
            name = 'unijob_put_in_veh',
            icon = 'fa-solid fa-car-side',
            label = 'Posadit do vozidla',
            groups = cuffGroups,
            canInteract = function(entity)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
                return Player(targetId).state.isCuffed == true and veh ~= nil
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
                if veh then
                    TriggerServerEvent('unijob:server:putInVehicle', targetId, NetworkGetNetworkIdFromEntity(veh))
                end
            end
        },
        {
            name = 'unijob_escort',
            icon = 'fa-solid fa-people-pulling',
            label = 'Vést / Pustit osobu',
            groups = cuffGroups,
            canInteract = function(entity)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return Player(targetId).state.isCuffed == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                TriggerServerEvent('unijob:server:escortPlayer', targetId)
            end
        },
        {
            name = 'unijob_search',
            icon = 'fa-solid fa-magnifying-glass',
            label = 'Prohledat osobu',
            groups = cuffGroups,
            canInteract = function(entity)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return Player(targetId).state.isCuffed == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                if lib.progressCircle({
                    duration = 2000,
                    label = 'Prohledáváš osobu...',
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search' }
                }) then
                    TriggerServerEvent('unijob:server:searchPlayer', targetId)
                end
            end
        }
    })

    -- Target na vozidlo pro vytažení spoutané osoby
    exports.ox_target:addGlobalVehicle({
        {
            name = 'unijob_take_out_veh',
            icon = 'fa-solid fa-person-arrow-up-from-line',
            label = 'Vytáhnout spoutanou osobu',
            groups = cuffGroups,
            canInteract = function(entity)
                for i = 0, GetVehicleMaxNumberOfPassengers(entity) - 1 do
                    local ped = GetPedInVehicleSeat(entity, i)
                    if ped ~= 0 and IsPedAPlayer(ped) then
                        local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                        if Player(targetId).state.isCuffed then
                            return true
                        end
                    end
                end
                return false
            end,
            onSelect = function(data)
                local entity = data.entity
                for i = 0, GetVehicleMaxNumberOfPassengers(entity) - 1 do
                    local ped = GetPedInVehicleSeat(entity, i)
                    if ped ~= 0 and IsPedAPlayer(ped) then
                        local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                        if Player(targetId).state.isCuffed then
                            TriggerServerEvent('unijob:server:takeOutVehicle', targetId)
                            break
                        end
                    end
                end
            end
        }
    })
end)

-- 3. Klientská logika pro spoutaného hráče
local function startCuffLoop()
    if cuffLoopActive then return end
    cuffLoopActive = true

    lib.requestAnimDict('mp_arresting')

    CreateThread(function()
        while isCuffed do
            Wait(0)
            local ped = cache.ped

            -- Udržování animace
            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, false, false, false)
            end

            -- Blokování kláves (útoky, zbraně, vystupování z auta atd.)
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 45, true)  -- Reload
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- Select Weapon
            DisableControlAction(0, 23, true)  -- Also 'enter' ?
            DisableControlAction(0, 75, true)  -- Exit Vehicle
            DisableControlAction(27, 75, true) -- Exit Vehicle
        end
        cuffLoopActive = false
    end)
end

RegisterNetEvent('unijob:client:getCuffed', function()
    isCuffed = true
    local ped = cache.ped
    SetEnableHandcuffs(ped, true)
    DisablePlayerFiring(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    SetPedCanPlayGestureAnims(ped, false)
    
    -- Zablokování používání ox_inventory během spoutání
    LocalPlayer.state:set('invBusy', true, false)

    startCuffLoop()
    lib.notify({ type = 'warning', description = 'Byl jsi spoután!' })
end)

RegisterNetEvent('unijob:client:getUncuffed', function()
    isCuffed = false
    local ped = cache.ped
    SetEnableHandcuffs(ped, false)
    DisablePlayerFiring(ped, false)
    SetPedCanPlayGestureAnims(ped, true)
    ClearPedSecondaryTask(ped)
    
    -- Povolení inventáře
    LocalPlayer.state:set('invBusy', false, false)

    lib.notify({ type = 'inform', description = 'Byl jsi odpoután.' })
end)

-- 4. Klientské eventy pro posazení / vyndání z vozidla
RegisterNetEvent('unijob:client:putInVehicle', function(vehNetId)
    if not isCuffed then return end
    local veh = NetToVeh(vehNetId)
    if DoesEntityExist(veh) then
        local maxSeats = GetVehicleMaxNumberOfPassengers(veh)
        -- Hledáme volné místo od zadních sedaček (2, 1, 0)
        for i = maxSeats - 1, 0, -1 do
            if IsVehicleSeatFree(veh, i) then
                TaskWarpPedIntoVehicle(cache.ped, veh, i)
                break
            end
        end
    end
end)

RegisterNetEvent('unijob:client:takeOutVehicle', function()
    if not isCuffed then return end
    local ped = cache.ped
    if IsPedSittingInAnyVehicle(ped) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 16)
    end
end)

-- 5. Klientská logika pro eskortování
local isEscorted = false

RegisterNetEvent('unijob:client:startEscort', function(draggerId)
    isEscorted = true
    local ped = cache.ped
    local draggerPed = GetPlayerPed(GetPlayerFromServerId(draggerId))

    if DoesEntityExist(draggerPed) then
        -- Připojení postavy k pravé ruce/boku eskortujícího
        AttachEntityToEntity(ped, draggerPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    end

    CreateThread(function()
        while isEscorted do
            Wait(500)
            draggerPed = GetPlayerPed(GetPlayerFromServerId(draggerId))
            -- Pokud eskortující zmizí, zemře nebo nasedne do auta, eskort se přeruší
            if not DoesEntityExist(draggerPed) or IsPedDeadOrDying(draggerPed, true) or IsPedInAnyVehicle(draggerPed, false) then
                isEscorted = false
                DetachEntity(ped, true, false)
            end
        end
    end)
end)

RegisterNetEvent('unijob:client:stopEscort', function()
    if isEscorted then
        isEscorted = false
        DetachEntity(cache.ped, true, false)
    end
end)
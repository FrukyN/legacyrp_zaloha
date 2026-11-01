local function formatPlate(plate)
    if not plate then return '' end
    return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

-- Kontrola na klientovi, jestli má u sebe klíč k dané SPZ
local function hasVehicleKey(plate)
    local cleanPlate = formatPlate(plate)
    local count = exports.ox_inventory:Search('count', Config.KeyItem, { plate = cleanPlate })
    return count and count > 0
end

-- Kontrola, jestli lze auto nastartovat (má klíč NEBO je hotwired)
local function canOperateVehicle(veh)
    if not DoesEntityExist(veh) then return false end
    local plate = GetVehicleNumberPlateText(veh)
    if hasVehicleKey(plate) then return true end
    if Entity(veh).state.hotwired then return true end
    return false
end

-- Upravený StateBag handler v client.lua:
AddStateBagChangeHandler('locked', nil, function(bagName, key, value, _unused, replicated)
    local ent = GetEntityFromStateBagName(bagName)
    if ent == 0 or not DoesEntityExist(ent) then return end
    
    -- Hodnota 2 zamkne dveře, SetVehicleDoorsLockedForAllPlayers pojistí, že GTA nepustí animaci rozbití skla
    SetVehicleDoorsLocked(ent, value and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(ent, value)
end)

-- ========================
-- LOGIKA MOTORU (0.00ms idle)
-- ========================
local engineLoopActive = false

local function handleDriverSeat(veh)
    if engineLoopActive then return end
    engineLoopActive = true

    -- Vypne automatické startování GTA při nasednutí
    SetPedConfigFlag(cache.ped, 429, true)

    CreateThread(function()
        while cache.vehicle == veh and cache.seat == -1 do
            if not canOperateVehicle(veh) then
                -- Hráč nemá klíč a auto není hotwired -> držíme motor vypnutý
                if GetIsVehicleEngineRunning(veh) then
                    SetVehicleEngineOn(veh, false, true, true)
                end
                DisableControlAction(0, 71, true) -- W (Accelerate)
                DisableControlAction(0, 72, true) -- S (Brake/Reverse)
                Wait(0)
            else
                -- Hráč má klíč nebo je auto hotwired -> netřeba blokovat každý frame
                Wait(500)
            end
        end
        engineLoopActive = false
    end)
end

lib.onCache('vehicle', function(veh)
    if veh and cache.seat == -1 then
        handleDriverSeat(veh)
    end
end)

lib.onCache('seat', function(seat)
    if cache.vehicle and seat == -1 then
        handleDriverSeat(cache.vehicle)
    end
end)

-- ========================
-- ZAMYKÁNÍ A START MOTORU
-- ========================
local function toggleVehicleLock()
    local veh = cache.vehicle
    if not veh then
        veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.LockDistance, false)
    end

    if not veh or not DoesEntityExist(veh) then return end
    TriggerServerEvent('fr_carkeys:server:toggleLock', NetworkGetNetworkIdFromEntity(veh))
end

RegisterNetEvent('fr_carkeys:client:playLockEffect', function(netId, isLocked)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end

    if not cache.vehicle then
        lib.playAnim(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click_fp', 8.0, 8.0, 1000, 48, 0, false, false, false)
    end

    PlayVehicleDoorCloseSound(veh, 1)
    SetVehicleLights(veh, 2)
    Wait(150)
    SetVehicleLights(veh, 0)
    Wait(150)
    SetVehicleLights(veh, 2)
    Wait(150)
    SetVehicleLights(veh, 0)

    lib.notify({
        type = isLocked and 'warning' or 'success',
        description = isLocked and 'Vozidlo zamčeno' or 'Vozidlo odemčeno'
    })
end)

local function toggleEngine()
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return end

    if not canOperateVehicle(veh) then
        lib.notify({ type = 'error', description = 'Nemáš klíče od tohoto vozidla!' })
        return
    end

    local running = GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, not running, false, true)
    lib.notify({
        type = not running and 'success' or 'inform',
        description = not running and 'Motor nastartován' or 'Motor vypnut'
    })
end

lib.addKeybind({
    name = 'carkeys_lock',
    description = 'Zamknout / Odemknout vozidlo',
    defaultKey = Config.LockKeybind,
    onPressed = toggleVehicleLock
})

lib.addKeybind({
    name = 'carkeys_engine',
    description = 'Zapnout / Vypnout motor',
    defaultKey = Config.EngineKeybind,
    onPressed = toggleEngine
})

-- ========================
-- KRÁDEŽ AUTA (LOCKPICK & HOTWIRE)
-- ========================

-- 1. Vypáčení zámku zvenku (přes ox_target na zamčené auto)
exports.ox_target:addGlobalVehicle({
    {
        name = 'lockpick_vehicle_door',
        icon = 'fa-solid fa-unlock-keyhole',
        label = 'Vypáčit zámek',
        items = Config.LockpickItem,
        distance = 2.0,
        canInteract = function(entity)
            local locked = Entity(entity).state.locked
            if locked == nil then
                locked = GetVehicleDoorLockStatus(entity) == 2
            end
            return locked
        end,
        onSelect = function(data)
            local veh = data.entity
            lib.requestAnimDict('veh@break_in@0h@p_m_one@')
            TaskPlayAnim(cache.ped, 'veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 3.0, 3.0, -1, 16, 0, false, false, false)

            local success = lib.skillCheck(Config.Lockpick.OutsideDifficulty, {'w', 'a', 's', 'd'})
            ClearPedTasks(cache.ped)

            if success then
                TriggerServerEvent('fr_carkeys:server:unlockLockpick', NetworkGetNetworkIdFromEntity(veh))
                lib.notify({ type = 'success', description = 'Zámek byl úspěšně vypáčen!' })
            else
                TriggerServerEvent('fr_carkeys:server:breakLockpick')
                SetVehicleAlarm(veh, true)
                StartVehicleAlarm(veh)
                lib.notify({ type = 'error', description = 'Nepodařilo se vypáčit zámek!' })
            end
        end
    }
})

-- 2. Hotwire uvnitř auta (když hráč použije item lockpick na sedadle řidiče, nebo přes příkaz/radiál)
local function startHotwire()
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then
        lib.notify({ type = 'error', description = 'Musíš sedět na místě řidiče!' })
        return
    end

    if canOperateVehicle(veh) then
        lib.notify({ type = 'inform', description = 'Toto vozidlo už můžeš normálně nastartovat.' })
        return
    end

    if exports.ox_inventory:Search('count', Config.LockpickItem) < 1 then
        lib.notify({ type = 'error', description = 'Potřebuješ šperhák na spojení kabelů!' })
        return
    end

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 3.0, 3.0, -1, 49, 0, false, false, false)

    local success = lib.skillCheck(Config.Lockpick.HotwireDifficulty, {'w', 'a', 's', 'd'})
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('fr_carkeys:server:setHotwired', NetworkGetNetworkIdFromEntity(veh))
        Wait(100)
        SetVehicleEngineOn(veh, true, false, true)
        lib.notify({ type = 'success', description = 'Kabely spojeny, motor naskočil!' })
    else
        TriggerServerEvent('fr_carkeys:server:breakLockpick')
        SetVehicleAlarm(veh, true)
        StartVehicleAlarm(veh)
        lib.notify({ type = 'error', description = 'Spojení kabelů selhalo!' })
    end
end

-- Možnost spustit hotwire příkazem /hotwire nebo si na to napojit item
RegisterCommand('hotwire', startHotwire, false)
exports('StartHotwire', startHotwire)

-- ========================
-- MNOŽENÍ KLÍČŮ (ZÁMEČNÍK)
-- ========================
local function openKeysmithMenu()
    local keys = exports.ox_inventory:Search('slots', Config.KeyItem)
    if not keys or #keys == 0 then
        lib.notify({ type = 'error', description = 'Nemáš u sebe žádné klíče k okopírování!' })
        return
    end

    local options = {}
    for _, slotData in ipairs(keys) do
        local plate = slotData.metadata and slotData.metadata.plate or 'Neznámá SPZ'
        local model = slotData.metadata and slotData.metadata.model or 'Vozidlo'

        options[#options + 1] = {
            title = ('Klíč [%s]'):format(plate),
            description = ('Model: %s | Cena kopie: %s$'):format(model, Config.Keysmith.Price),
            icon = 'fa-solid fa-key',
            onSelect = function()
                if lib.progressBar({
                    duration = 3500,
                    label = 'Vyrábím kopii klíče...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true }
                }) then
                    TriggerServerEvent('fr_carkeys:server:copyKey', slotData.slot)
                end
            end
        }
    end

    lib.registerContext({
        id = 'keysmith_copy_menu',
        title = 'Zámečnictví - Kopírování klíčů',
        options = options
    })
    lib.showContext('keysmith_copy_menu')
end

CreateThread(function()
    local cfg = Config.Keysmith
    lib.requestModel(cfg.Model)
    local ped = CreatePed(0, cfg.Model, cfg.Coords.x, cfg.Coords.y, cfg.Coords.z - 1.0, cfg.Coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'open_keysmith',
            icon = 'fa-solid fa-key',
            label = 'Vyrobit kopii klíčů',
            distance = 2.0,
            onSelect = openKeysmithMenu
        }
    })
end)

-- Export volaný přímo při použití klíče v ox_inventory
exports('UseCarKey', function(data, slot)
    exports.ox_inventory:useItem(data, function(itemData)
        if not itemData then return end

        local keyPlate = itemData.metadata and itemData.metadata.plate
        if not keyPlate then
            lib.notify({ type = 'error', description = 'Tento klíč není spárovaný s žádnou SPZ!' })
            return
        end

        local targetVeh = nil
        local cleanKeyPlate = formatPlate(keyPlate)

        -- 1. Pokud hráč sedí přímo v autě, zkontrolujeme SPZ tohoto auta
        if cache.vehicle then
            local currentPlate = formatPlate(GetVehicleNumberPlateText(cache.vehicle))
            if currentPlate == cleanKeyPlate then
                targetVeh = cache.vehicle
            end
        else
            -- 2. Pokud stojí venku, prohledáme všechna auta v okruhu (Config.LockDistance)
            local coords = GetEntityCoords(cache.ped)
            local nearbyVehicles = lib.getNearbyVehicles(coords, Config.LockDistance, false)

            for i = 1, #nearbyVehicles do
                local veh = nearbyVehicles[i].vehicle
                local vehPlate = formatPlate(GetVehicleNumberPlateText(veh))
                if vehPlate == cleanKeyPlate then
                    targetVeh = veh
                    break
                end
            end
        end

        if not targetVeh or not DoesEntityExist(targetVeh) then
            lib.notify({ type = 'error', description = ('Vozidlo [%s] není v dosahu signálu!'):format(cleanKeyPlate) })
            return
        end

        -- Odešleme požadavek na server (stejný event jako u klávesy U)
        TriggerServerEvent('fr_carkeys:server:toggleLock', NetworkGetNetworkIdFromEntity(targetVeh))
    end)
end)

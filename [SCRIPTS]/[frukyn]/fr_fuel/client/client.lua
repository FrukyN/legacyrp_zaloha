local state = {
    isFueling = false,
    nozzle = nil,
    rope = nil,
    petrolCan = nil
}

local function notify(description, notifyType)
    lib.notify({
        title = 'Palivo',
        description = description,
        type = notifyType or 'inform'
    })
end

local function clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function getVehicleFuel(vehicle)
    local vehState = Entity(vehicle).state
    return clamp(vehState.fuel or GetVehicleFuelLevel(vehicle), 0.0, 100.0)
end

local function setVehicleFuel(vehicle, fuel)
    fuel = clamp(fuel, 0.0, 100.0)
    SetVehicleFuelLevel(vehicle, fuel)
    Entity(vehicle).state:set('fuel', fuel, true)
end

local function getNearestVehicle(coords)
    local closestVehicle
    local closestDistance = Config.VehicleDistance + 0.01

    local lastVehicle = GetPlayersLastVehicle()
    if lastVehicle ~= 0 and DoesEntityExist(lastVehicle) then
        local distance = #(GetEntityCoords(lastVehicle) - coords)
        if distance <= closestDistance then
            closestVehicle = lastVehicle
            closestDistance = distance
        end
    end

    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) then
            local distance = #(GetEntityCoords(vehicle) - coords)
            if distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end

    return closestVehicle
end

local function getNetId(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    return netId
end

local function fuelAllowedAtStation(stationType, fuelType)
    local station = Config.StationTypes[stationType]
    if not station then return false end
    for i = 1, #station.fuels do
        if station.fuels[i] == fuelType then return true end
    end
    return false
end

local function buildFuelOptions(prices, expectedFuel, stationType)
    local options = {}
    for fuelType, data in pairs(Config.FuelTypes) do
        if fuelAllowedAtStation(stationType, fuelType) then
            local price = prices[fuelType] or data.price
            local label = ('%s - %s/l'):format(data.label, FuelTypes.FormatMoney(price))
            if fuelType == expectedFuel then
                label = ('%s (doporuceno)'):format(label)
            end
            options[#options + 1] = {
                value = fuelType,
                label = label
            }
        end
    end
    table.sort(options, function(a, b) return a.label < b.label end)
    return options
end

local function buildAccountOptions(accounts)
    local options = {}
    for i = 1, #accounts do
        local account = accounts[i]
        local label = ('%s - %s'):format(account.label, FuelTypes.FormatMoney(account.balance))
        if account.isDefault then
            label = ('%s (hlavni)'):format(label)
        end
        options[#options + 1] = {
            value = tostring(account.id),
            label = label
        }
    end
    return options
end

local function selectBankAccount()
    local accounts = lib.callback.await('fr_fuel:getBankAccounts', false)
    if not accounts or #accounts == 0 then
        notify('Nemas zadny ucet, ze ktereho lze platit.', 'error')
        return nil
    end

    local input = lib.inputDialog('Vyber bankovni ucet', {
        {
            type = 'select',
            label = 'Ucet',
            options = buildAccountOptions(accounts),
            default = tostring(accounts[1].id),
            required = true
        }
    })

    if not input then return nil end
    return tonumber(input[1])
end

local function buildPaymentOptions()
    return {
        { value = 'bank', label = Config.PaymentMethods.bank.label },
        { value = 'cash', label = Config.PaymentMethods.cash.label }
    }
end

local function deleteHose()
    if state.rope then
        DeleteRope(state.rope)
        state.rope = nil
    end

    if state.nozzle and DoesEntityExist(state.nozzle) then
        DeleteEntity(state.nozzle)
        state.nozzle = nil
    end
end

local function createHose(pumpEntity)
    if not Config.Hose.enabled then return end

    local ped = cache.ped
    local model = Config.Hose.nozzleModel
    lib.requestModel(model, 5000)

    local pedCoords = GetEntityCoords(ped)
    local nozzle = CreateObject(model, pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)

    AttachEntityToEntity(
        nozzle,
        ped,
        GetPedBoneIndex(ped, 18905),
        0.11, 0.02, 0.02,
        -90.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    state.nozzle = nozzle
    SetModelAsNoLongerNeeded(model)

    if pumpEntity and DoesEntityExist(pumpEntity) then
        local pumpCoords = GetEntityCoords(pumpEntity)
        local rope = AddRope(
            pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.0,
            0.0, 0.0, 0.0,
            Config.Hose.length, 1, Config.Hose.length,
            1.0, 0.0, false, false, false, 1.0, false, 0
        )

        if rope and rope ~= 0 then
            ActivatePhysics(rope)
            AttachEntitiesToRope(
                rope, pumpEntity, nozzle,
                pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.0,
                pedCoords.x, pedCoords.y, pedCoords.z,
                Config.Hose.length, false, false, 0, 0
            )
            state.rope = rope
        end
    end
end

local function confirmWrongFuel(selectedFuel, expectedFuel)
    if selectedFuel == expectedFuel then return true end

    local result = lib.alertDialog({
        header = 'Spatne palivo',
        content = ('Toto vozidlo potrebuje %s. Pokud natankujes %s, motor se rozbije. Pokracovat?'):format(
            FuelTypes.GetLabel(expectedFuel),
            FuelTypes.GetLabel(selectedFuel)
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Pokracovat',
            cancel = 'Zrusit'
        }
    })

    return result == 'confirm'
end

local function finishFueling(token, finalFuel)
    TriggerServerEvent('fr_fuel:finishSession', token, finalFuel)
end

local function startFueling(vehicle, pumpEntity, session)
    local ped = cache.ped
    local fuel = getVehicleFuel(vehicle)
    local targetFuel = clamp(fuel + session.units, 0.0, 100.0)
    local duration = math.ceil((targetFuel - fuel) / Config.RefillValue) * Config.RefillTick

    if duration <= 0 then
        finishFueling(session.token, fuel)
        return
    end

    state.isFueling = true
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    Wait(350)
    createHose(pumpEntity)

    CreateThread(function()
        local done = lib.progressCircle({
            duration = duration,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = {
                dict = 'timetable@gardener@filling_can',
                clip = 'gar_ig_5_filling_can',
                flags = 49
            }
        })

        if not done then
            state.isFueling = false
        end
    end)

    while state.isFueling do
        if not DoesEntityExist(vehicle) then
            fuel = 0.0
            break
        end

        local pedCoords = GetEntityCoords(ped)
        local pumpCoords = pumpEntity and DoesEntityExist(pumpEntity) and GetEntityCoords(pumpEntity) or pedCoords

        if #(pedCoords - pumpCoords) > (Config.Hose.length + 0.75) then
            notify('Hadice je moc natazena.', 'error')
            lib.cancelProgress()
            break
        end

        fuel = clamp(fuel + Config.RefillValue, 0.0, targetFuel)
        setVehicleFuel(vehicle, fuel)

        if fuel >= targetFuel or fuel >= 100.0 then
            state.isFueling = false
            lib.cancelProgress()
            break
        end

        Wait(Config.RefillTick)
    end

    ClearPedTasks(ped)
    deleteHose()
    state.isFueling = false

    finishFueling(session.token, fuel)
end

local function openFuelDialog(data)
    if state.isFueling or lib.progressActive() or cache.vehicle then return end

    local pumpCoords = data and data.coords or GetEntityCoords(cache.ped)
    local stationType = data and data.stationType or 'pump'
    local vehicle = getNearestVehicle(pumpCoords)

    if not vehicle or vehicle == 0 then
        return notify('U pumpy neni zadne vozidlo.', 'error')
    end

    local fuel = getVehicleFuel(vehicle)
    if fuel >= 99.9 then
        return notify('Nadrz je plna.', 'error')
    end

    local netId = getNetId(vehicle)
    local expectedFuel = FuelTypes.GetExpectedType(vehicle)
    local fuelData = lib.callback.await('fr_fuel:getFuelData', false, netId, expectedFuel, fuel)

    if not fuelData or not fuelData.ok then
        return notify(fuelData and fuelData.message or 'Pumpa neodpovida.', 'error')
    end

    fuel = clamp(fuelData.fuel or fuel, 0.0, 100.0)
    expectedFuel = fuelData.expectedFuel or expectedFuel

    if stationType == 'charger' and expectedFuel ~= 'electric' then
        return notify('Na nabijecce lze nabijet jen elektromobil.', 'error')
    end

    if stationType == 'pump' and expectedFuel == 'electric' then
        return notify('Elektromobil nabijes jen u nabijecky.', 'error')
    end

    local missingFuel = math.ceil(100.0 - fuel)
    local defaultUnits = math.min(Config.Prepay.defaultUnits, missingFuel)

    local input = lib.inputDialog('Predplacene tankovani', {
        {
            type = 'select',
            label = 'Palivo',
            options = buildFuelOptions(fuelData.prices or FuelTypes.GetPrices(), expectedFuel, stationType),
            default = fuelAllowedAtStation(stationType, expectedFuel) and expectedFuel or nil,
            required = true
        },
        {
            type = 'number',
            label = 'Predplatit litru / % nadrze',
            default = defaultUnits,
            min = math.min(Config.Prepay.minUnits, missingFuel),
            max = math.min(Config.Prepay.maxUnits, missingFuel),
            required = true
        },
        {
            type = 'select',
            label = 'Platba',
            options = buildPaymentOptions(),
            default = 'bank',
            required = true
        }
    })

    if not input then return end

    local selectedFuel = input[1]
    local units = tonumber(input[2])
    local paymentMethod = input[3]
    local accountId

    if not confirmWrongFuel(selectedFuel, expectedFuel) then
        return
    end

    if paymentMethod == 'bank' then
        accountId = selectBankAccount()
        if not accountId then return end
    end

    local session = lib.callback.await('fr_fuel:startSession', false, {
        netId = netId,
        fuelType = selectedFuel,
        units = units,
        paymentMethod = paymentMethod,
        accountId = accountId,
        stationType = stationType,
        expectedFuel = expectedFuel,
        currentFuel = fuel
    })

    if not session or not session.ok then
        return notify(session and session.message or 'Platba se nepovedla.', 'error')
    end

    notify(('Predplaceno %s za %.1f l %s.'):format(
        FuelTypes.FormatMoney(session.prepaid),
        session.units,
        FuelTypes.GetLabel(selectedFuel)
    ), 'success')

    startFueling(vehicle, data and data.entity, session)
end

-- ==========================================
-- LOGIKA KANYSTRU (z ox_fuel)
-- ==========================================
local function setPetrolCan(data)
    state.petrolCan = data?.name == 'WEAPON_PETROLCAN' and data or nil
end

setPetrolCan(exports.ox_inventory:getCurrentWeapon())
AddEventHandler('ox_inventory:currentWeapon', setPetrolCan)

local function buyOrRefillPetrolCan(coords)
    local hasCan = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
    local price = hasCan and Config.PetrolCan.refillPrice or Config.PetrolCan.price
    local money = exports.ox_inventory:GetItemCount('money')

    if money < price then
        return notify(('Nemas dost hotovosti ($%s).'):format(price), 'error')
    end

    TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, Config.PetrolCan.duration)
    Wait(500)

    if lib.progressCircle({
        duration = Config.PetrolCan.duration,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
            flags = 49
        }
    }) then
        TriggerServerEvent('fr_fuel:petrolCanAction', hasCan)
    end

    ClearPedTasks(cache.ped)
end

local function refuelVehicleWithCan(vehicle)
    if not state.petrolCan then
        return notify('Nemas v ruce kanystr.', 'error')
    end

    local ammo = state.petrolCan.metadata.ammo or 0
    if ammo <= Config.PetrolCan.durabilityTick then
        return notify('Kanystr je prazdny.', 'error')
    end

    local fuelAmount = getVehicleFuel(vehicle)
    if fuelAmount >= 99.9 then
        return notify('Nadrz je plna.', 'error')
    end

    state.isFueling = true
    local duration = math.ceil((100 - fuelAmount) / Config.PetrolCan.refillValue) * Config.PetrolCan.refillTick

    TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
    Wait(500)

    CreateThread(function()
        local success = lib.progressCircle({
            duration = duration,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = {
                dict = 'weapon@w_sp_jerrycan',
                clip = 'fire'
            }
        })
        if not success then
            state.isFueling = false
        end
    end)

    local durabilityUsed = 0

    while state.isFueling do
        durabilityUsed = durabilityUsed + Config.PetrolCan.durabilityTick
        fuelAmount = clamp(fuelAmount + Config.PetrolCan.refillValue, 0.0, 100.0)
        setVehicleFuel(vehicle, fuelAmount)

        if durabilityUsed >= ammo or fuelAmount >= 100.0 then
            state.isFueling = false
            lib.cancelProgress()
            break
        end

        Wait(Config.PetrolCan.refillTick)
    end

    ClearPedTasks(cache.ped)
    state.isFueling = false

    local netId = getNetId(vehicle)
    TriggerServerEvent('fr_fuel:updateFuelCan', durabilityUsed, netId, fuelAmount)
end

-- ==========================================
-- OX_TARGET
-- ==========================================
CreateThread(function()
    local pumpOptions = {
        {
            name = 'fr_fuel:pump',
            distance = Config.TargetDistance,
            icon = 'fas fa-gas-pump',
            label = 'Tankovat vozidlo',
            onSelect = function(data)
                data.stationType = 'pump'
                openFuelDialog(data)
            end,
            canInteract = function()
                return not state.isFueling and not cache.vehicle and not lib.progressActive()
            end
        }
    }

    if Config.PetrolCan.enabled then
        pumpOptions[#pumpOptions + 1] = {
            name = 'fr_fuel:petrolcan',
            distance = Config.TargetDistance,
            icon = 'fas fa-faucet',
            label = 'Koupit / Doplnit kanystr',
            onSelect = function(data)
                buyOrRefillPetrolCan(data.coords)
            end,
            canInteract = function()
                return not state.isFueling and not cache.vehicle and not lib.progressActive()
            end
        }
    end

    exports.ox_target:addModel(Config.PumpModels, pumpOptions)

    exports.ox_target:addModel(Config.ChargerModels, {
        {
            name = 'fr_fuel:charger',
            distance = Config.TargetDistance,
            icon = 'fas fa-bolt',
            label = 'Nabijet vozidlo',
            onSelect = function(data)
                data.stationType = 'charger'
                openFuelDialog(data)
            end,
            canInteract = function()
                return not state.isFueling and not cache.vehicle and not lib.progressActive()
            end
        }
    })

    if Config.PetrolCan.enabled then
        exports.ox_target:addGlobalVehicle({
            {
                name = 'fr_fuel:refuel_can',
                distance = 2.0,
                icon = 'fas fa-gas-pump',
                label = 'Doplnit palivo z kanystru',
                onSelect = function(data)
                    refuelVehicleWithCan(data.entity)
                end,
                canInteract = function(entity)
                    return not state.isFueling and not cache.vehicle and not lib.progressActive() and state.petrolCan
                end
            }
        })
    end
end)

-- ==========================================
-- SMYČKA SPOTŘEBY PALIVA ZA JÍZDY (z ox_fuel)
-- ==========================================
local function startDrivingVehicle()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 or not DoesVehicleUseFuel(vehicle) then return end

    local vehState = Entity(vehicle).state

    if not vehState.fuel then
        local currentFuel = GetVehicleFuelLevel(vehicle)
        TriggerServerEvent('fr_fuel:syncFuel', getNetId(vehicle), currentFuel)
        while not vehState.fuel do Wait(10) end
    end

    SetVehicleFuelLevel(vehicle, vehState.fuel)

    local fuelTick = 0

    while cache.seat == -1 do
        if GetIsVehicleEngineRunning(vehicle) then
            if not DoesEntityExist(vehicle) then return end
            SetFuelConsumptionRateMultiplier(Config.GlobalFuelConsumptionRate or 10.0)

            local fuelAmount = tonumber(vehState.fuel) or 0
            local newFuel = GetVehicleFuelLevel(vehicle)

            if fuelAmount > 0 then
                -- Únik paliva při proražené nádrži
                if GetVehiclePetrolTankHealth(vehicle) < 700 then
                    newFuel = newFuel - (math.random(10, 20) * 0.01)
                end

                if fuelAmount ~= newFuel then
                    if fuelTick >= 15 then
                        fuelTick = 0
                        TriggerServerEvent('fr_fuel:syncFuel', getNetId(vehicle), newFuel)
                    end

                    vehState.fuel = newFuel
                    SetVehicleFuelLevel(vehicle, newFuel)
                    fuelTick = fuelTick + 1
                end
            end
        else
            if not DoesEntityExist(vehicle) then return end
            SetFuelConsumptionRateMultiplier(0.0)
        end
        Wait(1000)
    end

    -- Po vystoupení řidiče finálně uloží stav
    TriggerServerEvent('fr_fuel:syncFuel', getNetId(vehicle), vehState.fuel or GetVehicleFuelLevel(vehicle))
end

if cache.seat == -1 then
    CreateThread(startDrivingVehicle)
end

lib.onCache('seat', function(seat)
    if seat == -1 then
        SetTimeout(0, startDrivingVehicle)
    end
end)

-- Kontrola poškození špatným palivem
CreateThread(function()
    while true do
        local vehicle = cache.vehicle
        if vehicle and cache.seat == -1 and Entity(vehicle).state.fr_wrongFuel then
            SetVehicleEngineHealth(vehicle, math.min(GetVehicleEngineHealth(vehicle), Config.WrongFuelDamage.engineHealth))
            if GetIsVehicleEngineRunning(vehicle) then
                SetVehicleEngineOn(vehicle, false, true, true)
            end
            Wait(2500)
        else
            Wait(5000)
        end
    end
end)
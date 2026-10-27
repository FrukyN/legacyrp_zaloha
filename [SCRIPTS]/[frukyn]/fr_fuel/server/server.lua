local Ox = require '@ox_core.lib.init'

local sessions = {}
local prices = {}

local function roundPrice(value)
    return math.floor((value * 100) + 0.5) / 100
end

local function clamp(value, min, max)
    value = tonumber(value) or 0

    if value < min then return min end
    if value > max then return max end

    return value
end

local function notify(source, description, notifyType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Tankování',
        description = description,
        type = notifyType or 'inform'
    })
end

local function publishPrices(initial)
    for fuelType, data in pairs(Config.FuelTypes) do
        local base = prices[fuelType] or data.price

        if initial then
            prices[fuelType] = roundPrice(base)
        else
            local volatility = data.volatility or Config.DefaultVolatility
            local change = 1.0 + ((math.random() * 2.0 - 1.0) * volatility)
            prices[fuelType] = roundPrice(clamp(base * change, data.minPrice or 1.0, data.maxPrice or 999.0))
        end
    end

    GlobalState.frFuelPrices = prices
end

local function getPlayer(source)
    local player = Ox.GetPlayer(source)

    if not player or not player.charId then
        return nil
    end

    return player
end

local function roleCanWithdraw(role)
    if not role then return false end

    local permissions = GlobalState[('accountRole.%s'):format(role)]

    if permissions then
        return permissions.withdraw == true or permissions.withdraw == 1
    end

    return role == 'owner' or role == 'manager'
end

local function handleAsyncResult(res)
    if type(res) == 'table' and (res.next or res['then'] or res.__cfx_async_retval) then
        local ok, awaited = pcall(Citizen.Await, res)
        if ok then res = awaited end
    end

    return res == true or res == nil or (type(res) == 'table' and res.success ~= false)
end

local function getAccountBalance(account)
    if not account then return nil end

    if account.balance ~= nil then
        return tonumber(account.balance)
    end

    local ok, balance = pcall(function()
        return account:get('balance')
    end)

    if ok and balance ~= nil then
        return tonumber(balance)
    end

    return nil
end

local function removeAccountBalance(account, amount, message, accountId)
    local targetId = (account and account.id) or accountId
    if not targetId then return false end

    if account and account.withdraw then
        local ok, res = pcall(function() return account:withdraw(amount, message) end)
        if ok and handleAsyncResult(res) then return true end
    end

    if account and account.removeBalance then
        local ok, res = pcall(function() return account:removeBalance(amount, message) end)
        if ok and handleAsyncResult(res) then return true end

        ok, res = pcall(function() return account:removeBalance({ amount = amount, message = message }) end)
        if ok and handleAsyncResult(res) then return true end
    end

    local rowsAffected = MySQL.update.await(
        'UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?',
        { amount, targetId, amount }
    )

    return rowsAffected and rowsAffected > 0
end

local function addAccountBalance(account, amount, message, accountId)
    local targetId = (account and account.id) or accountId
    if not targetId then return false end

    if account and account.deposit then
        local ok, res = pcall(function() return account:deposit(amount, message) end)
        if ok and handleAsyncResult(res) then return true end
    end

    if account and account.addBalance then
        local ok, res = pcall(function() return account:addBalance(amount, message) end)
        if ok and handleAsyncResult(res) then return true end

        ok, res = pcall(function() return account:addBalance({ amount = amount, message = message }) end)
        if ok and handleAsyncResult(res) then return true end
    end

    MySQL.update.await(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        { amount, targetId }
    )

    return true
end

local function getBankAccounts(source)
    local player = getPlayer(source)

    if not player then return {} end

    local accounts = MySQL.query.await([[
        SELECT DISTINCT
            COALESCE(access.role, gg.accountRole) AS role,
            account.id,
            account.label,
            account.balance,
            account.owner,
            account.isDefault,
            account.type,
            COALESCE(c.fullName, g.label) AS ownerName
        FROM accounts account
        LEFT JOIN characters c ON account.owner = c.charId
        LEFT JOIN ox_groups g ON account.group = g.name
        LEFT JOIN character_groups cg
            ON cg.charId = ?
            AND cg.name = account.group
        LEFT JOIN ox_group_grades gg
            ON account.group = gg.group
            AND cg.grade = gg.grade
        LEFT JOIN accounts_access access
            ON account.id = access.accountId
            AND access.charId = ?
        WHERE account.type != 'inactive'
            AND (
                access.charId = ?
                OR (
                    account.group IS NOT NULL
                    AND gg.accountRole IS NOT NULL
                )
            )
        GROUP BY account.id
        ORDER BY account.owner = ? DESC, account.isDefault DESC
    ]], { player.charId, player.charId, player.charId, player.charId }) or {}

    local result = {}

    for i = 1, #accounts do
        local account = accounts[i]

        if roleCanWithdraw(account.role) then
            result[#result + 1] = {
                id = account.id,
                label = account.label,
                balance = account.balance,
                isDefault = account.owner == player.charId and account.isDefault == 1,
                type = account.type,
                owner = account.ownerName
            }
        end
    end

    return result
end

local function chargePlayer(source, method, amount, accountId)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        return false, 'Neplatna castka.'
    end

    if method == 'cash' then
        local money = exports.ox_inventory:GetItemCount(source, 'money') or 0

        if money < amount then
            return false, 'Nemas dost hotovosti.'
        end

        exports.ox_inventory:RemoveItem(source, 'money', amount)
        return true
    end

    if method == 'bank' then
        accountId = tonumber(accountId)

        if not accountId then
            return false, 'Vyber ucet pro platbu kartou.'
        end

        local allowed = false
        local accounts = getBankAccounts(source)
        local selectedAccountData = nil

        for i = 1, #accounts do
            if accounts[i].id == accountId then
                allowed = true
                selectedAccountData = accounts[i]
                break
            end
        end

        if not allowed then
            return false, 'K tomuto uctu nemas pristup.'
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < amount then
            return false, 'Na uctu neni dost penez.'
        end

        if not removeAccountBalance(account, amount, 'Fuel prepayment', accountId) then
            return false, 'Platba z uctu se nepovedla.'
        end

        return true
    end

    return false, 'Neplatny typ platby.'
end

local function refundPlayer(source, method, amount, accountId)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return end

    if method == 'cash' then
        exports.ox_inventory:AddItem(source, 'money', amount)
        return
    end

    if method == 'bank' then
        accountId = tonumber(accountId)
        local account = accountId and Ox.GetAccount(accountId)

        addAccountBalance(account, amount, 'Unused fuel prepayment', accountId)
    end
end

local function fuelAllowedAtStation(stationType, fuelType)
    local station = Config.StationTypes[stationType]

    if not station then return false end

    for i = 1, #station.fuels do
        if station.fuels[i] == fuelType then return true end
    end

    return false
end

local function getVehicleFromNetId(netId)
    netId = tonumber(netId)
    if not netId then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil
    end

    return vehicle
end

local function playerNearVehicle(source, vehicle)
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    return #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= (Config.VehicleDistance + 3.0)
end

local function setFuelState(vehicle, fuel)
    local state = Entity(vehicle).state
    fuel = clamp(fuel, 0.0, 100.0)

    state:set('fuel', fuel, true)
end

math.randomseed(os.time())
publishPrices(true)

CreateThread(function()
    while Config.PriceUpdateMinutes and Config.PriceUpdateMinutes > 0 do
        Wait(Config.PriceUpdateMinutes * 60000)
        publishPrices(false)
    end
end)

lib.callback.register('fr_fuel:getFuelData', function(source, netId, clientExpectedFuel, clientFuel)
    local vehicle = getVehicleFromNetId(netId)

    if not vehicle or not playerNearVehicle(source, vehicle) then
        return { ok = false, message = 'Vozidlo je moc daleko.' }
    end

    local state = Entity(vehicle).state
    local expectedFuel = state.fr_expectedFuel

    if not FuelTypes.Exists(expectedFuel) then
        expectedFuel = FuelTypes.Exists(clientExpectedFuel) and clientExpectedFuel or FuelTypes.GetExpectedType(vehicle)
        state:set('fr_expectedFuel', expectedFuel, true)
    end

    local fuel = state.fuel

    if fuel == nil then
        fuel = clamp(clientFuel, 0.0, 100.0)
        state:set('fuel', fuel, true)
    end

    return {
        ok = true,
        fuel = clamp(fuel, 0.0, 100.0),
        expectedFuel = expectedFuel,
        prices = prices
    }
end)

lib.callback.register('fr_fuel:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

lib.callback.register('fr_fuel:startSession', function(source, data)
    if type(data) ~= 'table' then
        return { ok = false, message = 'Neplatna data.' }
    end

    if sessions[source] then
        return { ok = false, message = 'Uz tankujes.' }
    end

    local vehicle = getVehicleFromNetId(data.netId)

    if not vehicle or not playerNearVehicle(source, vehicle) then
        return { ok = false, message = 'Vozidlo je moc daleko.' }
    end

    local fuelType = data.fuelType
    local method = data.paymentMethod
    local stationType = data.stationType

    if not FuelTypes.Exists(fuelType) then
        return { ok = false, message = 'Neplatny typ paliva.' }
    end

    if not Config.PaymentMethods[method] then
        return { ok = false, message = 'Neplatny typ platby.' }
    end

    if not fuelAllowedAtStation(stationType, fuelType) then
        return { ok = false, message = 'Tento stojan nepodporuje vybrany typ paliva.' }
    end

    local currentFuel = clamp(data.currentFuel, 0.0, 100.0)
    local missingFuel = 100.0 - currentFuel

    if missingFuel <= 0.05 then
        return { ok = false, message = 'Nadrz je plna.' }
    end

    local units = clamp(data.units, Config.Prepay.minUnits, Config.Prepay.maxUnits)
    units = math.min(units, missingFuel)

    local price = prices[fuelType] or Config.FuelTypes[fuelType].price
    local prepaid = math.ceil(units * price)
    local expectedFuel = FuelTypes.Exists(data.expectedFuel) and data.expectedFuel or FuelTypes.GetExpectedType(vehicle)

    if stationType == 'charger' and expectedFuel ~= 'electric' then
        return { ok = false, message = 'Na nabijecce lze nabijet jen elektromobil.' }
    end

    if stationType == 'pump' and expectedFuel == 'electric' then
        return { ok = false, message = 'Elektromobil nelze tankovat na pumpe.' }
    end

    local charged, message = chargePlayer(source, method, prepaid, data.accountId)

    if not charged then
        return { ok = false, message = message or 'Platba se nepovedla.' }
    end

    local token = ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))

    Entity(vehicle).state:set('fr_expectedFuel', expectedFuel, true)

    sessions[source] = {
        token = token,
        netId = tonumber(data.netId),
        fuelType = fuelType,
        expectedFuel = expectedFuel,
        method = method,
        accountId = tonumber(data.accountId),
        units = units,
        price = price,
        prepaid = prepaid,
        initialFuel = currentFuel,
        startedAt = os.time()
    }

    return {
        ok = true,
        token = token,
        units = units,
        prepaid = prepaid,
        price = price,
        expectedFuel = expectedFuel
    }
end)

RegisterNetEvent('fr_fuel:finishSession', function(token, finalFuel)
    local source = source
    local session = sessions[source]

    if not session or session.token ~= token then
        return
    end

    sessions[source] = nil

    local vehicle = getVehicleFromNetId(session.netId)

    if not vehicle then
        refundPlayer(source, session.method, session.prepaid, session.accountId)
        return notify(source, 'Tankovani bylo zruseno, penize byly vraceny.', 'error')
    end

    finalFuel = clamp(finalFuel, 0.0, 100.0)

    local delivered = clamp(finalFuel - session.initialFuel, 0.0, session.units)
    local charged = math.ceil(delivered * session.price)
    local refund = session.prepaid - charged
    local newFuel = clamp(session.initialFuel + delivered, 0.0, 100.0)

    setFuelState(vehicle, newFuel)

    local vehState = Entity(vehicle).state
    vehState:set('fr_tankFuelType', session.fuelType, true)

    if Config.Prepay.refundUnused and refund > 0 then
        refundPlayer(source, session.method, refund, session.accountId)
    end

    local wrongFuel = Config.WrongFuelDamage.enabled and session.fuelType ~= session.expectedFuel
    local alreadyWrongFuel = vehState.fr_wrongFuel == true

    if wrongFuel then
        vehState:set('fr_wrongFuel', true, true)
        TriggerClientEvent('fr_fuel:damageVehicle', source, session.netId)
    elseif not alreadyWrongFuel then
        vehState:set('fr_wrongFuel', false, true)
    end

    local description = ('Natankovano %.1f l %s za %s.'):format(
        delivered,
        FuelTypes.GetLabel(session.fuelType),
        FuelTypes.FormatMoney(charged)
    )

    if refund > 0 and Config.Prepay.refundUnused then
        description = ('%s Vraceno %s.'):format(description, FuelTypes.FormatMoney(refund))
    end

    if wrongFuel then
        description = ('%s Spatne palivo poskodilo motor.'):format(description)
    end

    notify(source, description, wrongFuel and 'error' or 'success')
end)

AddEventHandler('playerDropped', function()
    local source = source
    local session = sessions[source]

    if session then
        refundPlayer(source, session.method, session.prepaid, session.accountId)
        sessions[source] = nil
    end
end)

RegisterCommand('frfuelprices', function(source)
    local parts = {}

    for fuelType, data in pairs(Config.FuelTypes) do
        parts[#parts + 1] = ('%s %s/l'):format(data.label, FuelTypes.FormatMoney(prices[fuelType] or data.price))
    end

    local text = table.concat(parts, ' | ')

    if source == 0 then
        print(('[fr_fuel] %s'):format(text))
    else
        notify(source, text, 'inform')
    end
end, false)

RegisterCommand('frfuelrefresh', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.frfuelrefresh') then
        return notify(source, 'Nemas opravneni.', 'error')
    end

    publishPrices(false)

    if source == 0 then
        ExecuteCommand('frfuelprices')
    else
        notify(source, 'Ceny paliv byly aktualizovany.', 'success')
    end
end, true)

exports('GetPrices', function()
    return prices
end)

local function clearWrongFuel(netId)
    local vehicle = getVehicleFromNetId(netId)

    if not vehicle then return false end

    local state = Entity(vehicle).state
    state:set('fr_wrongFuel', false, true)
    state:set('fr_tankFuelType', state.fr_expectedFuel or Config.DefaultFuelType, true)

    return true
end

RegisterNetEvent('fr_fuel:clearWrongFuel', function(netId)
    local source = source

    if not IsPlayerAceAllowed(source, 'command.frfuelrepair') then
        return notify(source, 'Nemas opravneni.', 'error')
    end

    if clearWrongFuel(netId) then
        notify(source, 'Palivovy system vozidla byl vycisten.', 'success')
    else
        notify(source, 'Vozidlo nenalezeno.', 'error')
    end
end)

exports('ClearWrongFuel', clearWrongFuel)


-- ==========================================
-- SERVER HANDLERY PRO SPOTŘEBU A KANYSTR
-- ==========================================

-- Synchronizace paliva za jízdy do State Bagu
RegisterNetEvent('fr_fuel:syncFuel', function(netId, fuel)
    local vehicle = getVehicleFromNetId(netId)
    if not vehicle then return end

    setFuelState(vehicle, fuel)
end)

-- Koupě nebo doplnění kanystru na pumpě
RegisterNetEvent('fr_fuel:petrolCanAction', function(hasCan)
    local source = source
    local price = hasCan and Config.PetrolCan.refillPrice or Config.PetrolCan.price

    local money = exports.ox_inventory:GetItemCount(source, 'money') or 0
    if money < price then
        return notify(source, 'Nemas dostatek penez.', 'error')
    end

    if hasCan then
        local item = exports.ox_inventory:GetCurrentWeapon(source)
        if not item or item.name ~= 'WEAPON_PETROLCAN' then return end

        exports.ox_inventory:RemoveItem(source, 'money', price)

        item.metadata.durability = 100
        item.metadata.ammo = 100
        exports.ox_inventory:SetMetadata(source, item.slot, item.metadata)

        notify(source, ('Kanystr byl doplnen za $%s.'):format(price), 'success')
    else
        if not exports.ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1) then
            return notify(source, 'Neuneses kanystr.', 'error')
        end

        exports.ox_inventory:RemoveItem(source, 'money', price)
        exports.ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1, { durability = 100, ammo = 100 })

        notify(source, ('Koupil jsi kanystr za $%s.'):format(price), 'success')
    end
end)

-- Odečet paliva z kanystru po dolití auta v terénu
RegisterNetEvent('fr_fuel:updateFuelCan', function(durabilityUsed, netId, newFuel)
    local source = source
    local item = exports.ox_inventory:GetCurrentWeapon(source)

    if item and item.name == 'WEAPON_PETROLCAN' and durabilityUsed > 0 then
        local currentDurability = item.metadata.durability or 100
        local updatedDurability = math.max(0, math.floor(currentDurability - durabilityUsed))

        item.metadata.durability = updatedDurability
        item.metadata.ammo = updatedDurability

        exports.ox_inventory:SetMetadata(source, item.slot, item.metadata)

        local vehicle = getVehicleFromNetId(netId)
        if vehicle then
            setFuelState(vehicle, newFuel)
        end
    end
end)
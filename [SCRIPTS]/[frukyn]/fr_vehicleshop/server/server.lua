local Ox = require '@ox_core.lib.init'
local playerState = {}

local function getShop(shopId)
    if not shopId then return nil end
    return Config.Shops[shopId]
end

local function getVehicleFromShop(shop, model)
    if not shop then return nil end
    for i = 1, #shop.vehicles do
        if shop.vehicles[i].model == model then
            return shop.vehicles[i]
        end
    end
    return nil
end

local function hasLicense(source, licenseType)
    if not licenseType or licenseType == false then return true end
    local ok, result = pcall(function() return exports.ox_core:CallPlayer(source, 'hasLicense', licenseType) end)
    return ok and result == true
end

local function roleCanWithdraw(role)
    if not role then return false end

    local permissions = GlobalState[('accountRole.%s'):format(role)]

    if permissions then
        return permissions.withdraw == true or permissions.withdraw == 1
    end

    return role == 'owner' or role == 'manager'
end

local function isManagerOrOwner(role)
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

local function getBankAccounts(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return {} end

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

-- Načtení pouze frakčních účtů, kde je hráč owner nebo manager
local function getFactionAccounts(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return {} end

    local accounts = MySQL.query.await([[
        SELECT DISTINCT
            COALESCE(access.role, gg.accountRole) AS role,
            account.id,
            account.label,
            account.balance,
            account.group,
            g.label AS groupLabel
        FROM accounts account
        INNER JOIN ox_groups g ON account.group = g.name
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
            AND account.group IS NOT NULL
            AND (
                access.charId = ?
                OR gg.accountRole IS NOT NULL
            )
        GROUP BY account.id
    ]], { player.charId, player.charId, player.charId }) or {}

    local result = {}

    for i = 1, #accounts do
        local acc = accounts[i]
        if isManagerOrOwner(acc.role) then
            result[#result + 1] = {
                id = acc.id,
                group = acc.group,
                label = ('%s (%s)'):format(acc.label or acc.groupLabel, acc.group),
                balance = tonumber(acc.balance) or 0
            }
        end
    end

    return result
end

-- Vrátí seznam frakcí, ve kterých má hráč úplně nejvyšší možnou hodnost (MAX grade)
local function getPlayerBossFactions(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return {} end

    local rows = MySQL.query.await([[
        SELECT 
            cg.name, 
            cg.grade, 
            g.label,
            gg.label AS gradeLabel
        FROM character_groups cg
        INNER JOIN ox_groups g ON cg.name = g.name
        LEFT JOIN ox_group_grades gg ON cg.name = gg.group AND cg.grade = gg.grade
        WHERE cg.charId = ?
          AND cg.grade = (
              SELECT MAX(gg2.grade) 
              FROM ox_group_grades gg2 
              WHERE gg2.group = cg.name
          )
    ]], { player.charId }) or {}

    return rows
end

-- Ověří, zda má hráč v dané frakci nejvyšší hodnost
local function isPlayerHighestGradeInGroup(source, groupName)
    if not groupName or groupName == '' then return false end
    local factions = getPlayerBossFactions(source)
    for i = 1, #factions do
        if factions[i].name == groupName then
            return true
        end
    end
    return false
end

local function chargePlayer(player, amount, payType, accountId)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        return false, 'Neplatná částka.'
    end

    if payType == 'cash' then
        local money = exports.ox_inventory:GetItemCount(player.source, 'money') or 0
        if money < amount then return false, 'Nemáš dost hotovosti.' end
        exports.ox_inventory:RemoveItem(player.source, 'money', amount)
        return true
    end

    if payType == 'bank' or payType == 'faction' then
        accountId = tonumber(accountId)

        if not accountId then
            return false, 'Vyber účet pro platbu.'
        end

        local allowed = false
        local accounts = payType == 'faction' and getFactionAccounts(player.source) or getBankAccounts(player.source)
        local selectedAccountData = nil

        for i = 1, #accounts do
            if accounts[i].id == accountId then
                allowed = true
                selectedAccountData = accounts[i]
                break
            end
        end

        if not allowed then
            return false, 'K tomuto účtu nemáš oprávnění pro platbu.'
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < amount then
            return false, 'Na účtu není dost peněz.'
        end

        if not removeAccountBalance(account, amount, 'Vehicle purchase', accountId) then
            return false, 'Platba z účtu se nepovedla.'
        end

        return true
    end

    return false, 'Neplatný typ platby.'
end

local function isSpawnFree(coords)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local vehCoords = GetEntityCoords(vehicles[i])
        if #(vehCoords - vec3(coords.x, coords.y, coords.z)) < 3.5 then
            return false
        end
    end
    return true
end

local function generateUniquePlate()
    local maxAttempts = 20
    for _ = 1, maxAttempts do
        local plate = Utils.GeneratePlate(Config.PlateFormat)
        local exists = MySQL.scalar.await('SELECT `plate` FROM `vehicles` WHERE `plate` = ? LIMIT 1', { plate })
        if not exists then return plate end
    end
    return ('CW%s'):format(math.random(10000, 99999))
end

local function generateVIN()
    local chars = "0123456789ABCDEFGHJKLMNPRSTUVWXYZ"
    local vin = ""
    for i = 1, 17 do
        local rand = math.random(1, #chars)
        vin = vin .. string.sub(chars, rand, rand)
    end
    return vin
end

local function saveOwnedVehicle(player, shopId, vehData, plate, colorIndex, spawnNow, spawnCoords, vClass, factionGroup)
    local shop = Config.Shops[shopId]
    local colorData = Config.ColorOptions[colorIndex] or Config.ColorOptions[1]
    local class = tonumber(vClass) or 0
    local garageName = shop.showroom.fallbackGarage or Config.DefaultGarageName
    
    local vehicleProps = {
        model = joaat(vehData.model),
        plate = plate,
        color1 = colorData.primary,
        color2 = colorData.secondary,
        class = class,
        type = vehData.type or 'car'
    }

    local isFaction = (factionGroup ~= nil and factionGroup ~= '')
    local vin = generateVIN()
    local storedValue = isFaction and factionGroup or garageName
    local dbId = nil

    if isFaction then
        -- Zápis pro frakci: owner je natvrdo NULL přímo v SQL dotazu
        dbId = MySQL.insert.await([[
            INSERT INTO `vehicles`
                (`plate`, `vin`, `owner`, `group`, `model`, `class`, `data`, `stored`, `fr_state`, `fr_vehicle_type`, `fr_fuel`)
            VALUES (?, ?, NULL, ?, ?, ?, ?, ?, "stored", ?, 100)
        ]], {
            plate,
            vin,
            factionGroup,
            vehData.model,
            class,
            json.encode(vehicleProps),
            storedValue,
            vehData.type or 'car'
        })
    else
        -- Zápis pro osobní vlastnictví: group je natvrdo NULL přímo v SQL dotazu
        dbId = MySQL.insert.await([[
            INSERT INTO `vehicles`
                (`plate`, `vin`, `owner`, `group`, `model`, `class`, `data`, `stored`, `fr_state`, `fr_vehicle_type`, `fr_fuel`)
            VALUES (?, ?, ?, NULL, ?, ?, ?, ?, "stored", ?, 100)
        ]], {
            plate,
            vin,
            player.charId,
            vehData.model,
            class,
            json.encode(vehicleProps),
            storedValue,
            vehData.type or 'car'
        })
    end

    local netId = nil
    if spawnNow and spawnCoords then
        local vehicle = Ox.SpawnVehicle(dbId, vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z), spawnCoords.w)
        if vehicle then
            netId = vehicle.netId
            MySQL.update.await('UPDATE `vehicles` SET `fr_state` = "out", `fr_entity_netid` = ? WHERE `id` = ?', { netId, dbId })
        end
    end

    return dbId, netId
end

local function formatPlate(plate)
    if not plate then return '' end
    return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

local function giveVehicleKey(source, plate, modelLabel)
    local cleanPlate = formatPlate(plate)
    local labelModel = modelLabel or 'Vozidlo'
    local count = (Config.KeysExport and Config.KeysExport.count) or 2

    local metadata = {
        plate = cleanPlate,
        model = labelModel,
        description = ('SPZ: %s  \nModel: %s'):format(cleanPlate, labelModel)
    }

    -- Přidáme klíče přímo přes ox_inventory (2x samostatný item se stejnou SPZ)
    local allSuccess = true
    for i = 1, count do
        local success, response = exports.ox_inventory:AddItem(source, 'carkey', 1, metadata)
        if not success then
            allSuccess = false
            print(('^1[fr_vehicleshop] CHYBA: Nepodařilo se dát carkey hráči %s! Důvod z ox_inventory: %s^7'):format(source, tostring(response)))
        else
            print(('^2[fr_vehicleshop] Klíč #%d [%s] úspěšně přidán hráči %s.^7'):format(i, cleanPlate, source))
        end
    end

    return allSuccess
end

local function countOwnedVehicles(charId)
    return MySQL.scalar.await('SELECT COUNT(1) FROM `vehicles` WHERE `owner` = ?', { charId }) or 0
end

lib.callback.register('fr_vehicleshop:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

lib.callback.register('fr_vehicleshop:getFactionAccounts', function(source)
    return getFactionAccounts(source)
end)

lib.callback.register('fr_vehicleshop:getPlayerFactions', function(source)
    return getPlayerBossFactions(source)
end)

lib.callback.register('fr_vehicleshop:requestTestDrive', function(source, payload)
    local player = Ox.GetPlayer(source)
    if not player then return { ok = false, message = 'Hráč nebyl nalezen.' } end
    if type(payload) ~= 'table' then return { ok = false, message = 'Neplatný požadavek.' } end

    local shop = getShop(payload.shopId)
    local veh = shop and getVehicleFromShop(shop, payload.model) or nil
    if not shop or not veh then return { ok = false, message = 'Neplatný výběr.' } end

    if not shop.showroom.testDrive or not shop.showroom.testDrive.enabled then
        return { ok = false, message = 'Testovací jízda je zde vypnutá.' }
    end

    if shop.licenseRequired and not hasLicense(source, shop.licenseRequired) then
        return { ok = false, message = 'Nemáš potřebnou licenci.' }
    end

    playerState[source] = playerState[source] or { strikes = {}, lastTestDrive = 0 }
    local now = os.time()
    if (now - playerState[source].lastTestDrive) < Config.TestDriveCooldownSeconds then
        return { ok = false, message = ('Počkej %s sekund.'):format(Config.TestDriveCooldownSeconds - (now - playerState[source].lastTestDrive)) }
    end

    playerState[source].lastTestDrive = now
    return { ok = true }
end)

lib.callback.register('fr_vehicleshop:buyVehicle', function(source, payload)
    local player = Ox.GetPlayer(source)
    if type(payload) ~= 'table' then return { ok = false, message = 'Neplatný požadavek.' } end
    if not player then return { ok = false, message = 'Hráč nebyl nalezen.' } end

    local shop = getShop(payload.shopId)
    local veh = shop and getVehicleFromShop(shop, payload.model) or nil
    local color = tonumber(payload.color)
    local payType = tostring(payload.payType or '')
    local buyType = tostring(payload.buyType or 'osobni')
    local accountId = tonumber(payload.accountId)
    local factionGroup = payload.factionGroup

    if not shop or not veh then return { ok = false, message = 'Neplatný výběr vozidla.' } end
    if not Config.ColorOptions[color or -1] then return { ok = false, message = 'Neplatná barva.' } end
    if payType ~= 'cash' and payType ~= 'bank' and payType ~= 'faction' then return { ok = false, message = 'Neplatný typ platby.' } end
    if buyType ~= 'osobni' and buyType ~= 'frakce' then return { ok = false, message = 'Neplatný typ vlastnictví.' } end

    local isFactionPurchase = (buyType == 'frakce')

    if isFactionPurchase then
        if not shop.allowSociety then
            return { ok = false, message = 'V tomto autosalonu nelze nakupovat vozidla na frakci.' }
        end

        if not factionGroup or factionGroup == '' then
            return { ok = false, message = 'Nebyla vybrána žádná frakce.' }
        end

        if shop.societyJobs and #shop.societyJobs > 0 and not Utils.TableContains(shop.societyJobs, factionGroup) then
            return { ok = false, message = 'Tvoje frakce v tomto autosalonu nemůže nakupovat.' }
        end

        -- Kontrola, že hráč má v dané frakci nejvyšší hodnost (MAX grade v ox_group_grades)
        if not isPlayerHighestGradeInGroup(source, factionGroup) then
            return { ok = false, message = 'Nákup na frakci může provést pouze nejvyšší vedení frakce!' }
        end
    else
        -- Pojistka: při osobním nákupu musí být factionGroup vždy nil
        factionGroup = nil

        if countOwnedVehicles(player.charId) >= Config.MaxOwnedVehiclesPerPlayer then
            return { ok = false, message = 'Dosáhl jsi limitu osobních vozidel.' }
        end
    end

    if shop.licenseRequired and not hasLicense(source, shop.licenseRequired) then
        return { ok = false, message = 'Nemáš potřebnou licenci.' }
    end

    local paid, reason = chargePlayer(player, veh.price, payType, accountId)
    if not paid then return { ok = false, message = reason } end

    local plate = generateUniquePlate()
    local spawnCoords = shop.showroom.spawnCoords
    local spawnNow = (spawnCoords and isSpawnFree(spawnCoords)) == true
    local dbId, netId = saveOwnedVehicle(player, payload.shopId, veh, plate, color, spawnNow, spawnCoords, payload.class, factionGroup)
    spawnNow = netId ~= nil

    -- Předáme source, SPZ a label vozidla (dá hráči 2x item klíče s metadaty)
    giveVehicleKey(source, plate, veh.label)

    local charName = (player.get('firstName') or '') .. ' ' .. (player.get('lastName') or '')
    local logType = isFactionPurchase and ('Frakce: ' .. tostring(factionGroup) .. ' | Platba: ' .. payType) or payType
    --logDiscord(('%s koupil %s za $%s [%s], SPZ: %s'):format(charName, veh.label, veh.price, logType, plate), source, 65280, 'vehicle_shop')

    return {
        ok = true,
        message = ('Zakoupeno: %s | SPZ %s %s'):format(veh.label, plate, isFactionPurchase and ('(Frakce: ' .. factionGroup .. ')') or ''),
        plate = plate,
        spawnNow = spawnNow,
        netId = netId
    }
end)

AddEventHandler('playerDropped', function()
    playerState[source] = nil
end)
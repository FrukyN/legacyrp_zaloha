local Ox = require '@ox_core.lib.init'
local Stock = {}

CreateThread(function()
    for itemName, data in pairs(Config.Items) do
        Stock[itemName] = {
            count = data.maxStock,
            currentPrice = data.minPrice 
        }
    end
end)

local function RecalculatePrice(itemName)
    local cfg = Config.Items[itemName]
    local currentStock = Stock[itemName].count
    
    local ratio = currentStock / cfg.maxStock
    local priceDiff = cfg.maxPrice - cfg.minPrice
    
    local newPrice = cfg.maxPrice - (priceDiff * ratio)
    Stock[itemName].currentPrice = math.floor(newPrice)
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

lib.callback.register('fr_shop:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

lib.callback.register('fr_shop:getShopData', function(source)
    return Stock
end)

lib.callback.register('fr_shop:checkout', function(source, cart, paymentMethod, accountId, printReceipt)
    local src = source
    local player = Ox.GetPlayer(src)
    if not player then return false, "Hráč nenalezen." end

    local totalCost = 0
    local finalCart = {}

    for _, item in ipairs(cart) do
        local itemName = item.name
        local reqCount = tonumber(item.count) or 0
        
        if reqCount <= 0 then
            return false, "Neplatný počet kusů v košíku."
        end

        if not Stock[itemName] or Stock[itemName].count < reqCount then
            return false, "Nedostatek zboží: " .. (Config.Items[itemName] and Config.Items[itemName].label or itemName)
        end
        
        local itemPrice = Stock[itemName].currentPrice * reqCount
        totalCost = totalCost + itemPrice
        
        table.insert(finalCart, {
            name = itemName,
            count = reqCount,
            price = itemPrice
        })
    end

    if totalCost <= 0 then
        return false, "Košík je prázdný."
    end

    if paymentMethod == "cash" then
        local cash = exports.ox_inventory:GetItemCount(src, 'money') or 0
        if cash < totalCost then return false, "Nemáš dostatek hotovosti." end
        exports.ox_inventory:RemoveItem(src, 'money', totalCost)
    elseif paymentMethod == "bank" then
        accountId = tonumber(accountId)
        if not accountId then
            return false, "Vyber bankovní účet pro platbu."
        end

        local allowed = false
        local accounts = getBankAccounts(src)
        local selectedAccountData = nil

        for i = 1, #accounts do
            if accounts[i].id == accountId then
                allowed = true
                selectedAccountData = accounts[i]
                break
            end
        end

        if not allowed then
            return false, "K tomuto účtu nemáš přístup."
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < totalCost then
            return false, "Na účtu není dost peněz."
        end

        if not removeAccountBalance(account, totalCost, 'Nákup v obchodě', accountId) then
            return false, "Platba z účtu se nepovedla."
        end
    else
        return false, "Neplatný typ platby."
    end

    local receiptDetails = "Účtenka:\n"
    for _, item in ipairs(finalCart) do
        Stock[item.name].count = Stock[item.name].count - item.count
        RecalculatePrice(item.name)
        exports.ox_inventory:AddItem(src, item.name, item.count)
        receiptDetails = receiptDetails .. ("%sx %s - $%s\n"):format(item.count, Config.Items[item.name].label, item.price)
    end

    receiptDetails = receiptDetails .. "\nCelkem zaplaceno: $" .. totalCost .. " (" .. paymentMethod .. ")"

    if printReceipt then
        exports.ox_inventory:AddItem(src, 'receipt2', 1, {
            description = receiptDetails
        })
    end

    return true, "Nákup proběhl úspěšně!"
end)

RegisterNetEvent('fr_shop:updateDoor', function(doorlockId, state)
    if type(doorlockId) == 'number' and type(state) == 'number' then
        exports.ox_doorlock:setDoorState(doorlockId, state)
    end
end)
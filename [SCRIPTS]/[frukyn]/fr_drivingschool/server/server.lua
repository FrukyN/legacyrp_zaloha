local Ox = require '@ox_core.lib.init'

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

lib.callback.register('autoskola:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

-- Čtení dat z tabulky character_licenses
lib.callback.register('autoskola:getOwnedLicenses', function(source)
    local player = Ox.GetPlayer(source)
    if not player then return {} end

    local charId = player.charId
    local result = MySQL.query.await('SELECT name, data FROM character_licenses WHERE charId = ? AND name LIKE ?',
        { charId, 'drive_%' })

    local licenses = {}
    if result then
        for i = 1, #result do
            local group = string.sub(result[i].name, 7)
            local data = json.decode(result[i].data) or {}
            licenses[group] = data
        end
    end
    return licenses
end)

-- Callback platby
lib.callback.register('autoskola:payTest', function(source, type, method, accountId)
    local cfg = Config.Licenses[type]
    if not cfg then return false, 'Neplatná skupina řidičáku.' end
    local price = cfg.price

    if method == 'cash' then
        local cashCount = exports.ox_inventory:GetItemCount(source, 'money') or 0
        if cashCount < price then
            return false, 'Nemáš dostatek hotovosti.'
        end
        exports.ox_inventory:RemoveItem(source, 'money', price)
        return true
    elseif method == 'bank' then
        accountId = tonumber(accountId)
        if not accountId then
            return false, 'Vyber bankovní účet pro platbu.'
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
            return false, 'K tomuto účtu nemáš přístup.'
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < price then
            return false, 'Na účtu není dost peněz.'
        end

        if not removeAccountBalance(account, price, ('Autoškola skupina %s'):format(type), accountId) then
            return false, 'Platba z účtu se nepovedla.'
        end

        return true
    end

    return false, 'Neplatný typ platby.'
end)

-- Uložení POUZE teorie do tabulky character_licenses
RegisterNetEvent('autoskola:saveTheory', function(type)
    local src = source
    local player = Ox.GetPlayer(src)
    if not player then return end

    local charId = player.charId
    local name = 'drive_' .. type
    local data = json.encode({ theory = true, practical = false })

    local exists = MySQL.scalar.await('SELECT 1 FROM character_licenses WHERE charId = ? AND name = ?', { charId, name })
    if exists then
        MySQL.update.await('UPDATE character_licenses SET data = ? WHERE charId = ? AND name = ?', { data, charId, name })
    else
        MySQL.insert.await('INSERT INTO character_licenses (charId, name, data) VALUES (?, ?, ?)', { charId, name, data })
    end
end)

-- Uložení KOMPLETNÍ zkoušky a odevzdání itemu
RegisterNetEvent('autoskola:giveLicense', function(type)
    local src = source
    local player = Ox.GetPlayer(src)
    if not player then return end

    local charId = player.charId
    local name = 'drive_' .. type
    local data = json.encode({ theory = true, practical = true })

    local exists = MySQL.scalar.await('SELECT 1 FROM character_licenses WHERE charId = ? AND name = ?', { charId, name })
    if exists then
        MySQL.update.await('UPDATE character_licenses SET data = ? WHERE charId = ? AND name = ?', { data, charId, name })
    else
        MySQL.insert.await('INSERT INTO character_licenses (charId, name, data) VALUES (?, ?, ?)', { charId, name, data })
    end

    exports.ox_inventory:AddItem(src, 'driver_license', 1, {
        description = 'Opravňuje k řízení vozidel skupiny ' .. type,
        type = type
    })

    print(('[Autoškola] Hráč (ID: %s) získal řidičský průkaz skupiny %s'):format(src, type))
end)
local Ox = require '@ox_core.lib.init'
local activeTests = {}

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

lib.callback.register('es_license_test:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

RegisterNetEvent('es_license_test:startTest', function(testId, method, accountId)
    local source = source
    local player = Ox.GetPlayer(source)
    if not player then return end

    local testData = Config.Tests[testId]
    if not testData then return end
    local charId = player.charId
    method = method or 'cash'

    local hasLicense = MySQL.scalar.await('SELECT 1 FROM character_licenses WHERE charId = ? AND name = ?',
        { charId, testId })
    if hasLicense then
        TriggerClientEvent('ox_lib:notify', source,
            { title = 'Chyba', description = 'Tento průkaz již vlastníš!', type = 'error' })
        return
    end

    if testData.requires then
        local hasReq = MySQL.scalar.await('SELECT 1 FROM character_licenses WHERE charId = ? AND name = ?',
            { charId, testData.requires })
        if not hasReq then
            TriggerClientEvent('ox_lib:notify', source,
                { title = 'Chybí oprávnění', description = 'Pro tento test potřebuješ licenci: ' .. testData.requires, type =
                'error' })
            return
        end
    end

    local price = testData.price

    if method == 'cash' then
        local currentMoney = exports.ox_inventory:GetItemCount(source, 'money') or 0
        if currentMoney < price then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Nedostatek financí',
                description = ('Nemáš u sebe dostatek hotovosti. Potřebuješ $%s.'):format(price),
                type = 'error'
            })
            return
        end

        exports.ox_inventory:RemoveItem(source, 'money', price)
    elseif method == 'bank' then
        accountId = tonumber(accountId)
        if not accountId then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Chyba platby',
                description = 'Vyber bankovní účet pro platbu.',
                type = 'error'
            })
            return
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
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Chyba platby',
                description = 'K tomuto účtu nemáš přístup.',
                type = 'error'
            })
            return
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < price then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Nedostatek financí',
                description = 'Na účtu není dost peněz.',
                type = 'error'
            })
            return
        end

        if not removeAccountBalance(account, price, ('License test: %s'):format(testData.label), accountId) then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Chyba platby',
                description = 'Platba z účtu se nepovedla.',
                type = 'error'
            })
            return
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Chyba platby',
            description = 'Neplatný typ platby.',
            type = 'error'
        })
        return
    end

    activeTests[source] = testId

    TriggerClientEvent('ox_lib:notify', source,
        { title = 'Platba úspěšná', description = ('Zaplatil jsi $%s za test.'):format(price), type = 'info' })
    TriggerClientEvent('es_license_test:cl_startTest', source, testId)
end)

RegisterNetEvent('es_license_test:evaluate', function(testId, correctAnswers, totalQuestions)
    local source = source
    local player = Ox.GetPlayer(source)
    if not player then return end

    if activeTests[source] ~= testId then
        print(('[Anti-Cheat] Hráč %s se pokusil odeslat výsledek testu bez placení!'):format(source))
        return
    end
    activeTests[source] = nil

    local testData = Config.Tests[testId]
    if not testData then return end

    if correctAnswers >= testData.minCorrect then
        MySQL.insert.await('INSERT IGNORE INTO character_licenses (charId, name) VALUES (?, ?)', { player.charId, testId })

        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Test úspěšně dokončen!',
            description = ('Správně: %s/%s. Získal jsi: %s'):format(correctAnswers, totalQuestions, testData.label),
            type = 'success',
            duration = 5000
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'U testu jsi neuspěl',
            description = ('Správně pouze %s/%s. Minimum pro splnění je %s.'):format(correctAnswers, totalQuestions,
                testData.minCorrect),
            type = 'error',
            duration = 5000
        })
    end
end)

RegisterNetEvent('es_license_test:cancelTest', function()
    local source = source
    activeTests[source] = nil
end)
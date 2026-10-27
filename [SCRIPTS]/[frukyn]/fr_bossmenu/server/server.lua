local Ox = require '@ox_core.lib.init'

local StashesRegistered = false

local function logDiscord(text, src, color, title)
    local ok, err = pcall(function()
        exports.JD_logs:discord(text, src or 0, 0, color or Config.WebhookColors.Info, title or 'bossmenu')
    end)
    if not ok and Config.Debug then print(('[bossmenu] JD_logs failed: %s'):format(err)) end
end

local function banForExploit(src, reason, details)
    logDiscord(('Exploit detection (%s): %s'):format(reason, details or 'no-details'), src, Config.WebhookColors.Danger, 'bossmenu_anticheat')
    if not Config.BanOnExploit then return end
    pcall(function() exports['ElectronAC']:banPlayer(src, reason, details or 'bossmenu exploit', false) end)
end

local function toInt(value)
    local n = tonumber(value)
    if not n then return nil end
    n = math.floor(n)
    if n < 0 then return nil end
    return n
end

local function hasLength(str, maxLen)
    return type(str) == 'string' and #str > 0 and #str <= maxLen
end

local function getJobConfig(jobName)
    return Config.Jobs[jobName]
end

local function getPlayerJob(player)
    if not player then return nil end
    local jobName, grade = player.getGroupByType and player.getGroupByType('job')
    if type(jobName) == 'table' then 
        for k, v in pairs(jobName) do jobName, grade = k, v break end 
    end
    if not jobName then return nil end

    local cfg = getJobConfig(jobName)
    local normalizedGrade = math.max((tonumber(grade) or 1), 0)
    return {
        name = jobName,
        grade = normalizedGrade,
        label = (cfg and cfg.label) or jobName
    }
end

local function getFullNameFromXPlayer(xPlayer)
    if not xPlayer then return 'Unknown' end
    local fn = xPlayer.get('firstName')
    local ln = xPlayer.get('lastName')
    if fn and ln then return ('%s %s'):format(fn, ln) end
    return xPlayer.name or ('Unknown (%s)'):format(xPlayer.charId or 'no-id')
end

local function getOfflineName(identifier)
    local row = MySQL.single.await('SELECT firstName, lastName FROM characters WHERE charId = ? LIMIT 1', { identifier })
    if not row then return tostring(identifier) end
    if row.firstName and row.lastName then
        return ('%s %s'):format(row.firstName, row.lastName)
    end
    return tostring(identifier)
end

-- Society accounts logic
local function ensureSocietyAccount(jobName)
    MySQL.insert.await('INSERT IGNORE INTO bossmenu_society_accounts (job_name, balance) VALUES (?, 0)', { jobName })
end

local function getSocietyBalance(jobName)
    ensureSocietyAccount(jobName)
    local row = MySQL.single.await('SELECT balance FROM bossmenu_society_accounts WHERE job_name = ? LIMIT 1', { jobName })
    return row and row.balance or 0
end

local function setSocietyBalance(jobName, newBalance)
    ensureSocietyAccount(jobName)
    MySQL.update.await('UPDATE bossmenu_society_accounts SET balance = ? WHERE job_name = ?', { newBalance, jobName })
end

-- Bank & Money helpers
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

local function addTransaction(jobName, action, amount, actor, targetIdentifier, targetName, reason)
    MySQL.insert.await([[
        INSERT INTO bossmenu_transactions (job_name, action, amount, actor_identifier, actor_name, target_identifier, target_name, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { jobName, action, amount, tostring(actor.charId), getFullNameFromXPlayer(actor), targetIdentifier, targetName, reason })
end

local function addHRHistory(jobName, action, actor, targetIdentifier, targetName, fromGrade, toGrade, amount, reason)
    MySQL.insert.await([[
        INSERT INTO bossmenu_hr_history (job_name, action, actor_identifier, actor_name, target_identifier, target_name, from_grade, to_grade, amount, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { jobName, action, tostring(actor.charId), getFullNameFromXPlayer(actor), targetIdentifier, targetName, fromGrade, toGrade, amount, reason })
end

local function addActivity(jobName, identifier, name, action, metadata)
    MySQL.insert.await([[
        INSERT INTO bossmenu_activity (job_name, identifier, name, action, metadata)
        VALUES (?, ?, ?, ?, ?)
    ]], { jobName, identifier, name, action, metadata and json.encode(metadata) or nil })
end

local function requireBoss(source, requiredGrade, context)
    local xPlayer = Ox.GetPlayer(source)
    if not xPlayer then return nil, nil, 'not_loaded' end
    local job = getPlayerJob(xPlayer)
    if not job or not job.name then
        banForExploit(source, 'bossmenu_invalid_job', context or 'job missing')
        return nil, nil, 'invalid_job'
    end
    local jobConfig = getJobConfig(job.name)
    if not jobConfig then
        banForExploit(source, 'bossmenu_unknown_job', ('%s / %s'):format(context or 'no-context', job.name))
        return nil, nil, 'unknown_job'
    end
    local minGrade = math.max(requiredGrade or 0, jobConfig.target and jobConfig.target.minGrade or 0)
    if (job.grade or 0) < minGrade then return nil, nil, 'insufficient_grade' end
    return xPlayer, job, nil
end

local function playerInSameJobOnline(identifier, jobName)
    local players = GetPlayers()
    for i = 1, #players do
        local xTarget = Ox.GetPlayer(tonumber(players[i]))
        if xTarget and tostring(xTarget.charId) == tostring(identifier) then
            local tJob = getPlayerJob(xTarget)
            if tJob and tJob.name == jobName then return xTarget end
        end
    end
    return nil
end

local function getOnlineAndTotal(jobName)
    local online = 0
    local players = GetPlayers()
    for i = 1, #players do
        local xPlayer = Ox.GetPlayer(tonumber(players[i]))
        local playerJob = getPlayerJob(xPlayer)
        if playerJob and playerJob.name == jobName then online = online + 1 end
    end
    local total = MySQL.scalar.await('SELECT COUNT(1) FROM character_groups WHERE name = ?', { jobName }) or 0
    return online, total
end

local function getWeekTopEmployee(jobName)
    local row = MySQL.single.await([[
        SELECT identifier, SUM(minutes) AS total_minutes
        FROM bossmenu_attendance_log
        WHERE job_name = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY identifier ORDER BY total_minutes DESC LIMIT 1
    ]], { jobName })
    if not row then return nil end
    return { identifier = row.identifier, minutes = row.total_minutes, name = getOfflineName(row.identifier) }
end

local function updateAttendance(identifier, jobName, minutes)
    MySQL.insert.await([[
        INSERT INTO bossmenu_attendance (identifier, job_name, total_minutes, last_seen)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE total_minutes = total_minutes + VALUES(total_minutes), last_seen = NOW(), updated_at = NOW()
    ]], { identifier, jobName, minutes })
    MySQL.insert.await('INSERT INTO bossmenu_attendance_log (identifier, job_name, minutes) VALUES (?, ?, ?)', { identifier, jobName, minutes })
end

local function processAttendanceTick()
    local tickMinutes = Config.AttendanceTickMinutes
    local players = GetPlayers()
    for i = 1, #players do
        local xPlayer = Ox.GetPlayer(tonumber(players[i]))
        if xPlayer then
            local job = getPlayerJob(xPlayer)
            if job and getJobConfig(job.name) then updateAttendance(tostring(xPlayer.charId), job.name, tickMinutes) end
        end
    end
end

local function registerStashes()
    if StashesRegistered then return end
    for jobName, cfg in pairs(Config.Jobs) do
        if cfg.stash and cfg.stash.id then
            exports.ox_inventory:RegisterStash(cfg.stash.id, cfg.stash.label or ('%s Stash'):format(jobName), cfg.stash.slots or 100, cfg.stash.weight or 500000, false, { [jobName] = cfg.target and cfg.target.minGrade or 0 })
        end
    end
    StashesRegistered = true
end

local function getEmployeeRows(jobName)
    return MySQL.query.await([[
        SELECT c.charId as identifier, c.firstName, c.lastName, cg.grade as job_grade, IFNULL(a.total_minutes, 0) AS total_minutes, a.last_seen
        FROM characters c
        INNER JOIN character_groups cg ON cg.charId = c.charId AND cg.name = ?
        LEFT JOIN bossmenu_attendance a ON a.identifier = CAST(c.charId AS CHAR) AND a.job_name = ?
        ORDER BY cg.grade DESC, c.firstName ASC
    ]], { jobName, jobName })
end

local function buildEmployeeName(row)
    if row.firstName and row.lastName and row.firstName ~= '' then
        return ('%s %s'):format(row.firstName, row.lastName)
    end
    return tostring(row.identifier)
end

lib.callback.register('bossmenu:server:getBankAccounts', function(source)
    return getBankAccounts(source)
end)

lib.callback.register('bossmenu:server:getDashboard', function(source)
    local xPlayer, job, err = requireBoss(source, Config.Grades.Finance, 'get_dashboard')
    if err then return nil end
    local online, total = getOnlineAndTotal(job.name)
    local top = getWeekTopEmployee(job.name)
    local balance = getSocietyBalance(job.name)
    local announcements = MySQL.query.await('SELECT id, message, author_name, created_at FROM bossmenu_announcements WHERE job_name = ? ORDER BY id DESC LIMIT 5', { job.name })
    return { job = job, jobLabel = (Config.Jobs[job.name] and Config.Jobs[job.name].label) or job.name, balance = balance, online = online, total = total, topEmployee = top, announcements = announcements }
end)

lib.callback.register('bossmenu:server:getEmployees', function(source)
    local _, job, err = requireBoss(source, Config.Grades.Employees, 'get_employees')
    if err then return nil end
    local rows = getEmployeeRows(job.name)
    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        out[#out + 1] = {
            identifier = tostring(row.identifier),
            name = buildEmployeeName(row),
            grade = row.job_grade,
            gradeLabel = ('Grade %s'):format(row.job_grade),
            salary = 0,
            minutes = row.total_minutes or 0,
            lastSeen = row.last_seen
        }
    end
    return out
end)

lib.callback.register('bossmenu:server:getEmployeeDetail', function(source, identifier)
    local _, job, err = requireBoss(source, Config.Grades.Employees, 'get_employee_detail')
    if err then return nil end
    if not identifier then return nil end

    local notes = MySQL.query.await('SELECT id, note, author_name, created_at FROM bossmenu_employee_notes WHERE job_name = ? AND employee_identifier = ? ORDER BY id DESC LIMIT 20', { job.name, identifier })
    local hr = MySQL.query.await('SELECT action, actor_name, from_grade, to_grade, amount, reason, created_at FROM bossmenu_hr_history WHERE job_name = ? AND target_identifier = ? ORDER BY id DESC LIMIT 20', { job.name, identifier })
    local attendance7d = MySQL.query.await([[
        SELECT DATE(created_at) AS day, SUM(minutes) AS minutes FROM bossmenu_attendance_log
        WHERE job_name = ? AND identifier = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY DATE(created_at) ORDER BY day DESC
    ]], { job.name, identifier })

    return { notes = notes, hrHistory = hr, attendance7d = attendance7d }
end)

lib.callback.register('bossmenu:server:getTransactions', function(source)
    local _, job, err = requireBoss(source, Config.Grades.Finance, 'get_transactions')
    if err then return nil end
    return MySQL.query.await('SELECT action, amount, actor_name, target_name, reason, created_at FROM bossmenu_transactions WHERE job_name = ? ORDER BY id DESC LIMIT 100', { job.name })
end)

lib.callback.register('bossmenu:server:getHRHistory', function(source)
    local _, job, err = requireBoss(source, Config.Grades.Employees, 'get_hr_history')
    if err then return nil end
    return MySQL.query.await('SELECT action, actor_name, target_name, from_grade, to_grade, amount, reason, created_at FROM bossmenu_hr_history WHERE job_name = ? ORDER BY id DESC LIMIT 100', { job.name })
end)

lib.callback.register('bossmenu:server:getAnnouncements', function(source)
    local _, job, err = requireBoss(source, Config.Grades.Employees, 'get_announcements')
    if err then return nil end
    return MySQL.query.await('SELECT id, message, author_name, created_at FROM bossmenu_announcements WHERE job_name = ? ORDER BY id DESC LIMIT 20', { job.name })
end)

lib.callback.register('bossmenu:server:getPendingOrders', function(source)
    local _, job, err = requireBoss(source, Config.Grades.Employees, 'get_orders')
    if err then return nil end
    return MySQL.query.await('SELECT id, item, amount, total_price, ordered_by_name, status, deliver_at, created_at FROM bossmenu_material_orders WHERE job_name = ? ORDER BY id DESC LIMIT 20', { job.name })
end)

-- PENÍZE (VKLAD & VÝBĚR)
RegisterNetEvent('bossmenu:server:deposit', function(amount, sourceType, accountId)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Finance, 'deposit')
    if err then return end

    local value = toInt(amount)
    if not value or value <= 0 or value > Config.MaxDeposit then
        banForExploit(src, 'bossmenu_bad_amount', ('deposit:%s'):format(tostring(amount)))
        return
    end

    if sourceType == 'cash' then
        local moneyBal = exports.ox_inventory:GetItemCount(src, 'money') or 0
        if moneyBal < value then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Nemáš dost hotovosti.' })
            return
        end
        exports.ox_inventory:RemoveItem(src, 'money', value)
    elseif sourceType == 'bank' then
        accountId = tonumber(accountId)
        if not accountId then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vyber účet pro vklad.' })
            return
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
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'K tomuto účtu nemáš přístup.' })
            return
        end

        local account = Ox.GetAccount(accountId)
        local balance = getAccountBalance(account) or (selectedAccountData and tonumber(selectedAccountData.balance))

        if not balance or balance < value then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Na účtu není dost peněz.' })
            return
        end

        if not removeAccountBalance(account, value, ('Bossmenu deposit: %s'):format(job.name), accountId) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Platba z účtu se nepovedla.' })
            return
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Neplatný typ platby.' })
        return
    end

    local oldBalance = getSocietyBalance(job.name)
    setSocietyBalance(job.name, oldBalance + value)

    addTransaction(job.name, 'deposit', value, xPlayer, nil, nil, ('boss_deposit (%s)'):format(sourceType))
    addActivity(job.name, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer), 'deposit', { amount = value, type = sourceType })
    logDiscord(('Player deposited %s to society %s via %s'):format(value, job.name, sourceType), src, Config.WebhookColors.Success, 'bossmenu_finance')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Vloženo $%s na firemní účet.'):format(value) })
end)

RegisterNetEvent('bossmenu:server:withdraw', function(amount, targetType, accountId)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Finance, 'withdraw')
    if err then return end

    local value = toInt(amount)
    if not value or value <= 0 or value > Config.MaxWithdraw then
        banForExploit(src, 'bossmenu_bad_amount', ('withdraw:%s'):format(tostring(amount)))
        return
    end

    local balance = getSocietyBalance(job.name)
    if balance < value then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Firemní účet nemá dostatek financí.' })
        return
    end

    if targetType == 'cash' then
        exports.ox_inventory:AddItem(src, 'money', value)
    elseif targetType == 'bank' then
        accountId = tonumber(accountId)
        if not accountId then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vyber účet pro převod.' })
            return
        end

        local allowed = false
        local accounts = getBankAccounts(src)

        for i = 1, #accounts do
            if accounts[i].id == accountId then
                allowed = true
                break
            end
        end

        if not allowed then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'K tomuto účtu nemáš přístup.' })
            return
        end

        local account = Ox.GetAccount(accountId)
        if not addAccountBalance(account, value, ('Bossmenu withdrawal: %s'):format(job.name), accountId) then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Připsání na účet se nepovedlo.' })
            return
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Neplatný typ platby.' })
        return
    end

    setSocietyBalance(job.name, balance - value)

    addTransaction(job.name, 'withdraw', value, xPlayer, nil, nil, ('boss_withdraw (%s)'):format(targetType))
    addActivity(job.name, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer), 'withdraw', { amount = value, type = targetType })
    logDiscord(('Player withdrew %s from society %s via %s'):format(value, job.name, targetType), src, Config.WebhookColors.Warning, 'bossmenu_finance')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Vybráno $%s z firemního účtu.'):format(value) })
end)

-- EMPLOYEE MANAGEMENT
RegisterNetEvent('bossmenu:server:hire', function(targetSource)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'hire')
    if err then return end
    local targetId = tonumber(targetSource)
    if not targetId then return end

    local xTarget = Ox.GetPlayer(targetId)
    if not xTarget then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target player is not online.' })
        return
    end

    local targetJob = getPlayerJob(xTarget)
    if targetJob and targetJob.name == job.name then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Player is already in this job.' })
        return
    end

    xTarget.setGroup(job.name, 1)

    local targetName = getFullNameFromXPlayer(xTarget)
    addHRHistory(job.name, 'hire', xPlayer, tostring(xTarget.charId), targetName, nil, 1, nil, 'hired')
    addActivity(job.name, tostring(xTarget.charId), targetName, 'hire', { actor = xPlayer.charId })
    logDiscord(('%s hired %s to %s'):format(getFullNameFromXPlayer(xPlayer), targetName, job.name), src, Config.WebhookColors.Success, 'bossmenu_hr')

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Hired %s.'):format(targetName) })
    TriggerClientEvent('ox_lib:notify', xTarget.source, { type = 'inform', description = ('You were hired in %s.'):format(job.label or job.name) })
end)

RegisterNetEvent('bossmenu:server:fire', function(identifier, reason)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'fire')
    if err then return end
    if not identifier then return end

    reason = type(reason) == 'string' and reason:sub(1, 120) or 'fired'
    local current = MySQL.single.await('SELECT grade FROM character_groups WHERE charId = ? AND name = ? LIMIT 1', { identifier, job.name })
    if not current then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Employee is not in your company.' })
        return
    end

    local targetName = getOfflineName(identifier)
    local onlineTarget = playerInSameJobOnline(identifier, job.name)

    if onlineTarget then
        pcall(function() onlineTarget.setGroup(job.name, 0) end)
        TriggerClientEvent('ox_lib:notify', onlineTarget.source, { type = 'error', description = ('You were fired from %s.'):format(job.label or job.name) })
    else
        MySQL.query.await('DELETE FROM character_groups WHERE charId = ? AND name = ?', { identifier, job.name })
    end

    addHRHistory(job.name, 'fire', xPlayer, identifier, targetName, current.grade, 0, nil, reason)
    addActivity(job.name, identifier, targetName, 'fire', { actor = tostring(xPlayer.charId), reason = reason })
    logDiscord(('%s fired %s from %s (%s)'):format(getFullNameFromXPlayer(xPlayer), targetName, job.name, reason), src, Config.WebhookColors.Danger, 'bossmenu_hr')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Fired %s.'):format(targetName) })
end)

RegisterNetEvent('bossmenu:server:setGrade', function(identifier, newGrade)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'set_grade')
    if err then return end

    local grade = tonumber(newGrade)
    if not grade or grade < 0 or grade > 20 then
        banForExploit(src, 'bossmenu_bad_grade', tostring(newGrade))
        return
    end

    local current = MySQL.single.await('SELECT grade FROM character_groups WHERE charId = ? AND name = ? LIMIT 1', { identifier, job.name })
    if not current then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Employee is not in your company.' })
        return
    end

    local targetName = getOfflineName(identifier)
    local onlineTarget = playerInSameJobOnline(identifier, job.name)

    if onlineTarget then
        onlineTarget.setGroup(job.name, grade)
        TriggerClientEvent('ox_lib:notify', onlineTarget.source, { type = 'inform', description = ('Your grade was changed to %s.'):format(grade) })
    else
        MySQL.update.await('UPDATE character_groups SET grade = ? WHERE charId = ? AND name = ?', { grade, identifier, job.name })
    end

    addHRHistory(job.name, 'grade_change', xPlayer, identifier, targetName, current.grade, grade, nil, 'manual_grade_change')
    addActivity(job.name, identifier, targetName, 'grade_change', { actor = tostring(xPlayer.charId), from = current.grade, to = grade })
    logDiscord(('%s changed grade for %s from %s to %s (%s)'):format(getFullNameFromXPlayer(xPlayer), targetName, current.grade, grade, job.name), src, Config.WebhookColors.Info, 'bossmenu_hr')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Updated grade for %s.'):format(targetName) })
end)

RegisterNetEvent('bossmenu:server:bonus', function(identifier, amount, reason)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'bonus')
    if err then return end

    local value = toInt(amount)
    if not value or value <= 0 or value > Config.MaxBonus then
        banForExploit(src, 'bossmenu_bad_bonus', tostring(amount))
        return
    end

    reason = type(reason) == 'string' and reason:sub(1, 120) or 'bonus'

    local current = MySQL.single.await('SELECT grade FROM character_groups WHERE charId = ? AND name = ? LIMIT 1', { identifier, job.name })
    if not current then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Employee is not in your company.' })
        return
    end

    local balance = getSocietyBalance(job.name)
    if balance < value then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Insufficient company funds for bonus.' })
        return
    end

    local onlineTarget = playerInSameJobOnline(identifier, job.name)
    local targetName = getOfflineName(identifier)
    if Config.PayrollOnlineOnly and not onlineTarget then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Target employee must be online for bonus payout.' })
        return
    end

    setSocietyBalance(job.name, balance - value)

    if onlineTarget then
        local account = Ox.GetCharacterAccount(onlineTarget.charId)
        if account then
            addAccountBalance(account, value, 'Bossmenu bonus')
        end
        TriggerClientEvent('ox_lib:notify', onlineTarget.source, { type = 'success', description = ('You received a bonus: $%s.'):format(value) })
    end

    addTransaction(job.name, 'bonus', value, xPlayer, identifier, targetName, reason)
    addHRHistory(job.name, 'bonus', xPlayer, identifier, targetName, nil, nil, value, reason)
    addActivity(job.name, identifier, targetName, 'bonus', { actor = tostring(xPlayer.charId), amount = value, reason = reason })
    logDiscord(('%s gave bonus %s to %s (%s)'):format(getFullNameFromXPlayer(xPlayer), value, targetName, reason), src, Config.WebhookColors.Success, 'bossmenu_finance')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Bonus paid to %s.'):format(targetName) })
end)

RegisterNetEvent('bossmenu:server:addEmployeeNote', function(identifier, note)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'note_add')
    if err then return end

    if not hasLength(note, Config.MaxNoteLength) then
        banForExploit(src, 'bossmenu_bad_note', tostring(note and #note or 'nil'))
        return
    end

    local current = MySQL.single.await('SELECT grade FROM character_groups WHERE charId = ? AND name = ? LIMIT 1', { identifier, job.name })
    if not current then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Employee is not in your company.' })
        return
    end

    MySQL.insert.await([[
        INSERT INTO bossmenu_employee_notes (job_name, employee_identifier, note, author_identifier, author_name)
        VALUES (?, ?, ?, ?, ?)
    ]], { job.name, identifier, note, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer) })

    addActivity(job.name, identifier, getOfflineName(identifier), 'note_add', { actor = tostring(xPlayer.charId) })
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Employee note added.' })
end)

RegisterNetEvent('bossmenu:server:addAnnouncement', function(message)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'announcement_add')
    if err then return end

    if not hasLength(message, Config.MaxAnnouncementLength) then
        banForExploit(src, 'bossmenu_bad_announcement', tostring(message and #message or 'nil'))
        return
    end

    MySQL.insert.await([[
        INSERT INTO bossmenu_announcements (job_name, message, author_identifier, author_name)
        VALUES (?, ?, ?, ?)
    ]], { job.name, message, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer) })

    addActivity(job.name, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer), 'announcement_add', { message = message })

    local players = GetPlayers()
    for i = 1, #players do
        local p = Ox.GetPlayer(tonumber(players[i]))
        if p then
            local pJob = getPlayerJob(p)
            if pJob and pJob.name == job.name then
                TriggerClientEvent('ox_lib:notify', p.source, { type = 'inform', title = 'Company announcement', description = message })
            end
        end
    end

    logDiscord(('%s posted company announcement for %s: %s'):format(getFullNameFromXPlayer(xPlayer), job.name, message), src, Config.WebhookColors.Info, 'bossmenu_announcement')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Announcement published.' })
end)

RegisterNetEvent('bossmenu:server:openStash', function()
    local src = source
    local _, job, err = requireBoss(src, Config.Grades.Employees, 'open_stash')
    if err then return end
    local cfg = getJobConfig(job.name)
    if not cfg or not cfg.stash then return end
    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', cfg.stash.id)
end)

RegisterNetEvent('bossmenu:server:createMaterialOrder', function(itemName, amount)
    local src = source
    local xPlayer, job, err = requireBoss(src, Config.Grades.Employees, 'create_order')
    if err then return end

    local cfg = getJobConfig(job.name)
    local orderCfg = cfg and cfg.materialsOrder
    if not (Config.OrderSystem.Enabled and orderCfg and orderCfg.enabled) then return end

    local qty = toInt(amount)
    if not qty or qty <= 0 or qty > Config.MaxOrderAmount then return end

    local catalogItem
    for i = 1, #orderCfg.items do
        if orderCfg.items[i].item == itemName then catalogItem = orderCfg.items[i]; break end
    end
    if not catalogItem then return end

    local total = qty * catalogItem.price
    local balance = getSocietyBalance(job.name)
    if balance < total then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Company account balance is too low for this order.' })
        return
    end

    setSocietyBalance(job.name, balance - total)

    local deliverySeconds = orderCfg.deliverySeconds or Config.OrderSystem.DefaultDeliverySeconds
    MySQL.insert.await([[
        INSERT INTO bossmenu_material_orders (job_name, item, amount, total_price, ordered_by_identifier, ordered_by_name, status, deliver_at)
        VALUES (?, ?, ?, ?, ?, ?, 'pending', DATE_ADD(NOW(), INTERVAL ? SECOND))
    ]], { job.name, itemName, qty, total, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer), deliverySeconds })

    addTransaction(job.name, 'material_order', total, xPlayer, nil, nil, ('order:%s x%s'):format(itemName, qty))
    addActivity(job.name, tostring(xPlayer.charId), getFullNameFromXPlayer(xPlayer), 'material_order', { item = itemName, amount = qty, price = total })
    logDiscord(('%s ordered %sx %s for %s (cost %s)'):format(getFullNameFromXPlayer(xPlayer), qty, itemName, job.name, total), src, Config.WebhookColors.Warning, 'bossmenu_orders')
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Order placed: %sx %s. Delivery in %s minutes.'):format(qty, itemName, math.floor(deliverySeconds / 60)) })
end)

CreateThread(function()
    Wait(1500)
    registerStashes()
    for jobName, _ in pairs(Config.Jobs) do ensureSocietyAccount(jobName) end
    while true do Wait((Config.AttendanceTickMinutes or 5) * 60000); processAttendanceTick() end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local orders = MySQL.query.await('SELECT id, job_name, item, amount FROM bossmenu_material_orders WHERE status = \'pending\' AND deliver_at <= NOW() LIMIT 30')
        for i = 1, #orders do
            local order = orders[i]
            local cfg = getJobConfig(order.job_name)
            if cfg and cfg.stash then
                local success = exports.ox_inventory:AddItem(cfg.stash.id, order.item, order.amount)
                if success then
                    MySQL.update.await('UPDATE bossmenu_material_orders SET status = ?, delivered_at = NOW() WHERE id = ?', { 'delivered', order.id })
                else
                    MySQL.update.await('UPDATE bossmenu_material_orders SET status = ? WHERE id = ?', { 'failed', order.id })
                end
            else
                MySQL.update.await('UPDATE bossmenu_material_orders SET status = ? WHERE id = ?', { 'failed', order.id })
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(500)
    registerStashes()
end)
local pending = {}
local sequence = 0

local function getPlayer(source)
    return exports.ox_core:GetPlayer(source)
end

local function identifier(source)
    local player = getPlayer(source)
    return player and (player.charId or player.identifier)
end

local function nameOf(source)
    local player = getPlayer(source)
    return player and (player.getName and player:getName() or player.name) or GetPlayerName(source)
end

local function accountName(accountId)
    for _, r in ipairs(Config.Registers) do if r.accountId == accountId then return r.label end end
    return accountId or 'Platební terminál'
end

local function receipt(source, data)
    exports.ox_inventory:AddItem(source, Config.ReceiptItem, 1, {
        date = os.date('%d.%m.%Y %H:%M'), business = data.business, amount = data.amount,
        reason = data.reason, signature = data.signature
    })
end

local function requestImmediate(employee, target, amount, reason, accountId)
    if type(target) ~= 'number' or type(amount) ~= 'number' or amount < 1 or not reason or #reason > 180 then return end
    if #(GetEntityCoords(GetPlayerPed(employee)) - GetEntityCoords(GetPlayerPed(target))) > Config.MaxDistance + 1.0 then return end
    sequence = sequence + 1
    local id = ('pos:%s:%s'):format(os.time(), sequence)
    pending[id] = { id = id, employee = employee, target = target, amount = math.floor(amount), reason = reason, accountId = accountId, business = accountName(accountId), expires = os.time() + 90 }
    TriggerClientEvent('fr_faktury:client:openPayment', target, pending[id])
    return true
end

RegisterNetEvent('fr_faktury:server:requestImmediate', function(target, amount, reason, accountId)
    requestImmediate(source, target, amount, reason, accountId)
end)

RegisterNetEvent('fr_faktury:server:declined', function(employee, id)
    local invoice = pending[id]
    if invoice and invoice.target == source then
        pending[id] = nil
        TriggerClientEvent('fr_faktury:client:employeeDeclined', employee)
    end
end)

RegisterNetEvent('fr_faktury:server:payImmediate', function(id, method, tipPercent)
    local payer, invoice = source, pending[id]
    if not invoice or invoice.target ~= payer or invoice.expires < os.time() then return end
    local tip = math.floor(invoice.amount * math.max(0, math.min(tipPercent or 0, 15)) / 100)
    local total = invoice.amount + tip
    local success, err = Config.Banking.chargePlayer(payer, total, method, invoice.reason)
    if not success then return TriggerClientEvent('fr_faktury:client:paymentResult', payer, false, err or 'Platbu se nepodařilo provést.') end
    pending[id] = nil
    Config.Banking.addToAccount(invoice.accountId, invoice.amount, invoice.reason)
    if tip > 0 then Config.Banking.addCash(invoice.employee, tip) end
    receipt(payer, { business = invoice.business, amount = total, reason = invoice.reason, signature = nameOf(invoice.employee) })
    TriggerClientEvent('fr_faktury:client:paymentResult', payer, true, 'Platba proběhla úspěšně. Účtenka byla vložena do inventáře.')
    TriggerClientEvent('fr_faktury:client:paymentResult', invoice.employee, true, ('Zaplaceno %s%s%s'):format(Config.Currency, invoice.amount, tip > 0 and (' + dýško ' .. Config.Currency .. tip) or ''))
end)

RegisterNetEvent('fr_faktury:server:openDeferred', function(accountId)
    local source, charId = source, identifier(source)
    if not charId then return end
    local invoices = MySQL.query.await('SELECT id, amount, reason, due_at FROM fr_invoices WHERE citizen_id = ? AND account_id = ? AND paid_at IS NULL ORDER BY due_at ASC', { charId, accountId })
    if #invoices == 0 then return TriggerClientEvent('ox_lib:notify', source, { type = 'inform', description = 'Nemáte žádné nezaplacené pohledávky.' }) end
    -- Integrators may open these in their banking UI; payment endpoint remains server-authoritative.
    TriggerClientEvent('ox_lib:notify', source, { type = 'inform', description = ('Nalezeno nezaplacených pohledávek: %s. Připojte UI banky na export GetUnpaidInvoices.'):format(#invoices) })
end)

local function createInvoice(targetSrc, amount, reason, accountId, isImmediate, createdBy, dueDays)
    if isImmediate then
        -- Exports invoked inside a net event retain `source`, which identifies the employee.
        local employee = source
        if not employee or employee <= 0 then return false, 'Okamžitá platba vyžaduje hráče-obsluhu.' end
        return requestImmediate(employee, targetSrc, amount, reason, accountId), 'Platba odeslána zákazníkovi.'
    end
    local targetId = identifier(targetSrc)
    if not targetId or amount < 1 then return false, 'Neplatný hráč nebo částka.' end
    local dueAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + 86400 * (dueDays or Config.Deferred.defaultDays))
    local id = MySQL.insert.await('INSERT INTO fr_invoices (citizen_id, account_id, amount, reason, created_by, due_at) VALUES (?, ?, ?, ?, ?, ?)', { targetId, accountId, math.floor(amount), reason, createdBy or 'MDT', dueAt })
    return id ~= nil, id
end

exports('CreateInvoice', function(targetSrc, amount, reason, accountId, isImmediate)
    return createInvoice(targetSrc, amount, reason, accountId, isImmediate, GetInvokingResource() or 'unknown')
end)

exports('GetUnpaidInvoices', function(source)
    return MySQL.query.await('SELECT id, account_id, amount, reason, due_at FROM fr_invoices WHERE citizen_id = ? AND paid_at IS NULL ORDER BY due_at ASC', { identifier(source) })
end)

CreateThread(function()
    while true do
        Wait(Config.Deferred.collectIntervalMinutes * 60000)
        local overdue = MySQL.query.await('SELECT * FROM fr_invoices WHERE paid_at IS NULL AND due_at <= NOW() AND collected_at IS NULL')
        for _, invoice in ipairs(overdue) do
            local total = math.floor(invoice.amount * (100 + Config.Deferred.penaltyPercent) / 100)
            -- Resolve the currently online player; offline banking support should be implemented in your banking adapter.
            for _, playerId in ipairs(GetPlayers()) do
                if tostring(identifier(tonumber(playerId))) == tostring(invoice.citizen_id) then
                    if Config.Banking.removeBank(tonumber(playerId), total, 'Automatická úhrada faktury') then
                        Config.Banking.addToAccount(invoice.account_id, total, invoice.reason)
                        MySQL.update.await('UPDATE fr_invoices SET paid_at = NOW(), collected_at = NOW(), paid_amount = ? WHERE id = ?', { total, invoice.id })
                    end
                    break
                end
            end
        end
    end
end)

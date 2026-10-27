Config = {}

Config.Currency = '$'
Config.TerminalItem = 'payment_terminal'
Config.ReceiptItem = 'receipt'
Config.MaxDistance = 4.0
Config.Tips = { 0, 10, 15 }

-- Replace the account ids / coordinates with your own businesses.
Config.Registers = {
    { id = 'beanmachine_1', label = 'Bean Machine kasa', coords = vec3(-634.18, 235.40, 81.88), size = vec3(0.55, 0.55, 0.7), rotation = 0, accountId = 'beanmachine' },
}

-- PD/EMS can create deferred invoices through the export/MDT. These are payment points.
Config.InvoiceCounters = {
    { label = 'Mission Row PD - přepážka', coords = vec3(441.87, -981.93, 30.69), accountId = 'police' },
    { label = 'Pillbox EMS - přepážka', coords = vec3(307.20, -595.33, 43.28), accountId = 'ambulance' },
}

Config.Deferred = {
    defaultDays = 7,
    penaltyPercent = 15,
    collectIntervalMinutes = 60
}

-- Banking adapter. Change only these functions if your ox_banking fork uses other exports.
Config.Banking = {
    chargePlayer = function(source, amount, method, reason)
        -- Expected ox_banking API. Return true on success, false and message on failure.
        return exports.ox_banking:RemoveMoney(source, method, amount, reason)
    end,
    addToAccount = function(accountId, amount, reason)
        return exports.ox_banking:AddAccountMoney(accountId, amount, reason)
    end,
    addCash = function(source, amount)
        return exports.ox_inventory:AddItem(source, 'money', amount)
    end,
    removeBank = function(source, amount, reason)
        -- Must permit negative balances for automatic collection when desired.
        return exports.ox_banking:RemoveMoney(source, 'bank', amount, reason, true)
    end
}

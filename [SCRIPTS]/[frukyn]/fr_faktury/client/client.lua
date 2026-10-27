local function notify(data)
    lib.notify(data)
end

local function nearbyPlayer()
    local players = lib.getNearbyPlayers(GetEntityCoords(cache.ped), Config.MaxDistance, false)
    local options = {}
    for i = 1, #players do
        local entry = players[i]
        options[#options + 1] = {
            value = GetPlayerServerId(entry.id),
            label = ('%s [%s]'):format(GetPlayerName(entry.id), GetPlayerServerId(entry.id)),
        }
    end
    if #options == 0 then return nil end

    -- ox_lib's selector visibly points at the selected nearby player.
    local showing = true
    CreateThread(function()
        while showing do
            for i = 1, #players do
                local ped = GetPlayerPed(players[i].id)
                if DoesEntityExist(ped) then
                    local pos = GetEntityCoords(ped)
                    DrawMarker(2, pos.x, pos.y, pos.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.20, 0.20, 0.20, 40, 160, 255, 220, false, true, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end)
    local selected = lib.inputDialog('Vybrat zákazníka', {{ type = 'select', label = 'Hráč', options = options, required = true }})
    showing = false
    return selected and tonumber(selected[1])
end

local function createImmediateInvoice(accountId, label)
    local target = nearbyPlayer()
    if not target then return notify({ type = 'error', description = 'V blízkosti není žádný hráč.' }) end

    local input = lib.inputDialog(label, {
        { type = 'number', label = 'Částka', required = true, min = 1 },
        { type = 'textarea', label = 'Důvod', required = true, max = 180 },
    })
    if not input then return end
    TriggerServerEvent('fr_faktury:server:requestImmediate', target, tonumber(input[1]), input[2], accountId)
end

RegisterNetEvent('fr_faktury:client:openPayment', function(invoice)
    local input = lib.inputDialog('Platba: ' .. invoice.business, {
        { type = 'readonly', label = 'Důvod', default = invoice.reason },
        { type = 'readonly', label = 'K úhradě', default = ('%s%s'):format(Config.Currency, invoice.amount) },
        { type = 'select', label = 'Způsob platby', required = true, options = {
            { value = 'cash', label = 'Hotově' }, { value = 'bank', label = 'Kartou' }
        } },
        { type = 'select', label = 'Dýško obsluze', default = 0, options = {
            { value = 0, label = '0 %' }, { value = 10, label = '10 %' }, { value = 15, label = '15 %' }
        } },
    })
    if not input then
        return TriggerServerEvent('fr_faktury:server:declined', invoice.employee, invoice.id)
    end
    if input[3] == 'bank' then
        RequestAnimDict('anim@heists@keycard@')
        while not HasAnimDictLoaded('anim@heists@keycard@') do Wait(0) end
        TaskPlayAnim(cache.ped, 'anim@heists@keycard@', 'exit', 2.0, 2.0, 1800, 49, 0, false, false, false)
    end
    TriggerServerEvent('fr_faktury:server:payImmediate', invoice.id, input[3], tonumber(input[4]) or 0)
end)

RegisterNetEvent('fr_faktury:client:employeeDeclined', function()
    PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', true)
    notify({ type = 'error', description = 'Zákazník platbu odmítl nebo zavřel nabídku.' })
end)

RegisterNetEvent('fr_faktury:client:paymentResult', function(success, message)
    notify({ type = success and 'success' or 'error', description = message })
end)

CreateThread(function()
    for _, register in ipairs(Config.Registers) do
        exports.ox_target:addBoxZone({
            coords = register.coords, size = register.size, rotation = register.rotation, debug = false,
            options = {{ name = 'fr_register_' .. register.id, icon = 'fa-solid fa-cash-register', label = 'Použít ' .. register.label,
                onSelect = function() createImmediateInvoice(register.accountId, register.label) end }}
        })
    end
    for _, counter in ipairs(Config.InvoiceCounters) do
        exports.ox_target:addSphereZone({
            coords = counter.coords, radius = 1.0,
            options = {{ icon = 'fa-solid fa-file-invoice-dollar', label = 'Zaplatit pohledávku',
                onSelect = function() TriggerServerEvent('fr_faktury:server:openDeferred', counter.accountId) end }}
        })
    end
end)

exports('UseTerminal', function(data, slot)
    createImmediateInvoice(data and data.metadata and data.metadata.accountId or nil, 'Platební terminál')
end)

local ox_inventory = exports.ox_inventory

RegisterNetEvent('rename_item:server:rename', function(slot, newLabel)
    local src = source

    if type(slot) ~= 'number' or type(newLabel) ~= 'string' then
        return
    end

    local cleanLabel = newLabel:gsub('^%s*(.-)%s*$', '%1')
    if #cleanLabel < 1 or #cleanLabel > 32 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Neplatná délka názvu.'
        })
        return
    end

    local item = ox_inventory:GetSlot(src, slot)
    if not item then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Předmět nebyl nalezen.'
        })
        return
    end

    local metadata = item.metadata or {}
    metadata.label = cleanLabel

    ox_inventory:SetMetadata(src, slot, metadata)

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('Předmět byl přejmenován na "%s".'):format(cleanLabel)
    })
end)

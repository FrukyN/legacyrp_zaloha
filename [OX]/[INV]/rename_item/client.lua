local function renameItem(slot)
    if not slot then return end

    local input = lib.inputDialog('Přejmenovat předmět', {
        {
            type = 'input',
            label = 'Nový název',
            description = 'Zadej nový název (max 32 znaků)',
            placeholder = 'Např. Moje oblíbená zbraň',
            icon = 'tag',
            required = true,
            min = 1,
            max = 32
        }
    })

    if not input or not input[1] then return end

    local newLabel = input[1]:gsub('^%s*(.-)%s*$', '%1') -- Ořezání mezer
    if newLabel == '' then return end

    TriggerServerEvent('rename_item:server:rename', slot, newLabel)
end

exports('RenameSlot', renameItem)

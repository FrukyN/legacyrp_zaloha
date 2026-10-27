local function openNotepad(data)
    local metadata = data.metadata or {}
    local currentTitle = metadata.title or 'Prázdný blok'
    local currentContent = metadata.content or ''

    local input = lib.inputDialog('Poznámkový blok: ' .. currentTitle, {
        {
            type = 'input',
            label = 'Název poznámky',
            default = currentTitle ~= 'Prázdný blok' and currentTitle or '',
            placeholder = 'Např. Seznam kódů...',
            max = 32,
            required = true,
            icon = 'heading'
        },
        {
            type = 'textarea',
            label = 'Obsah',
            default = currentContent,
            placeholder = 'Zde napiš své poznámky...',
            max = 1024,
            autosize = true,
            icon = 'pencil'
        }
    })

    if not input then return end

    local newTitle = input[1]
    local newContent = input[2]

    if newTitle ~= currentTitle or newContent ~= currentContent then
        TriggerServerEvent('fr_notepad:saveNote', data.slot, newTitle, newContent)
        lib.notify({
            title = 'Poznámkový blok',
            description = 'Poznámka byla úspěšně uložena.',
            type = 'success',
            position = 'top-right'
        })
    end
end

exports('useNotepad', function(data, slot)
    local itemData = type(slot) == 'table' and slot or data
    if itemData then
        openNotepad(itemData)
    end
end)

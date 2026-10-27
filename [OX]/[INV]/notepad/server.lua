local Ox = exports.ox_inventory

RegisterNetEvent('fr_notepad:saveNote', function(slot, title, content)
    local src = source
    if not slot or type(slot) ~= 'number' then return end

    local item = Ox:GetSlot(src, slot)
    if not item or item.name ~= 'notepad' then return end

    local cleanTitle = tostring(title or 'Bez názvu'):sub(1, 32)
    local cleanContent = tostring(content or ''):sub(1, 1024)

    local preview = cleanContent
    if #preview > 100 then
        preview = preview:sub(1, 97) .. '...'
    end

    local newMetadata = item.metadata or {}
    newMetadata.title = cleanTitle
    newMetadata.content = cleanContent

    if cleanContent ~= '' then
        newMetadata.description = ('**%s**\n%s'):format(cleanTitle, preview)
    else
        newMetadata.description = 'Prázdný blok'
    end

    Ox:SetMetadata(src, slot, newMetadata)
end)

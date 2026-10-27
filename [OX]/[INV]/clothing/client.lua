local CLOTHING_TYPES = {
    ['cloth_mask'] = { label = 'Maska', compType = 'component', id = 1, emptyDrawable = 0, anim = { dict = 'missfbi4', clip = 'takeoff_mask' } },
    ['cloth_glasses'] = { label = 'Brýle', compType = 'prop', id = 1, emptyDrawable = -1, anim = { dict = 'clothingspecs', clip = 'take_off' } },
    ['cloth_helmet'] = { label = 'Pokrývka hlavy', compType = 'prop', id = 0, emptyDrawable = -1, anim = { dict = 'missheistdockssetup1hardhat@', clip = 'takeoff_hardhat' } },
    ['cloth_chain'] = { label = 'Řetízek', compType = 'component', id = 7, emptyDrawable = 0 },
    ['cloth_jacket'] = { label = 'Svršek / Bunda', compType = 'component', id = 11, emptyDrawable = 15, anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' } },
    ['cloth_undershirt'] = { label = 'Triko', compType = 'component', id = 8, emptyDrawable = 15 },
    ['cloth_armor'] = { label = 'Vesta', compType = 'component', id = 9, emptyDrawable = 0 },
    ['cloth_pants'] = { label = 'Kalhoty', compType = 'component', id = 4, emptyDrawable = 14, anim = { dict = 're@construction', clip = 'out_of_breath' } },
    ['cloth_shoes'] = { label = 'Boty', compType = 'component', id = 6, emptyDrawable = 34, anim = { dict = 'random@domestic', clip = 'pickup_low' } },
    ['cloth_watch'] = { label = 'Hodinky', compType = 'prop', id = 6, emptyDrawable = -1 },
    ['cloth_bracelet'] = { label = 'Náramek', compType = 'prop', id = 7, emptyDrawable = -1 },
    ['cloth_bag'] = { label = 'Batoh', compType = 'component', id = 5, emptyDrawable = 0 }
}

local function useClothing(data, slot)
    local metadata = slot.metadata
    local itemName = slot.name
    local config = CLOTHING_TYPES[itemName]

    if not config or not metadata or not metadata.clothData then
        lib.notify({ type = 'error', description = 'Předmět nemá platná data oblečení.' })
        return
    end

    local ped = PlayerPedId()
    local cloth = metadata.clothData

    if config.anim then
        lib.requestAnimDict(config.anim.dict)
        TaskPlayAnim(ped, config.anim.dict, config.anim.clip, 8.0, 8.0, 1200, 49, 0, false, false, false)
        Wait(1000)
    end

    if config.compType == 'component' then
        SetPedComponentVariation(ped, cloth.component_id, cloth.drawable, cloth.texture, cloth.palette or 0)
    elseif config.compType == 'prop' then
        if cloth.drawable == -1 then
            ClearPedProp(ped, cloth.prop_id)
        else
            SetPedPropIndex(ped, cloth.prop_id, cloth.drawable, cloth.texture, true)
        end
    end

    lib.notify({ type = 'success', description = ('Nasadil sis: %s'):format(metadata.label or config.label) })
end
exports('useClothing', useClothing)

local function takeOffClothing(itemName)
    local config = CLOTHING_TYPES[itemName]
    if not config then return end

    local ped = PlayerPedId()
    local clothData = {}
    local currentDrawable = 0
    local currentTexture = 0

    if config.compType == 'component' then
        currentDrawable = GetPedDrawableVariation(ped, config.id)
        currentTexture = GetPedTextureVariation(ped, config.id)

        if currentDrawable == config.emptyDrawable then
            lib.notify({ type = 'error', description = 'Tento kus oblečení na sobě nemáš.' })
            return
        end

        clothData = {
            component_id = config.id,
            drawable = currentDrawable,
            texture = currentTexture,
            palette = GetPedPaletteVariation(ped, config.id)
        }
    elseif config.compType == 'prop' then
        currentDrawable = GetPedPropIndex(ped, config.id)
        currentTexture = GetPedPropTextureIndex(ped, config.id)

        if currentDrawable == -1 or currentDrawable == config.emptyDrawable then
            lib.notify({ type = 'error', description = 'Tento doplněk na sobě nemáš.' })
            return
        end

        clothData = {
            prop_id = config.id,
            drawable = currentDrawable,
            texture = currentTexture
        }
    end

    local input = lib.inputDialog('Sundat ' .. config.label, {
        { type = 'input', label = 'Vlastní název (nebo nech prázdné)', placeholder = config.label }
    })

    local itemLabel = (input and input[1] ~= '') and input[1] or (config.label .. ' #' .. clothData.drawable)

    if config.anim then
        lib.requestAnimDict(config.anim.dict)
        TaskPlayAnim(ped, config.anim.dict, config.anim.clip, 8.0, 8.0, 1000, 49, 0, false, false, false)
        Wait(800)
    end

    if config.compType == 'component' then
        SetPedComponentVariation(ped, config.id, config.emptyDrawable, 0, 0)
    elseif config.compType == 'prop' then
        ClearPedProp(ped, config.id)
    end

    TriggerServerEvent('clothing_item:server:createSingleCloth', itemName, itemLabel, clothData)
end

RegisterCommand('obleceni', function()
    local options = {}

    for itemName, data in pairs(CLOTHING_TYPES) do
        table.insert(options, {
            title = data.label,
            onSelect = function()
                takeOffClothing(itemName)
            end
        })
    end

    lib.registerContext({
        id = 'clothing_menu',
        title = 'Správa oblečení (Svlékání)',
        options = options
    })

    lib.showContext('clothing_menu')
end, false)

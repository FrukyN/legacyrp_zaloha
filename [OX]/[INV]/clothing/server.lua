local ox_inventory = exports.ox_inventory

RegisterNetEvent('clothing_item:server:createSingleCloth', function(itemName, labelName, clothData)
    local src = source

    if not itemName or not clothData or type(clothData) ~= 'table' then return end

    local metadata = {
        label = labelName,
        clothData = clothData,
        description = ('Model: %s | Varianta: %s'):format(clothData.drawable, clothData.texture)
    }

    if ox_inventory:CanCarryItem(src, itemName, 1) then
        ox_inventory:AddItem(src, itemName, 1, metadata)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = ('Sundal jsi %s a uložil do batohu.'):format(labelName)
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Máš plný inventář!'
        })
    end
end)

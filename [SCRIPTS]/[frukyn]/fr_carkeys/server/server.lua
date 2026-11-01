local Ox = require '@ox_core.lib.init'

-- Pomocná funkce pro sjednocení formátu SPZ (odstraní mezery na konci)
local function formatPlate(plate)
    if not plate then return '' end
    return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

-- Kontrola na serveru, zda má hráč u sebe klíč s danou SPZ
local function hasKey(source, plate)
    local cleanPlate = formatPlate(plate)
    local count = exports.ox_inventory:Search(source, 'count', Config.KeyItem, { plate = cleanPlate })
    return count and count > 0
end

-- Přepnutí zámku (voláno klientem)
RegisterNetEvent('fr_carkeys:server:toggleLock', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local plate = formatPlate(GetVehicleNumberPlateText(entity))
    
    -- Ověření podle itemu v inventáři, NE podle ownera auta
    if not hasKey(src, plate) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Od tohoto vozidla nemáš klíče!' })
        return
    end

    local currentLock = Entity(entity).state.locked
    if currentLock == nil then
        currentLock = GetVehicleDoorLockStatus(entity) == 2
    end

    local newLock = not currentLock
    Entity(entity).state:set('locked', newLock, true)
    SetVehicleDoorsLocked(entity, newLock and 2 or 1)

    TriggerClientEvent('fr_carkeys:client:playLockEffect', src, netId, newLock)
end)

-- Odemknutí šperhákem zvenčí
RegisterNetEvent('fr_carkeys:server:unlockLockpick', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    -- Ověření, že má hráč opravdu šperhák
    if exports.ox_inventory:GetItemCount(src, Config.LockpickItem) < 1 then return end

    Entity(entity).state:set('locked', false, true)
    SetVehicleDoorsLocked(entity, 1)
end)

-- Hotwire zevnitř (spojení kabelů)
RegisterNetEvent('fr_carkeys:server:setHotwired', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    Entity(entity).state:set('hotwired', true, true)
end)

-- Zlomení šperháku při selhání
RegisterNetEvent('fr_carkeys:server:breakLockpick', function()
    local src = source
    if math.random(1, 100) <= Config.Lockpick.BreakChance then
        exports.ox_inventory:RemoveItem(src, Config.LockpickItem, 1)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Šperhák se zlomil!' })
    end
end)

-- Kopírování klíče u zámečníka
RegisterNetEvent('fr_carkeys:server:copyKey', function(slot)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)

    if not item or item.name ~= Config.KeyItem or not item.metadata or not item.metadata.plate then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Neplatný klíč!' })
        return
    end

    local money = exports.ox_inventory:GetItemCount(src, 'money')
    if money < Config.Keysmith.Price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Nemáš dostatek hotovosti (%s$)!'):format(Config.Keysmith.Price) })
        return
    end

    exports.ox_inventory:RemoveItem(src, 'money', Config.Keysmith.Price)
    exports.ox_inventory:AddItem(src, Config.KeyItem, 1, {
        plate = item.metadata.plate,
        model = item.metadata.model or 'Vozidlo',
        description = ('SPZ: %s  \nModel: %s'):format(item.metadata.plate, item.metadata.model or 'Neznámý')
    })

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Kopie klíče byla úspěšně vytvořena.' })
end)

-- Export pro dávání klíčů z jiných scriptů (např. autosalon: exports.tvuj_script:GiveCarKey(source, 'ABC 123', 'Octavia'))
local function giveCarKey(source, plate, modelName)
    local cleanPlate = formatPlate(plate)
    local labelModel = modelName or 'Vozidlo'

    return exports.ox_inventory:AddItem(source, Config.KeyItem, 1, {
        plate = cleanPlate,
        model = labelModel,
        description = ('SPZ: %s  \nModel: %s'):format(cleanPlate, labelModel)
    })
end
exports('GiveCarKey', giveCarKey)

-- Testovací příkaz na získání klíče od auta, ve kterém sedíš (pro adminy/testování)
lib.addCommand('givekey', {
    help = 'Vytvoří klíč k vozidlu, ve kterém sedíš',
    restricted = 'group.admin'
}, function(source)
    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Nesedíš v žádném vozidle!' })
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    giveCarKey(source, plate, 'Služební/Test')
    TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = ('Dostal jsi klíč k SPZ: %s'):format(plate) })
end)

-- ========================
-- AUTOMATICKÉ ZAMYKÁNÍ NPC AUT (0.00ms client resmon)
-- ========================
AddEventHandler('entityCreated', function(entity)
    if not Config.NPCLock.Enabled then return end
    if not DoesEntityExist(entity) then return end

    -- 1. Kontrola, zda jde o vozidlo (2 = automobile, bike, boat, atd.)
    if GetEntityType(entity) ~= 2 then return end

    -- 2. Kontrola typu populace (Population Type):
    -- 2, 3 = Zaparkovaná NPC auta
    -- 4, 5 = Jedoucí NPC auta v provozu
    -- 7 = Vozidlo vytvořené scriptem (hráčské auto, admin spawn, job auto) -> IGNOROVAT
    local popType = GetEntityPopulationType(entity)
    if popType == 7 or popType == 0 then return end

    -- 3. Kontrola výjimek (kola atd.)
    local model = GetEntityModel(entity)
    if Config.NPCLock.IgnoreModels[model] then return end

    -- Krátké počkání, než se inicializuje síťová entita a případný NPC řidič uvnitř
    Wait(250)
    if not DoesEntityExist(entity) then return end

    -- Pokud už má auto nastavený stav zámku (např. jiným scriptem), nezasahujeme
    if Entity(entity).state.locked ~= nil then return end

    local driver = GetPedInVehicleSeat(entity, -1)
    local shouldLock = false

    if driver ~= 0 then
        -- Auto v provozu s NPC řidičem
        if math.random(1, 100) <= Config.NPCLock.LockDrivenChance then
            shouldLock = true
        end
    else
        -- Zaparkované prázdné auto
        if math.random(1, 100) <= Config.NPCLock.LockParkedChance then
            shouldLock = true
        end
    end

    if shouldLock then
        Entity(entity).state:set('locked', true, true)
        -- 2 = Zamčeno (hráč nemůže otevřít dveře ani vytáhnout NPC, dokud auto nevypáčí)
        SetVehicleDoorsLocked(entity, 2)
    else
        Entity(entity).state:set('locked', false, true)
        SetVehicleDoorsLocked(entity, 1)
    end
end)
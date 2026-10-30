local function groupDigits(value)
    local left, num, right = tostring(math.floor(tonumber(value) or 0)):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1 '):reverse()) .. right
end

local state = {
    currentShop = nil,
    previewVehicle = nil,
    previewColor = 1,
    inDialog = false,
    testDrive = {
        active = false,
        vehicle = nil,
        endTime = 0,
        returnCoords = nil,
        originalCoords = nil
    }
}

local function notify(msg, msgType)
    lib.notify({ title = 'Vehicle Shop', description = msg, type = msgType or 'inform' })
end

local function giveKeys(plate)
    if not Config.KeysExport.enabled then return end
    local res = Config.KeysExport.resource
    local exp = Config.KeysExport.export
    if res and exp and exports[res] and exports[res][exp] then
        exports[res][exp](plate)
    end
end

local function deletePreviewVehicle()
    if state.previewVehicle and DoesEntityExist(state.previewVehicle) then
        DeleteEntity(state.previewVehicle)
    end
    state.previewVehicle = nil
end

local function setupPreviewCam(shop)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, shop.showroom.camCoords.x, shop.showroom.camCoords.y, shop.showroom.camCoords.z)
    PointCamAtCoord(cam, shop.showroom.previewCoords.x, shop.showroom.previewCoords.y,
        shop.showroom.previewCoords.z + 0.8)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 700, true, false)
    return cam
end

local function spawnLocalPreview(shop, vehicleData)
    deletePreviewVehicle()
    local model = joaat(vehicleData.model)
    lib.requestModel(model, 10000)

    local coords = shop.showroom.previewCoords
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, false, false, true)
    FreezeEntityPosition(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 2)

    state.previewColor = math.random(1, #Config.ColorOptions)

    local colorData = Config.ColorOptions[state.previewColor] or Config.ColorOptions[1]
    SetVehicleColours(vehicle, colorData.primary, colorData.secondary)
    state.previewVehicle = vehicle
    SetModelAsNoLongerNeeded(model)
end

local function buildAccountOptions(accounts)
    local options = {}

    for i = 1, #accounts do
        local account = accounts[i]
        local label = ('%s - $%s'):format(account.label, groupDigits(account.balance))

        if account.isDefault then
            label = ('%s (hlavní)'):format(label)
        end

        options[#options + 1] = {
            value = tostring(account.id),
            label = label
        }
    end

    return options
end

local function selectBankAccount()
    local accounts = lib.callback.await('cwrp_vehicleshop:getBankAccounts', false)

    if not accounts or #accounts == 0 then
        notify('Nemáš žádný účet, ze kterého lze platit.', 'error')
        return nil
    end

    local input = lib.inputDialog('Výběr bankovního účtu', {
        {
            type = 'select',
            label = 'Účet',
            options = buildAccountOptions(accounts),
            default = tostring(accounts[1].id),
            required = true
        }
    })

    if not input then return nil end

    return tonumber(input[1])
end

-- Výběr frakčního účtu pro platbu
local function selectFactionAccount()
    local accounts = lib.callback.await('cwrp_vehicleshop:getFactionAccounts', false)

    if not accounts or #accounts == 0 then
        notify('Nemáš roli Majitele nebo Manažera v žádné frakci s přístupem k financím.', 'error')
        return nil, nil
    end

    local options = {}
    for i = 1, #accounts do
        local acc = accounts[i]
        options[#options + 1] = {
            value = tostring(acc.id),
            label = ('%s - $%s'):format(acc.label, groupDigits(acc.balance))
        }
    end

    local input = lib.inputDialog('Nákup na frakci', {
        {
            type = 'select',
            label = 'Frakční účet',
            options = options,
            default = tostring(accounts[1].id),
            required = true
        }
    })

    if not input then return nil, nil end

    local selectedId = tonumber(input[1])
    local selectedGroup = nil

    for i = 1, #accounts do
        if accounts[i].id == selectedId then
            selectedGroup = accounts[i].group
            break
        end
    end

    return selectedId, selectedGroup
end

local openPurchaseMenu

local function buildVehicleList(shopId, shop, category)
    local options = {}
    local filteredVehicles = {}

    for i = 1, #shop.vehicles do
        local veh = shop.vehicles[i]
        if not category or veh.category == category.key then
            filteredVehicles[#filteredVehicles + 1] = veh
        end
    end

    table.sort(filteredVehicles, function(a, b) return a.price < b.price end)

    for i = 1, #filteredVehicles do
        local veh = filteredVehicles[i]
        options[#options + 1] = {
            title = ('%s - $%s'):format(veh.label, groupDigits(veh.price)),
            description = ('Místa: %d | Odhad rychlosti: %d km/h'):format(veh.seats, veh.estSpeed),
            icon = 'car',
            onSelect = function()
                spawnLocalPreview(shop, veh)

                local text = ('%s | %d míst | %d km/h | $%s'):format(
                    veh.label, veh.seats, veh.estSpeed, groupDigits(veh.price)
                )

                lib.showTextUI(text .. " | [E] Koupit | [Backspace] Zpět | [X] Testovací jízda", {
                    icon = 'car',
                    style = {
                        borderRadius = 10,
                        backgroundColor = '#121212',
                        color = 'white'
                    }
                })

                CreateThread(function()
                    while state.currentShop == shopId and state.previewVehicle do
                        Wait(0)

                        if IsControlJustPressed(0, 38) then
                            openPurchaseMenu(shopId, shop, veh, category.key)
                            lib.hideTextUI()
                            break
                        elseif IsControlJustPressed(0, 177) then
                            lib.hideTextUI()
                            deletePreviewVehicle()
                            lib.showContext(('cwrp_vehicleshop_veh_%s_%s'):format(shopId, category.key))
                            break
                        elseif IsControlJustPressed(0, 73) then
                            lib.hideTextUI()
                            deletePreviewVehicle()
                            lib.callback('cwrp_vehicleshop:requestTestDrive', false, function(response)
                                if not response.ok then
                                    notify(response.message or 'Testovací jízda nebyla povolena.', 'error')
                                    lib.showContext(('cwrp_vehicleshop_veh_%s_%s'):format(shopId, category.key))
                                    return
                                end
                                local spawn = shop.showroom.testDrive and shop.showroom.testDrive.spawnCoords
                                if not spawn then return notify('Shop nemá nastavený spawn pro testovací jízdu.', 'error') end

                                local model = joaat(veh.model)
                                lib.requestModel(model, 10000)
                                local ped = PlayerPedId()
                                local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
                                SetVehicleOnGroundProperly(vehicle)
                                SetPedIntoVehicle(ped, vehicle, -1)
                                SetEntityAsMissionEntity(vehicle, true, true)
                                SetVehicleNumberPlateText(vehicle, 'TESTDRV')
                                local colorData = Config.ColorOptions[state.previewColor] or Config.ColorOptions[1]
                                SetVehicleColours(vehicle, colorData.primary, colorData.secondary)

                                state.testDrive.active = true
                                state.testDrive.vehicle = vehicle
                                state.testDrive.endTime = GetGameTimer() + (Config.TestDriveSeconds * 1000)
                                state.testDrive.returnCoords = shop.showroom.testDrive.returnCoords

                                state.currentShop = nil
                                notify(('Testovací jízda spuštěna na %s sekund.'):format(Config.TestDriveSeconds), 'success')
                            end, { shopId = shopId, model = veh.model })
                            return
                        end
                    end
                end)
            end
        }
    end
    return options
end

local function buildFilteredVehicleList(shopId, shop, filters)
    local options = {}
    local filteredVehicles = {}

    for i = 1, #shop.vehicles do
        local veh = shop.vehicles[i]
        local match = true

        if filters.name and filters.name ~= '' then
            if not string.find(string.lower(veh.label), string.lower(filters.name)) then
                match = false
            end
        end

        if match and filters.type and filters.type ~= 'all' then
            if not veh.filter or string.lower(veh.filter) ~= string.lower(filters.type) then
                match = false
            end
        end

        if match and filters.minPrice then
            if veh.price < filters.minPrice then match = false end
        end

        if match and filters.maxPrice then
            if veh.price > filters.maxPrice then match = false end
        end

        if match then
            filteredVehicles[#filteredVehicles + 1] = veh
        end
    end

    table.sort(filteredVehicles, function(a, b) return a.price < b.price end)

    if #filteredVehicles == 0 then
        return {
            {
                title = 'Žádná vozidla nenalezena',
                description = 'Zkuste upravit parametry hledání.',
                icon = 'circle-xmark',
                onSelect = function()
                    lib.showContext(('cwrp_vehicleshop_cat_%s'):format(shopId))
                end
            }
        }
    end

    for i = 1, #filteredVehicles do
        local veh = filteredVehicles[i]
        options[#options + 1] = {
            title = ('%s - $%s'):format(veh.label, groupDigits(veh.price)),
            description = ('Místa: %d | Odhad rychlosti: %d km/h'):format(veh.seats, veh.estSpeed),
            icon = 'car',
            onSelect = function()
                spawnLocalPreview(shop, veh)

                local text = ('%s | %d míst | %d km/h | $%s'):format(
                    veh.label, veh.seats, veh.estSpeed, groupDigits(veh.price)
                )

                lib.showTextUI(text .. " | [E] Koupit | [Backspace] Zpět | [X] Testovací jízda", {
                    icon = 'car',
                    style = { borderRadius = 10, backgroundColor = '#121212', color = 'white' }
                })

                CreateThread(function()
                    while state.currentShop == shopId and state.previewVehicle do
                        Wait(0)
                        if IsControlJustPressed(0, 38) then
                            openPurchaseMenu(shopId, shop, veh, 'filtered_results')
                            lib.hideTextUI()
                            break
                        elseif IsControlJustPressed(0, 177) then
                            lib.hideTextUI()
                            deletePreviewVehicle()
                            lib.showContext(('cwrp_vehicleshop_veh_%s_filtered_results'):format(shopId))
                            break
                        elseif IsControlJustPressed(0, 73) then
                            lib.hideTextUI()
                            deletePreviewVehicle()
                            lib.callback('cwrp_vehicleshop:requestTestDrive', false, function(response)
                                if not response.ok then 
                                    notify(response.message or 'Testovací jízda nebyla povolena.', 'error') 
                                    lib.showContext(('cwrp_vehicleshop_veh_%s_filtered_results'):format(shopId))
                                    return
                                end
                                local spawn = shop.showroom.testDrive and shop.showroom.testDrive.spawnCoords
                                if not spawn then return notify('Shop nemá nastavený spawn pro test.', 'error') end

                                local model = joaat(veh.model)
                                lib.requestModel(model, 10000)
                                local ped = PlayerPedId()
                                local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
                                SetVehicleOnGroundProperly(vehicle)
                                SetPedIntoVehicle(ped, vehicle, -1)
                                SetEntityAsMissionEntity(vehicle, true, true)
                                SetVehicleNumberPlateText(vehicle, 'TESTDRV')
                                local colorData = Config.ColorOptions[state.previewColor] or Config.ColorOptions[1]
                                SetVehicleColours(vehicle, colorData.primary, colorData.secondary)

                                state.testDrive.active = true
                                state.testDrive.vehicle = vehicle
                                state.testDrive.endTime = GetGameTimer() + (Config.TestDriveSeconds * 1000)
                                state.testDrive.returnCoords = shop.showroom.testDrive.returnCoords
                                
                                state.currentShop = nil 
                                notify(('Testovací jízda spuštěna na %s s.'):format(Config.TestDriveSeconds), 'success')
                            end, { shopId = shopId, model = veh.model })
                            return
                        end
                    end
                end)
            end
        }
    end
    return options
end

function openPurchaseMenu(shopId, shop, veh, categoryKey)
    state.inDialog = true

    local payOptions = {
        { value = 'cash', label = 'Hotovost' },
        { value = 'bank', label = 'Banka (Karta)' }
    }

    if shop.allowSociety then
        payOptions[#payOptions + 1] = { value = 'faction', label = 'Frakční účet (Společnost)' }
    end

    local input = lib.inputDialog(('Koupě: %s'):format(veh.label), {
        {
            type = 'select',
            label = 'Způsob platby',
            options = payOptions,
            default = 'bank',
            required = true
        },
    })
    state.inDialog = false

    local backMenuId = categoryKey == 'filtered_results' 
        and ('cwrp_vehicleshop_veh_%s_filtered_results'):format(shopId)
        or ('cwrp_vehicleshop_veh_%s_%s'):format(shopId, categoryKey)

    if not input then
        lib.showContext(backMenuId)
        return
    end

    local payType = input[1]
    local accountId = nil
    local factionGroup = nil

    if payType == 'bank' then
        state.inDialog = true
        accountId = selectBankAccount()
        state.inDialog = false

        if not accountId then
            lib.showContext(backMenuId)
            return
        end
    elseif payType == 'faction' then
        state.inDialog = true
        accountId, factionGroup = selectFactionAccount()
        state.inDialog = false

        if not accountId or not factionGroup then
            lib.showContext(backMenuId)
            return
        end
    end

    lib.callback('cwrp_vehicleshop:buyVehicle', false, function(response)
        if not response.ok then
            notify(response.message or 'Nákup se nepovedl.', 'error')
            lib.showContext(backMenuId)
            return
        end

        notify(response.message or 'Nákup dokončen.', 'success')

        if response.spawnNow and response.netId then
            local ped = PlayerPedId()
            local vehicle = NetToVeh(response.netId)

            local timeout = 50
            while not DoesEntityExist(vehicle) and timeout > 0 do
                Wait(100)
                vehicle = NetToVeh(response.netId)
                timeout = timeout - 1
            end

            if DoesEntityExist(vehicle) then
                SetPedIntoVehicle(ped, vehicle, -1)
                SetVehicleNumberPlateText(vehicle, response.plate)
                local colorData = Config.ColorOptions[state.previewColor] or Config.ColorOptions[1]
                SetVehicleColours(vehicle, colorData.primary, colorData.secondary)
            end

            giveKeys(response.plate)
        else
            notify('Spawn byl obsazen, vozidlo bylo uloženo do garáže.', 'inform')
        end

        deletePreviewVehicle()
        state.currentShop = nil
    end, {
        shopId = shopId,
        model = veh.model,
        color = state.previewColor,
        payType = payType,
        accountId = accountId,
        factionGroup = factionGroup,
        class = GetVehicleClassFromName(joaat(veh.model))
    })
end

local function openCategoryMenu(shopId)
    local shop = Config.Shops[shopId]
    if not shop then return end

    state.currentShop = shopId
    local options = {}

    local availableFilters = {}
    local filterAdded = {}
    for i = 1, #shop.vehicles do
        local veh = shop.vehicles[i]
        if veh.filter and not filterAdded[veh.filter] then
            filterAdded[veh.filter] = true
            local formatedLabel = string.upper(string.sub(veh.filter, 1, 1)) .. string.sub(veh.filter, 2)
            availableFilters[#availableFilters + 1] = { value = veh.filter, label = formatedLabel }
        end
    end
    table.insert(availableFilters, 1, { value = 'all', label = 'Všechny typy' })

    options[#options + 1] = {
        title = 'Vyhledat / Filtrovat',
        description = 'Filtruj podle typu vozidla, jména nebo ceny',
        icon = 'magnifying-glass',
        iconColor = '#ff4a4a',
        onSelect = function()
            state.inDialog = true
            local input = lib.inputDialog('Vyhledávání vozidel', {
                { type = 'input', label = 'Název (např. Sultan)', placeholder = 'Název hledaného vozidla', icon = 'car' },
                { type = 'select', label = 'Typ (kategorie)', options = availableFilters, default = 'all', icon = 'list' },
                { type = 'number', label = 'Minimální cena ($)', min = 0, icon = 'dollar-sign' },
                { type = 'number', label = 'Maximální cena ($)', min = 0, icon = 'dollar-sign' }
            })
            state.inDialog = false

            if not input then
                lib.showContext(('cwrp_vehicleshop_cat_%s'):format(shopId))
                return
            end

            local searchFilters = {
                name = input[1],
                type = input[2],
                minPrice = input[3],
                maxPrice = input[4]
            }

            lib.registerContext({
                id = ('cwrp_vehicleshop_veh_%s_filtered_results'):format(shopId),
                title = 'Výsledky hledání',
                menu = ('cwrp_vehicleshop_cat_%s'):format(shopId),
                options = buildFilteredVehicleList(shopId, shop, searchFilters),
                onExit = function()
                    if not state.inDialog then
                        deletePreviewVehicle()
                        state.currentShop = nil
                    end
                end
            })
            
            lib.showContext(('cwrp_vehicleshop_veh_%s_filtered_results'):format(shopId))
        end
    }

    for i = 1, #shop.categories do
        local category = shop.categories[i]
        options[#options + 1] = {
            title = category.label,
            icon = 'list',
            onSelect = function()
                lib.registerContext({
                    id = ('cwrp_vehicleshop_veh_%s_%s'):format(shopId, category.key),
                    title = ('%s - %s'):format(shop.label, category.label),
                    menu = ('cwrp_vehicleshop_cat_%s'):format(shopId),
                    options = buildVehicleList(shopId, shop, category),
                    onExit = function()
                        if not state.inDialog then
                            deletePreviewVehicle()
                            state.currentShop = nil
                        end
                    end
                })
                lib.showContext(('cwrp_vehicleshop_veh_%s_%s'):format(shopId, category.key))
            end
        }
    end

    lib.registerContext({
        id = ('cwrp_vehicleshop_cat_%s'):format(shopId),
        title = shop.label,
        options = options,
        onExit = function()
            if not state.inDialog then
                deletePreviewVehicle()
                state.currentShop = nil
            end
        end
    })

    lib.showContext(('cwrp_vehicleshop_cat_%s'):format(shopId))
end

local function createShop(shopId, shop)
    local npcModel = joaat(shop.npc.model)
    lib.requestModel(npcModel, 10000)

    local npc = CreatePed(4, npcModel, shop.npc.coords.x, shop.npc.coords.y, shop.npc.coords.z - 1.0, shop.npc.coords.w,
        false, true)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    if shop.npc.scenario then TaskStartScenarioInPlace(npc, shop.npc.scenario, 0, true) end

    exports.ox_target:addLocalEntity(npc, {
        {
            name = ('cwrp_vehicleshop_%s_open'):format(shopId),
            icon = 'fa-solid fa-car',
            label = ('Otevřít %s'):format(shop.label),
            distance = 2.2,
            onSelect = function()
                local cam = setupPreviewCam(shop)
                openCategoryMenu(shopId)

                CreateThread(function()
                    local pv = shop.showroom.previewCoords
                    local cv = shop.showroom.camCoords
                    local camRadius = #(vec2(pv.x, pv.y) - vec2(cv.x, cv.y))
                    local camAngle = math.deg(math.atan(cv.y - pv.y, cv.x - pv.x))
                    local camHeight = cv.z - pv.z

                    while state.currentShop == shopId do
                        Wait(0)

                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 25, true)
                        DisableControlAction(0, 140, true)
                        DisableControlAction(0, 141, true)
                        DisableControlAction(0, 142, true)
                        DisableControlAction(0, 257, true)

                        if state.previewVehicle and DoesEntityExist(state.previewVehicle) then
                            DisableControlAction(0, 1, true)
                            DisableControlAction(0, 2, true)

                            local mouseX = GetDisabledControlNormal(0, 1)
                            local mouseY = GetDisabledControlNormal(0, 2)

                            if mouseX ~= 0.0 or mouseY ~= 0.0 then
                                camAngle = camAngle - (mouseX * 7.0)
                                camHeight = math.max(-0.5, math.min(3.5, camHeight + (mouseY * 0.6)))

                                local newX = pv.x + math.cos(math.rad(camAngle)) * camRadius
                                local newY = pv.y + math.sin(math.rad(camAngle)) * camRadius

                                SetCamCoord(cam, newX, newY, pv.z + camHeight)
                                PointCamAtCoord(cam, pv.x, pv.y, pv.z + 0.5)
                            end
                        end
                    end

                    RenderScriptCams(false, true, 300, true, false)
                    DestroyCam(cam, false)
                    deletePreviewVehicle()
                end)
            end
        }
    })

    if shop.blip and shop.blip.enabled then
        local blip = AddBlipForCoord(shop.blip.coords.x, shop.blip.coords.y, shop.blip.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale or 0.7)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString("<font face='ChakraPetch-Regular'>"..shop.label.."</font>")
        EndTextCommandSetBlipName(blip)
    end
end

CreateThread(function()
    for shopId, shop in pairs(Config.Shops) do
        createShop(shopId, shop)
    end
end)

RegisterNetEvent('cwrp_vehicleshop:giveKeys', function(plate) giveKeys(plate) end)

CreateThread(function()
    local lastTimeLeft = -1

    while true do
        if state.testDrive.active then
            Wait(0)
            local now = GetGameTimer()
            local timeLeft = math.ceil((state.testDrive.endTime - now) / 1000)

            if timeLeft > 0 then
                if timeLeft ~= lastTimeLeft then
                    lib.showTextUI(('Testovací jízda: %d s \n[Backspace] Ukončit jízdu'):format(timeLeft), {
                        position = 'left-center',
                        icon = 'stopwatch',
                        style = {
                            borderRadius = 5,
                            backgroundColor = '#121212',
                            color = '#ff4a4a'
                        }
                    })
                    lastTimeLeft = timeLeft
                end

                if IsControlJustPressed(0, 177) then
                    state.testDrive.endTime = 0
                end
            else
                lib.hideTextUI()
                local ped = PlayerPedId()

                if state.testDrive.vehicle and DoesEntityExist(state.testDrive.vehicle) then
                    DeleteEntity(state.testDrive.vehicle)
                end

                if state.testDrive.returnCoords then
                    SetEntityCoords(ped, state.testDrive.returnCoords.x, state.testDrive.returnCoords.y,
                        state.testDrive.returnCoords.z, false, false, false, false)
                    SetEntityHeading(ped, state.testDrive.returnCoords.w)
                end

                state.testDrive.active = false
                state.testDrive.vehicle = nil
                state.testDrive.endTime = 0
                lastTimeLeft = -1
                notify('Testovací jízda byla ukončena.', 'inform')
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreviewVehicle()
    lib.hideTextUI()
end)
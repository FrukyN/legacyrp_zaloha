local inside, currentVehicle = nil, 0
local createdBlips = {}

local function notify(description, type)
    lib.notify({ description = description, type = type or 'inform' })
end

local function modelLabel(hash)
    local display = GetDisplayNameFromVehicleModel(hash)
    local label = GetLabelText(display)
    return label ~= 'NULL' and label or display
end

local function vehicleProps(veh)
    local props = {
        model = GetEntityModel(veh),
        plate = GetVehicleNumberPlateText(veh),
        bodyHealth = GetVehicleBodyHealth(veh),
        engineHealth = GetVehicleEngineHealth(veh),
        tankHealth = GetVehiclePetrolTankHealth(veh),
        class = GetVehicleClass(veh),
        mods = {},
        toggleMods = {},
        colors = { GetVehicleColours(veh) },
        extraColors = { GetVehicleExtraColours(veh) },
        livery = GetVehicleLivery(veh),
        wheelType = GetVehicleWheelType(veh),
        windowTint = GetVehicleWindowTint(veh),
        extras = {}
    }

    for i = 0, 49 do
        local m = GetVehicleMod(veh, i)
        if m and m ~= -1 then props.mods[tostring(i)] = m end
        if i == 18 or i == 20 or i == 22 then
            props.toggleMods[tostring(i)] = IsToggleModOn(veh, i)
        end
    end

    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            props.extras[tostring(i)] = IsVehicleExtraTurnedOn(veh, i)
        end
    end

    return props
end

local function applyProps(veh, p)
    p = p or {}
    if p.plate then SetVehicleNumberPlateText(veh, p.plate) end
    if p.bodyHealth then SetVehicleBodyHealth(veh, p.bodyHealth + 0.0) end
    if p.engineHealth then SetVehicleEngineHealth(veh, p.engineHealth + 0.0) end
    if p.tankHealth then SetVehiclePetrolTankHealth(veh, p.tankHealth + 0.0) end
    if p.colors then SetVehicleColours(veh, p.colors[1] or 0, p.colors[2] or 0) end
    SetVehicleModKit(veh, 0)
    if p.mods then
        for k, v in pairs(p.mods) do SetVehicleMod(veh, tonumber(k), v, false) end
    end
    if p.toggleMods then
        for k, v in pairs(p.toggleMods) do ToggleVehicleMod(veh, tonumber(k), v == true) end
    end
    if p.extraColors then SetVehicleExtraColours(veh, p.extraColors[1] or 0, p.extraColors[2] or 0) end
    if p.livery and p.livery >= 0 then SetVehicleLivery(veh, p.livery) end
    if p.wheelType then SetVehicleWheelType(veh, p.wheelType) end
    if p.windowTint then SetVehicleWindowTint(veh, p.windowTint) end
    if p.extras then
        for k, v in pairs(p.extras) do SetVehicleExtra(veh, tonumber(k), v and 0 or 1) end
    end
end

local function openGarage(id, searchQuery)
    local g = Config.Garages[id]
    if not g then return end

    local rows = lib.callback.await('fr_garage:list', false, id) or {}
    local options = {}

    options[#options + 1] = {
        title = 'Hledat vozidlo',
        description = searchQuery and ('Aktivní filtr: "%s" (Klikni pro zrušení / změnu)'):format(searchQuery) or 'Filtrovat auta podle SPZ nebo názvu',
        icon = 'magnifying-glass',
        onSelect = function()
            local dialog = lib.inputDialog(g.label, {
                { type = 'input', label = 'Hledat (jméno, SPZ, model)', default = searchQuery or '' }
            })
            if dialog then
                local val = (dialog[1] or ''):gsub('^%s*(.-)%s*$', '%1')
                openGarage(id, val ~= '' and val:lower() or nil)
            else
                openGarage(id, searchQuery)
            end
        end
    }

    local query = searchQuery and searchQuery:lower() or ''
    local foundAny = false

    for _, v in ipairs(rows) do
        local label = (v.vehicle_name and v.vehicle_name ~= '' and v.vehicle_name or modelLabel(tonumber(v.props.model) or joaat(v.model)))
        local state = v.state == 'impound' and 'V impoundu' or v.state == 'out' and 'Venku' or 'V garáži'
        local searchable = (label .. ' ' .. (v.plate or '') .. ' ' .. (v.model or '') .. ' ' .. (v.vehicle_type or '')):lower()

        if query == '' or searchable:find(query, 1, true) then
            foundAny = true
            local details = ('%.1f km · %.0f%% paliva · %s'):format(tonumber(v.mileage) or 0, tonumber(v.fuel) or 0, state)
            if v.state == 'impound' and v.impound_reason then
                details = details .. ' · ' .. v.impound_reason
            end

            options[#options + 1] = {
                title = ('%s · %s'):format(label, v.plate),
                description = details,
                icon = v.state == 'impound' and 'lock' or v.state == 'out' and 'car-side' or 'square-parking',
                onSelect = function()
                    local actions = {}

                    if v.state == 'stored' then
                        actions[#actions + 1] = {
                            title = 'Vytáhnout vozidlo',
                            icon = 'car',
                            onSelect = function()
                                local result = lib.callback.await('fr_garage:take', false, id, v.id)
                                if not result then return notify('K vozidlu nemáš přístup', 'error') end
                                if result.error == 'blocked' then
                                    return notify(Config.Locale.noSpawn, 'error')
                                elseif result.error then
                                    return notify(result.error == 'out' and 'Vozidlo je již venku.' or Config.Locale.impounded, 'error')
                                end

                                local model = tonumber(result.vehicle.props.model) or joaat(result.vehicle.model)
                                if not IsModelInCdimage(model) then
                                    TriggerServerEvent('fr_garage:spawnFailed', v.id)
                                    return notify('Neplatný model vozidla.', 'error')
                                end

                                lib.requestModel(model)
                                local s = result.spawn
                                local veh = CreateVehicle(model, s.x, s.y, s.z, s.w, true, true)
                                if veh == 0 then
                                    TriggerServerEvent('fr_garage:spawnFailed', v.id)
                                    return
                                end

                                applyProps(veh, result.vehicle.props)
                                SetVehicleNumberPlateText(veh, v.plate)
                                Config.Fuel.set(veh, tonumber(v.fuel) or Config.DefaultFuel, result.vehicle.fuel_type, result.vehicle.dirty_fuel)
                                SetVehicleOnGroundProperly(veh)
                                SetVehicleHasBeenOwnedByPlayer(veh, true)

                                local net = NetworkGetNetworkIdFromEntity(veh)
                                SetNetworkIdCanMigrate(net, true)
                                TriggerServerEvent('fr_garage:spawned', v.id, net)
                                TaskWarpPedIntoVehicle(cache.ped, veh, -1)
                                currentVehicle = veh
                                SetModelAsNoLongerNeeded(model)
                            end
                        }
                    end

                    if v.state == 'impound' then
                        actions[#actions + 1] = {
                            title = 'Vyzvednout z impoundu',
                            icon = 'truck-pickup',
                            onSelect = function()
                                local res = lib.callback.await('fr_garage:releaseImpound', false, v.id)
                                if not res then return end
                                if res.error == 'blocked' then
                                    notify('Vozidlo musí nejdřív odblokovat policie.', 'error')
                                elseif res.error == 'expired' then
                                    notify('Blokace ještě nevypršela.', 'error')
                                elseif res.error == 'money' then
                                    notify(('Potřebuješ $%s.'):format(res.fee), 'error')
                                else
                                    openGarage(id, searchQuery)
                                end
                            end
                        }
                    end

                    actions[#actions + 1] = {
                        title = 'Přejmenovat vozidlo',
                        icon = 'pen',
                        onSelect = function()
                            local d = lib.inputDialog('Přejmenovat', {
                                { type = 'input', label = 'Název', default = v.vehicle_name or '', max = 80 }
                            })
                            if d then
                                lib.callback.await('fr_garage:rename', false, v.id, d[1])
                                openGarage(id, searchQuery)
                            end
                        end
                    }

                    if g.kind == 'faction' and v.canTransfer then
                        actions[#actions + 1] = {
                            title = 'Nastavit minimální hodnost',
                            icon = 'users-gear',
                            onSelect = function()
                                local d = lib.inputDialog('Přístup frakce', {
                                    { type = 'number', label = 'Minimální grade', min = 0, max = 100, default = tonumber(v.job_min_grade) or 0 }
                                })
                                if d then
                                    local ok = lib.alertDialog({
                                        header = 'Přepsat vozidlo frakci?',
                                        content = 'Vozidlo přejde do vlastnictví skupiny ' .. g.group .. '.',
                                        centered = true,
                                        cancel = true
                                    })
                                    if ok == 'confirm' then
                                        lib.callback.await('fr_garage:transfer', false, v.id, g.group, d[1])
                                        openGarage(id, searchQuery)
                                    end
                                end
                            end
                        }
                    end

                    lib.registerContext({
                        id = 'fr_garage_vehicle',
                        title = label .. ' · ' .. v.plate,
                        menu = 'fr_garage_list',
                        options = actions
                    })
                    lib.showContext('fr_garage_vehicle')
                end
            }
        end
    end

    if not foundAny then
        options[#options + 1] = {
            title = 'Žádná vozidla nenalezena',
            icon = 'ban',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'fr_garage_list',
        title = g.label,
        options = options
    })
    lib.showContext('fr_garage_list')
end

-- Vytvoření blipů na mapě
CreateThread(function()
    for id, g in pairs(Config.Garages) do
        if g.blip then
            local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
            SetBlipSprite(blip, g.blip.id or 357)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, g.blip.scale or 0.7)
            SetBlipColour(blip, g.blip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString("<font face='ChakraPetch-Regular'>"..g.label.."</font>")
            EndTextCommandSetBlipName(blip)
            createdBlips[id] = blip
        end
    end
end)

-- Registrace ox_lib bodů (lib.points) s vizuálním markerem
for id, g in pairs(Config.Garages) do
    lib.points.new({
        coords = g.coords,
        distance = 25.0, -- Vzdálenost, ze které se začne vykreslovat marker na zemi
        garageId = id,
        interactDistance = g.radius or 3.5,
        isTextOpen = false,
        onExit = function(self)
            if self.isTextOpen then
                lib.hideTextUI()
                self.isTextOpen = false
            end
        end,
        nearby = function(self)
            -- Vykreslení markeru na zemi (typ 1 = válec / kruh)
            DrawMarker(1, self.coords.x, self.coords.y, self.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, self.interactDistance * 2.0, self.interactDistance * 2.0, 0.8, 45, 140, 235, 150, false, false, 2, false, nil, nil, false)

            local inRange = self.currentDistance <= self.interactDistance
            local veh = GetVehiclePedIsIn(cache.ped, false)

            if inRange then
                if not self.isTextOpen then
                    if veh ~= 0 then
                        lib.showTextUI(('[E] Zaparkovat do %s'):format(g.label), { position = 'left-center' })
                    else
                        lib.showTextUI(('[E] Otevřít %s'):format(g.label), { position = 'left-center' })
                    end
                    self.isTextOpen = true
                end

                if IsControlJustReleased(0, Config.InteractKey) then
                    if veh ~= 0 then
                        local props = vehicleProps(veh)
                        local success = lib.callback.await('fr_garage:store', false, self.garageId, {
                            plate = props.plate,
                            props = props,
                            damage = { body = props.bodyHealth, engine = props.engineHealth },
                            fuel = Config.Fuel.get(veh)
                        })
                        if success then
                            notify('Vozidlo zaparkováno.', 'success')
                            if self.isTextOpen then
                                lib.hideTextUI()
                                self.isTextOpen = false
                            end
                        else
                            notify('Vozidlo nelze zaparkovat.', 'error')
                        end
                    else
                        openGarage(self.garageId)
                    end
                end
            elseif self.isTextOpen then
                lib.hideTextUI()
                self.isTextOpen = false
            end
        end
    })
end

RegisterCommand('frgarage_sharekey', function(_, args)
    local target = tonumber(args[1])
    local plate = args[2]
    if not target or not plate then return notify('Použití: /frgarage_sharekey [server ID] [SPZ]', 'error') end
    TriggerServerEvent('fr_garage:shareKey', target, plate, Config.KeyShareSeconds)
end, false)

RegisterCommand('frgarage_lock', function()
    local veh = GetVehiclePedIsIn(cache.ped, false)
    if veh == 0 then veh = GetClosestVehicle(GetEntityCoords(cache.ped), 8.0, 0, 70) end
    if veh == 0 then return end
    TriggerServerEvent('fr_garage:toggleLock', NetworkGetNetworkIdFromEntity(veh), GetVehicleNumberPlateText(veh))
end, false)

RegisterCommand('frgarage_impound', function()
    local veh = GetClosestVehicle(GetEntityCoords(cache.ped), 8.0, 0, 70)
    if veh == 0 then return notify('V okolí není vozidlo.', 'error') end
    local form = lib.inputDialog('Odtah vozidla', {
        { type = 'input', label = 'Důvod', required = true, max = 255 },
        { type = 'checkbox', label = 'Zablokovat do uvolnění PD' }
    })
    if form then
        TriggerServerEvent('fr_garage:impoundNearby', GetVehicleNumberPlateText(veh), form[1], form[2] == true)
        notify('Požadavek na impound odeslán.')
    end
end, false)

RegisterKeyMapping('frgarage_lock', 'Zamknout / odemknout vozidlo klíčem', 'keyboard', 'L')

RegisterNetEvent('fr_garage:lockResult', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 then return end
    local locked = GetVehicleDoorLockStatus(veh) > 1
    SetVehicleDoorsLocked(veh, locked and 1 or 2)
    PlayVehicleDoorCloseSound(veh, 1)
    notify(locked and 'Vozidlo odemčeno.' or 'Vozidlo zamčeno.')
end)

CreateThread(function()
    while true do
        Wait(Config.MileageInterval)
        local veh = GetVehiclePedIsIn(cache.ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == cache.ped then
            local c = GetEntityCoords(veh)
            TriggerServerEvent('fr_garage:mileage', NetworkGetNetworkIdFromEntity(veh), GetVehicleNumberPlateText(veh), c.x, c.y, c.z)
        end
    end
end)
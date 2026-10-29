local menuOpen = false

local function notify(message, ntype, duration)
    lib.notify({
        title = Config.NotifyTitle,
        description = message,
        type = ntype or 'inform',
        position = Config.NotifyPosition,
        duration = duration,
    })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

local function openMenu()
    if menuOpen then return end
    local payload = lib.callback.await('fr_admin:open', false)
    if not payload then return end -- server už hráči oznámil důvod (chybí oprávnění)

    menuOpen = true
    payload.action = 'openMenu'
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

RegisterCommand(Config.OpenCommand, openMenu, false)
RegisterKeyMapping(Config.OpenCommand, "<font face='ChakraPetch-Regular'>Otevřít admin menu</font>", 'keyboard', Config.OpenKey)


AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)

RegisterNUICallback('closeMenu', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

-- Všechna oznámení z UI jdou přes ox_lib
RegisterNUICallback('notify', function(data, cb)
    notify(tostring(data.message or ''), data.type, tonumber(data.duration))
    cb({})
end)

RegisterNUICallback('requestData', function(_, cb)
    cb(lib.callback.await('fr_admin:requestData', false) or {})
end)

RegisterNUICallback('getPlayerDetail', function(data, cb)
    cb(lib.callback.await('fr_admin:getPlayerDetail', false, data.id) or {})
end)

RegisterNUICallback('executeAction', function(data, cb)
    cb(lib.callback.await('fr_admin:execute', false, data) or { ok = false })
end)

RegisterNUICallback('sendStaffMessage', function(data, cb)
    TriggerServerEvent('fr_admin:server:staffMessage', data.message)
    cb({})
end)

RegisterNetEvent('fr_admin:client:refresh', function()
    if not menuOpen then return end
    local payload = lib.callback.await('fr_admin:requestData', false)
    if payload then
        payload.action = 'updateData'
        SendNUIMessage(payload)
    end
end)

RegisterNetEvent('fr_admin:client:staffChat', function(from, message)
    if menuOpen then
        SendNUIMessage({ action = 'staffChat', from = from, message = message })
    else
        notify(('%s: %s'):format(from, message), 'inform', 6000)
    end
end)

RegisterNetEvent('fr_admin:client:showScreenshot', function(image, name)
    if not menuOpen then
        notify('Screenshot je připravený – otevři admin menu.', 'inform')
        return
    end
    SendNUIMessage({ action = 'screenshot', image = image, name = name })
end)


local noclip, godmode, invisible = false, false, false

local function currentEntity()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    return veh ~= 0 and veh or ped, ped
end

local function stopNoclip()
    noclip = false
    local entity, ped = currentEntity()
    FreezeEntityPosition(entity, false)
    SetEntityCollision(entity, true, true)
    SetEntityVisible(ped, not invisible, false)
    if entity ~= ped then SetVehicleOnGroundProperly(entity) end
end

local function startNoclip()
    noclip = true
    CreateThread(function()
        while noclip do
            local entity, ped = currentEntity()
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, false, false)
            SetEntityVisible(ped, false, false)

            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local forward = vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
            local right = vec3(math.cos(yaw), math.sin(yaw), 0.0)

            local speed = 0.5
            if IsControlPressed(0, 21) then speed = 2.5 end   -- Shift = rychle
            if IsControlPressed(0, 19) then speed = 0.15 end  -- Alt = pomalu

            local move = vec3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + forward end      -- W
            if IsControlPressed(0, 33) then move = move - forward end      -- S
            if IsControlPressed(0, 35) then move = move + right end        -- D
            if IsControlPressed(0, 34) then move = move - right end        -- A
            if IsControlPressed(0, 22) then move = move + vec3(0.0, 0.0, 1.0) end -- Space
            if IsControlPressed(0, 36) then move = move - vec3(0.0, 0.0, 1.0) end -- Ctrl

            local pos = GetEntityCoords(entity) + move * speed
            SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, true, true, true)
            if entity == ped then SetEntityHeading(ped, rot.z) end

            Wait(0)
        end
    end)
end

local function setGodmode(state)
    godmode = state
    SetPlayerInvincible(PlayerId(), state)
    SetEntityInvincible(PlayerPedId(), state)
    if state then
        CreateThread(function()
            while godmode do
                SetPlayerInvincible(PlayerId(), true)
                SetEntityInvincible(PlayerPedId(), true)
                Wait(1000)
            end
        end)
    end
end

local function teleportTo(x, y, z)
    local entity = currentEntity()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(entity, x, y, z, false, false, false, false)
end

local function teleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        return notify('Nemáš nastavený waypoint.', 'error')
    end

    local coords = GetBlipInfoIdCoord(blip)
    local entity = currentEntity()
    FreezeEntityPosition(entity, true)

    local groundZ
    for z = 1000.0, 0.0, -25.0 do
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, z, false, false, false)
        RequestCollisionAtCoord(coords.x, coords.y, z)
        Wait(20)
        local found, height = GetGroundZFor_3dCoord(coords.x, coords.y, z, false)
        if found then groundZ = height break end
    end

    SetEntityCoordsNoOffset(entity, coords.x, coords.y, (groundZ or 50.0) + 1.0, false, false, false)
    FreezeEntityPosition(entity, false)
    notify('Teleportováno na waypoint.', 'success')
end

local function heal()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), 100, false)
        ped = PlayerPedId()
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    for _, eventName in ipairs(Config.ReviveEvents) do
        TriggerEvent(eventName)
    end
    notify('Byl jsi oživen.', 'success')
end

local spectating, spectateReturn = false, nil

local function stopSpectate()
    if not spectating then return end
    spectating = false
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if spectateReturn then
        SetEntityCoords(ped, spectateReturn.x, spectateReturn.y, spectateReturn.z, false, false, false, false)
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, not invisible, false)
    notify('Spectate ukončen.', 'inform')
end

local function startSpectate(p)
    if spectating then return stopSpectate() end
    if menuOpen then closeMenu() end

    local ped = PlayerPedId()
    spectating = true
    spectateReturn = GetEntityCoords(ped)

    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, p.x, p.y, p.z + 10.0, false, false, false, false)

    local deadline = GetGameTimer() + 6000
    local targetPed
    while GetGameTimer() < deadline do
        local player = GetPlayerFromServerId(p.target)
        if player ~= -1 then
            local candidate = GetPlayerPed(player)
            if candidate ~= 0 and candidate ~= ped and DoesEntityExist(candidate) then
                targetPed = candidate
                break
            end
        end
        RequestCollisionAtCoord(p.x, p.y, p.z)
        Wait(100)
    end

    if not targetPed then
        stopSpectate()
        return notify('Hráče se nepodařilo načíst.', 'error')
    end

    NetworkSetInSpectatorMode(true, targetPed)
    notify('Spectate zapnut. Ukončíš ho klávesou BACKSPACE.', 'inform', 6000)

    CreateThread(function()
        while spectating do
            if IsControlJustPressed(0, 177) then stopSpectate() end
            Wait(0)
        end
    end)
end

local function setFuel(veh)
    SetVehicleFuelLevel(veh, 100.0)
    Entity(veh).state:set('fuel', 100.0, true) -- ox_fuel
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(veh, 100.0)
    end
end

local function repair(veh)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
end

local function maxTune(veh)
    SetVehicleModKit(veh, 0)
    for modType = 0, 49 do
        if modType ~= 14 and modType ~= 48 then -- klakson a livery necháme být
            local count = GetNumVehicleMods(veh, modType)
            if count > 0 then SetVehicleMod(veh, modType, count - 1, false) end
        end
    end
    ToggleVehicleMod(veh, 18, true) -- turbo
    ToggleVehicleMod(veh, 22, true) -- xenon
end

local function targetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    return (lib.getClosestVehicle(GetEntityCoords(ped), 5.0, false))
end

local function withVehicle(fn, successMessage)
    local veh = targetVehicle()
    if not veh or veh == 0 then
        return notify('Nejsi ve vozidle ani žádné nemáš do 5 metrů.', 'error')
    end
    fn(veh)
    notify(successMessage, 'success')
end

RegisterNetEvent('fr_admin:client:vehicleOp', function(netId, op)
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end
    if op == 'repair' then repair(veh) elseif op == 'refuel' then setFuel(veh) end
end)


local Handlers = {}

function Handlers.toggleNoclip()
    if noclip then stopNoclip() else startNoclip() end
    notify(noclip and 'Noclip zapnut.' or 'Noclip vypnut.', noclip and 'success' or 'warning')
end

function Handlers.toggleGodmode()
    setGodmode(not godmode)
    notify(godmode and 'Godmode zapnut.' or 'Godmode vypnut.', godmode and 'success' or 'warning')
end

function Handlers.toggleInvis()
    invisible = not invisible
    SetEntityVisible(PlayerPedId(), not invisible and not noclip, false)
    notify(invisible and 'Jsi neviditelný.' or 'Jsi opět viditelný.', invisible and 'success' or 'warning')
end

function Handlers.heal() heal() end
function Handlers.tpWaypoint() teleportToWaypoint() end
function Handlers.teleport(p) teleportTo(p.x + 0.0, p.y + 0.0, p.z + 0.0) end
function Handlers.spectate(p) startSpectate(p) end

function Handlers.freeze(p)
    local entity = currentEntity()
    FreezeEntityPosition(entity, p.state)
    notify(p.state and 'Administrátor tě zamknul na místě.' or 'Administrátor tě odemkl.', p.state and 'warning' or 'success')
end

function Handlers.forceCommand(p) ExecuteCommand(p.command) end

function Handlers.setTime(p) NetworkOverrideClockTime(p.hour, 0, 0) end

function Handlers.repairVeh() withVehicle(repair, 'Vozidlo bylo opraveno a vyčištěno.') end
function Handlers.refuelVeh() withVehicle(setFuel, 'Vozidlo bylo dotankováno.') end
function Handlers.maxTuneVeh() withVehicle(maxTune, 'Vozidlo bylo vytunováno na maximum.') end

function Handlers.deleteVeh()
    withVehicle(function(veh)
        NetworkRequestControlOfEntity(veh)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end, 'Vozidlo bylo smazáno.')
end

RegisterNetEvent('fr_admin:client:do', function(name, payload)
    local handler = Handlers[name]
    if handler then handler(payload or {}) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if noclip then stopNoclip() end
    if godmode then setGodmode(false) end
    if spectating then stopSpectate() end
    if invisible then
        invisible = false
        SetEntityVisible(PlayerPedId(), true, false)
    end
end)


RegisterCommand('fr_noclip', function()
    lib.callback.await('fr_admin:execute', false, { action = 'toggleNoclip' })
end, false)

RegisterKeyMapping('fr_noclip', "<font face='ChakraPetch-Regular'>Noclip</font>", 'keyboard', Config.NoclipKey)

RegisterCommand(Config.ReportCommand, function()
    if menuOpen then return end
    local input = lib.inputDialog('Nahlásit problém', {
        { type = 'input', label = 'Předmět', description = 'Stručně popiš, co se stalo', required = true, max = 200 },
        {
            type = 'select', label = 'Kategorie', required = true, default = 'other',
            options = {
                { value = 'rdm', label = 'RDM / Trolling' },
                { value = 'bug', label = 'Herní bug' },
                { value = 'rulebreak', label = 'Porušení pravidel' },
                { value = 'other', label = 'Ostatní' },
            },
        },
    })
    if not input then return end
    TriggerServerEvent('fr_admin:server:report', { title = input[1], category = input[2] })
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.ReportCommand, 'Nahlásit problém administrátorům')

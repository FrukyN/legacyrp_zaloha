local isOpen = false
local tabletProp = 0

-- Animace a prop tabletu
local function attachTablet()
    local ped = cache.ped
    lib.requestAnimDict('amb@code_human_in_bus_passenger_idles@female@tablet@base')
    lib.requestModel(`prop_cs_tablet`)

    tabletProp = CreateObject(`prop_cs_tablet`, 0, 0, 0, true, true, false)
    AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    TaskPlayAnim(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function detachTablet()
    local ped = cache.ped
    if DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
        tabletProp = 0
    end
    StopAnimTask(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 2.0)
end

-- Otevření MDT
local function openMDT()
    if isOpen then return end

    -- Kontrola položky v inventáři, pokud je vyžadována
    if Config.RequiredItem then
        local count = exports.ox_inventory:GetItemCount(Config.RequiredItem)
        if count < 1 then
            lib.notify({ title = 'MDT', description = 'Nemáš u sebe služební tablet!', type = 'error' })
            return
        end
    end

    local data = lib.callback.await('fr_mdt:server:getDashboardData', false)
    if not data then
        lib.notify({ title = 'MDT', description = 'Nemáš přístup do policejního systému!', type = 'error' })
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    attachTablet()

    SendNUIMessage({
        action = 'open',
        data = data,
        penalCode = PenalCode,
        systemName = Config.SystemName,
        departmentName = Config.DepartmentName,
        roles = Config.Roles,
        tenCodes = Config.TenCodes,
        divisions = Config.Divisions
    })
end

-- Zavření MDT
local function closeMDT()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    detachTablet()
    SendNUIMessage({ action = 'close' })
end

-- Příkaz a klávesa
RegisterCommand(Config.Command, openMDT, false)
lib.addKeybind({
    name = 'open_mdt',
    description = 'Otevřít policejní MDT tablet',
    defaultKey = Config.OpenKeybind,
    onPressed = openMDT
})

-- ========================================================
-- NUI CALLBACKS
-- ========================================================

RegisterNUICallback('close', function(_, cb)
    closeMDT()
    cb(true)
end)

RegisterNUICallback('getDashboard', function(_, cb)
    local data = lib.callback.await('fr_mdt:server:getDashboardData', false)
    cb(data or {})
end)

RegisterNUICallback('searchCitizens', function(data, cb)
    local results = lib.callback.await('fr_mdt:server:searchCitizens', false, data.query)
    cb(results or {})
end)

RegisterNUICallback('getCitizenDetail', function(data, cb)
    local detail = lib.callback.await('fr_mdt:server:getCitizenDetail', false, data.charId)
    cb(detail or {})
end)

RegisterNUICallback('saveCitizenNote', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:saveCitizenNote', false, data.charId, data.note, data.tags)
    cb(ok)
end)

RegisterNUICallback('searchVehicles', function(data, cb)
    local results = lib.callback.await('fr_mdt:server:searchVehicles', false, data.query)
    cb(results or {})
end)

RegisterNUICallback('getVehicleDetail', function(data, cb)
    local detail = lib.callback.await('fr_mdt:server:getVehicleDetail', false, data.plate)
    cb(detail or {})
end)

RegisterNUICallback('setVehicleStolen', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:setVehicleStolen', false, data.plate, data.isStolen)
    cb(ok)
end)

RegisterNUICallback('saveVehicleNote', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:saveVehicleNote', false, data.plate, data.note)
    cb(ok)
end)

RegisterNUICallback('getIncidents', function(data, cb)
    local list = lib.callback.await('fr_mdt:server:getIncidents', false, data.search)
    cb(list or {})
end)

RegisterNUICallback('getIncidentDetail', function(data, cb)
    local detail = lib.callback.await('fr_mdt:server:getIncidentDetail', false, data.id)
    cb(detail or {})
end)

RegisterNUICallback('saveIncident', function(data, cb)
    local id = lib.callback.await('fr_mdt:server:saveIncident', false, data)
    cb(id)
end)

RegisterNUICallback('getWarrants', function(_, cb)
    local warrants = lib.callback.await('fr_mdt:server:getWarrants', false)
    cb(warrants or {})
end)

RegisterNUICallback('createWarrant', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:createWarrant', false, data)
    cb(ok)
end)

RegisterNUICallback('setWarrantStatus', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:setWarrantStatus', false, data.id, data.status)
    cb(ok)
end)

RegisterNUICallback('saveBulletin', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:saveBulletin', false, data.title, data.content, data.isPinned)
    cb(ok)
end)

RegisterNUICallback('deleteBulletin', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:deleteBulletin', false, data.id)
    cb(ok)
end)

RegisterNUICallback('updateCallsign', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:updateCallsign', false, data.callsign)
    cb(ok)
end)

RegisterNUICallback('setUnitStatus', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:setUnitStatus', false, data.status)
    cb(ok)
end)

RegisterNUICallback('setGps', function(data, cb)
    if data and data.x and data.y then
        SetNewWaypoint(data.x, data.y)
        lib.notify({ title = 'MDT GPS', description = 'Navigace byla nastavena na zadané souřadnice.', type = 'success' })
    end
    cb(true)
end)

-- Registr zbraní
RegisterNUICallback('searchWeapons', function(data, cb)
    local results = lib.callback.await('fr_mdt:server:searchWeapons', false, data.query)
    cb(results or {})
end)

RegisterNUICallback('getWeaponDetail', function(data, cb)
    local detail = lib.callback.await('fr_mdt:server:getWeaponDetail', false, data.serial)
    cb(detail or {})
end)

RegisterNUICallback('registerWeapon', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:registerWeapon', false, data)
    cb(ok)
end)

RegisterNUICallback('setWeaponStolen', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:setWeaponStolen', false, data.serial, data.isStolen)
    cb(ok)
end)

RegisterNUICallback('saveWeaponBallistics', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:saveWeaponBallistics', false, data.serial, data.notes)
    cb(ok)
end)

-- Aktivní BOLOs
RegisterNUICallback('getBolos', function(_, cb)
    local bolos = lib.callback.await('fr_mdt:server:getBolos', false)
    cb(bolos or {})
end)

RegisterNUICallback('createBolo', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:createBolo', false, data)
    cb(ok)
end)

RegisterNUICallback('deleteBolo', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:deleteBolo', false, data.id)
    cb(ok)
end)

-- Personál & Administrace rolí
RegisterNUICallback('getStaffList', function(_, cb)
    local staff = lib.callback.await('fr_mdt:server:getStaffList', false)
    cb(staff or {})
end)

RegisterNUICallback('setOfficerRole', function(data, cb)
    local ok = lib.callback.await('fr_mdt:server:setOfficerRole', false, data.charId, data.role)
    cb(ok)
end)

-- Audit Logy
RegisterNUICallback('getAuditLogs', function(data, cb)
    local logs = lib.callback.await('fr_mdt:server:getAuditLogs', false, data.search)
    cb(logs or {})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then
        closeMDT()
    end
end)

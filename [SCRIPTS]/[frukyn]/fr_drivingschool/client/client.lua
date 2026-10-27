local inDriveTest = false
local currentCheckpoint = 1
local driveErrors = 0
local testVehicle = nil
local instructorPed = nil
local schoolPed = nil

CreateThread(function()
    lib.requestModel(Config.PedModel)

    schoolPed = CreatePed(4, GetHashKey(Config.PedModel), Config.Location.x, Config.Location.y, Config.Location.z - 1.0,
        Config.PedHeading, false, true)
    FreezeEntityPosition(schoolPed, true)
    SetEntityInvincible(schoolPed, true)
    SetBlockingOfNonTemporaryEvents(schoolPed, true)

    exports.ox_target:addLocalEntity(schoolPed, {
        {
            name = 'open_autoskola',
            icon = 'fa-solid fa-id-card',
            label = 'Autoškola',
            onSelect = function()
                OpenAutoskolaMenu()
            end
        }
    })
end)

function OpenAutoskolaMenu()
    local ownedLicenses = lib.callback.await('autoskola:getOwnedLicenses', false) or {}
    local accounts = lib.callback.await('autoskola:getBankAccounts', false) or {}

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
        licenses = Config.Licenses,
        owned = ownedLicenses,
        accounts = accounts
    })
end

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('processPayment', function(data, cb)
    local success, message = lib.callback.await('autoskola:payTest', false, data.type, data.method, data.accountId)
    cb({ ok = success, message = message })
end)

RegisterNUICallback('saveTheory', function(data, cb)
    TriggerServerEvent('autoskola:saveTheory', data.type)
    cb('ok')
end)

RegisterNUICallback('startPractical', function(data, cb)
    SetNuiFocus(false, false)
    lib.notify({ title = 'Autoškola', description = 'Zkouška zahájena! Nasedněte do vozidla.', type = 'info' })
    StartDriveTest(data.type)
    cb('ok')
end)

function StartDriveTest(type)
    local routeData = Config.Licenses[type].route
    local vehName = Config.Licenses[type].vehicle

    if not routeData or #routeData == 0 then
        lib.notify({ title = 'Chyba', description = 'Pro tuto skupinu není v configu nastavena žádná trasa!', type = 'error' })
        return
    end

    lib.requestModel(vehName)
    testVehicle = CreateVehicle(GetHashKey(vehName), Config.VehicleSpawn.x, Config.VehicleSpawn.y, Config.VehicleSpawn.z,
        Config.VehicleSpawn.w, true, false)
    TaskWarpPedIntoVehicle(cache.ped, testVehicle, -1)

    lib.requestModel('ig_bankman')
    instructorPed = CreatePedInsideVehicle(testVehicle, 4, GetHashKey('ig_bankman'), 0, true, false)

    inDriveTest = true
    currentCheckpoint = 1
    driveErrors = 0

    CreateThread(function()
        while inDriveTest do
            Wait(0)
            local cp = routeData[currentCheckpoint]

            if not cp then
                break
            end

            local pedCoords = GetEntityCoords(cache.ped)
            local speed = GetEntitySpeed(testVehicle) * 3.6

            if speed > Config.SpeedLimit then
                driveErrors = driveErrors + 1
                lib.notify({ title = 'Instruktor', description = 'Zpomalte! Překračujete rychlost.', type = 'error' })
                Wait(2000)
                if driveErrors >= Config.MaxDriveErrors then
                    FailDriveTest()
                    return
                end
            end

            DrawMarker(1, cp.coords.x, cp.coords.y, cp.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.0, 255, 255, 0, 100,
                false, false, 2, false, nil, nil, false)

            if #(pedCoords - cp.coords) < 3.0 then
                lib.notify({ title = 'Instruktor', description = cp.msg, type = 'info' })
                currentCheckpoint = currentCheckpoint + 1

                if currentCheckpoint > #routeData then
                    PassDriveTest(type)
                    return
                end
            end
        end
    end)
end

function FailDriveTest()
    inDriveTest = false
    lib.notify({ title = 'Autoškola', description = 'Zkouška ukončena pro nekázeň!', type = 'error' })
    CleanupTest()
end

function PassDriveTest(type)
    inDriveTest = false
    lib.notify({ title = 'Autoškola', description = 'Gratulujeme, získali jste řidičský průkaz!', type = 'success' })
    TriggerServerEvent('autoskola:giveLicense', type)
    CleanupTest()
end

function CleanupTest()
    if DoesEntityExist(instructorPed) then DeleteEntity(instructorPed) end
    if DoesEntityExist(testVehicle) then DeleteEntity(testVehicle) end
    SetEntityCoords(cache.ped, Config.Location.x, Config.Location.y, Config.Location.z)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if DoesEntityExist(schoolPed) then
            DeleteEntity(schoolPed)
        end
    end
end)
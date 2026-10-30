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

-- 1. HLAVNÍ MENU AUTOŠKOLY
function OpenAutoskolaMenu()
    local ownedLicenses = lib.callback.await('autoskola:getOwnedLicenses', false) or {}
    local accounts = lib.callback.await('autoskola:getBankAccounts', false) or {}

    local options = {}

    -- Seřazení klíčů, aby byly skupiny v menu vždy ve stejném pořadí (A, B, ...)
    local keys = {}
    for k in pairs(Config.Licenses) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    for _, type in ipairs(keys) do
        local data = Config.Licenses[type]
        local owned = ownedLicenses[type] or { theory = false, practical = false }

        local statusDesc = ''
        local disabled = false
        local icon = 'fa-solid fa-car'
        if type == 'A' then icon = 'fa-solid fa-motorcycle' end

        if owned.theory and owned.practical then
            statusDesc = 'Již vlastníte tento řidičský průkaz'
            disabled = true
            icon = 'fa-solid fa-circle-check'
        elseif owned.theory and not owned.practical then
            statusDesc = ('Teorie splněna | Spustit jízdu (%s $)'):format(data.price)
        else
            statusDesc = ('Zahájit teoretický test (%s $)'):format(data.price)
        end

        options[#options + 1] = {
            title = data.label,
            description = statusDesc,
            icon = icon,
            disabled = disabled,
            onSelect = function()
                OpenPaymentMenu(type, owned, accounts)
            end
        }
    end

    lib.registerContext({
        id = 'autoskola_main',
        title = 'Autoškola',
        options = options
    })

    lib.showContext('autoskola_main')
end

-- 2. VÝBĚR ZPŮSOBU PLATBY
function OpenPaymentMenu(type, owned, accounts)
    local cfg = Config.Licenses[type]
    local stepName = owned.theory and 'Praktická jízda' or 'Teoretický test'

    local options = {
        {
            title = 'Zaplatit hotovostí',
            description = ('Cena: %s $'):format(cfg.price),
            icon = 'fa-solid fa-money-bill-wave',
            onSelect = function()
                ProcessTestPayment(type, 'cash', nil, owned)
            end
        },
        {
            title = 'Zaplatit z bankovního účtu',
            description = ('Cena: %s $'):format(cfg.price),
            icon = 'fa-solid fa-building-columns',
            onSelect = function()
                OpenBankAccountsMenu(type, owned, accounts)
            end
        }
    }

    lib.registerContext({
        id = 'autoskola_payment',
        title = ('%s - %s'):format(cfg.label, stepName),
        menu = 'autoskola_main',
        options = options
    })

    lib.showContext('autoskola_payment')
end

-- 3. VÝBĚR BANKOVNÍHO ÚČTU
function OpenBankAccountsMenu(type, owned, accounts)
    if not accounts or #accounts == 0 then
        lib.notify({ title = 'Autoškola', description = 'Nemáte žádný dostupný bankovní účet.', type = 'error' })
        lib.showContext('autoskola_payment')
        return
    end

    local options = {}
    for i = 1, #accounts do
        local acc = accounts[i]
        options[#options + 1] = {
            title = ('%s (ID: %s)'):format(acc.label or 'Účet', acc.id),
            description = ('Zůstatek: %s $ | Vlastník: %s'):format(acc.balance, acc.owner or 'Neznámý'),
            icon = 'fa-solid fa-credit-card',
            onSelect = function()
                ProcessTestPayment(type, 'bank', acc.id, owned)
            end
        }
    end

    lib.registerContext({
        id = 'autoskola_bank_accounts',
        title = 'Výběr bankovního účtu',
        menu = 'autoskola_payment',
        options = options
    })

    lib.showContext('autoskola_bank_accounts')
end

-- 4. ZPRACOVÁNÍ PLATBY A SPUŠTĚNÍ TESTU
function ProcessTestPayment(type, method, accountId, owned)
    local success, message = lib.callback.await('autoskola:payTest', false, type, method, accountId)

    if not success then
        lib.notify({ title = 'Autoškola', description = message or 'Platba se nezdařila.', type = 'error' })
        return
    end

    lib.notify({ title = 'Autoškola', description = 'Poplatek byl uhrazen.', type = 'success' })

    if owned.theory then
        lib.notify({ title = 'Autoškola', description = 'Zkouška zahájena! Nasedněte do vozidla.', type = 'info' })
        StartDriveTest(type)
    else
        StartTheoryTest(type)
    end
end

-- 5. TEORETICKÝ TEST PŘES OX_LIB CONTEXT
function StartTheoryTest(type)
    local questions = Config.Licenses[type].theory
    if not questions or #questions == 0 then
        TriggerServerEvent('autoskola:saveTheory', type)
        StartDriveTest(type)
        return
    end

    local errors = 0

    local function askQuestion(index)
        if index > #questions then
            -- Hráč dokončil všechny otázky v limitu chyb
            TriggerServerEvent('autoskola:saveTheory', type)
            lib.notify({ title = 'Autoškola', description = 'Úspěšně jste složili teoretickou zkoušku!', type = 'success' })

            local startDrive = lib.alertDialog({
                header = 'Teorie úspěšně splněna!',
                content = 'Přejít rovnou k praktické jízdě?',
                centered = true,
                cancel = true,
                labels = {
                    confirm = 'Zahájit jízdu',
                    cancel = 'Později'
                }
            })

            if startDrive == 'confirm' then
                lib.notify({ title = 'Autoškola', description = 'Zkouška zahájena! Nasedněte do vozidla.', type = 'info' })
                StartDriveTest(type)
            end
            return
        end

        local q = questions[index]
        local options = {
            {
                title = q.question,
                description = ('Otázka %d z %d | Chyby: %d/%d'):format(index, #questions, errors, Config.MaxTheoryErrors),
                icon = 'fa-solid fa-circle-question',
                readOnly = true
            }
        }

        for i = 1, #q.answers do
            local answerText = q.answers[i]
            local isCorrect = ((i - 1) == q.correct) -- V configu jsou správné odpovědi indexované od 0

            options[#options + 1] = {
                title = answerText,
                icon = 'fa-regular fa-circle',
                onSelect = function()
                    if not isCorrect then
                        errors = errors + 1
                        lib.notify({
                            title = 'Autoškola - Teorie',
                            description = ('Špatná odpověď! (%d/%d chyb)'):format(errors, Config.MaxTheoryErrors),
                            type = 'error'
                        })

                        if errors >= Config.MaxTheoryErrors then
                            lib.notify({
                                title = 'Autoškola',
                                description = 'Překročili jste maximální počet chyb. Zkouška byla ukončena.',
                                type = 'error'
                            })
                            return
                        end
                    else
                        lib.notify({
                            title = 'Autoškola - Teorie',
                            description = 'Správná odpověď!',
                            type = 'success'
                        })
                    end

                    askQuestion(index + 1)
                end
            }
        end

        lib.registerContext({
            id = 'autoskola_theory_question',
            title = ('Teoretický test - Skupina %s'):format(type),
            canClose = false,
            options = options
        })

        lib.showContext('autoskola_theory_question')
    end

    askQuestion(1)
end

-- 6. PRAKTICKÁ JÍZDA
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
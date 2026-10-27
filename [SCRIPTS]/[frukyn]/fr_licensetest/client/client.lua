local spawnedPeds = {}

local function groupDigits(value)
    local left, num, right = tostring(math.floor(tonumber(value) or 0)):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1 '):reverse()) .. right
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
    local accounts = lib.callback.await('es_license_test:getBankAccounts', false)

    if not accounts or #accounts == 0 then
        lib.notify({ title = 'Chyba', description = 'Nemáš žádný účet, ze kterého lze platit.', type = 'error' })
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

local function startLicenseTest(testId, testData)
    local pool = {}
    for i, q in ipairs(testData.questions) do pool[i] = q end

    local selectedQuestions = {}
    local dialogElements = {}
    local maxQ = math.min(testData.maxQuestions, #pool)

    for i = 1, maxQ do
        local idx = math.random(1, #pool)
        local q = pool[idx]
        table.insert(selectedQuestions, q)

        table.insert(dialogElements, {
            type = 'select',
            label = ('%s. %s'):format(i, q.question),
            options = q.options,
            required = true
        })
        table.remove(pool, idx)
    end

    local input = lib.inputDialog(testData.label .. ' - Teoretický test', dialogElements)

    if not input then
        lib.notify({ title = 'Test zrušen', description = 'Odešel jsi od testu.', type = 'error' })
        TriggerServerEvent('es_license_test:cancelTest')
        return
    end

    local correctAnswers = 0
    for i, q in ipairs(selectedQuestions) do
        if input[i] == q.correct then
            correctAnswers = correctAnswers + 1
        end
    end

    TriggerServerEvent('es_license_test:evaluate', testId, correctAnswers, maxQ)
end

local function openLicenseMenu(testId, testData)
    lib.registerContext({
        id = 'license_main_menu',
        title = testData.label,
        options = {
            {
                title = 'Spustit teoretický test',
                description = ('Cena: $%s | Požadováno: %s/%s správně'):format(groupDigits(testData.price), testData.minCorrect,
                    testData.maxQuestions),
                icon = 'file-signature',
                arrow = true,
                onSelect = function()
                    local input = lib.inputDialog(('Platba: %s'):format(testData.label), {
                        {
                            type = 'select',
                            label = 'Způsob platby',
                            options = {
                                { value = 'cash', label = 'Hotovost' },
                                { value = 'bank', label = 'Banka (Karta)' }
                            },
                            default = 'bank',
                            required = true
                        }
                    })

                    if not input then return end

                    local method = input[1]
                    local accountId = nil

                    if method == 'bank' then
                        accountId = selectBankAccount()
                        if not accountId then return end
                    end

                    TriggerServerEvent('es_license_test:startTest', testId, method, accountId)
                end
            }
        }
    })
    lib.showContext('license_main_menu')
end

CreateThread(function()
    for testId, data in pairs(Config.Tests) do
        local zone = lib.zones.box({
            coords = data.coords,
            size = vec3(30.0, 30.0, 10.0),
            debug = false,
            onEnter = function()
                lib.requestModel(data.ped)
                local ped = CreatePed(4, joaat(data.ped), data.coords.x, data.coords.y, data.coords.z - 1.0, data
                .heading, false, false)
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)

                spawnedPeds[testId] = ped

                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = 'license_ped_' .. testId,
                        icon = 'fas fa-id-card',
                        label = 'Promluvit si o: ' .. data.label,
                        onSelect = function()
                            openLicenseMenu(testId, data)
                        end
                    }
                })
            end,
            onExit = function()
                if spawnedPeds[testId] and DoesEntityExist(spawnedPeds[testId]) then
                    exports.ox_target:removeLocalEntity(spawnedPeds[testId])
                    DeleteEntity(spawnedPeds[testId])
                    spawnedPeds[testId] = nil
                end
            end
        })
    end
end)

RegisterNetEvent('es_license_test:cl_startTest', function(testId)
    startLicenseTest(testId, Config.Tests[testId])
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
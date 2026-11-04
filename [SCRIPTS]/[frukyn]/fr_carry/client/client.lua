local carrying = false
local beingCarried = false
local carryThreadRunning = false

local anims = {
    carrier = {
        dict = 'missfinale_c2mcs_1',
        clip = 'fin_c2_mcs_1_camman',
        flag = 49
    },
    carried = {
        dict = 'nm',
        clip = 'firemans_carry',
        flag = 33
    }
}

-- Funkce pro vyžádání nebo ukončení nošení
local function requestCarry()
    -- Pokud už někoho nese nebo je nesen, požádá server o ukončení
    if carrying or beingCarried then
        TriggerServerEvent('fr_carry:server:stop')
        return
    end

    if cache.vehicle then
        return lib.notify({ title = 'Carry', description = 'Nemůžeš nosit hráče v autě.', type = 'error' })
    end

    if LocalPlayer.state.isDead then
        return lib.notify({ title = 'Carry', description = 'Nemůžeš toto dělat, když jsi mrtvý.', type = 'error' })
    end

    local coords = GetEntityCoords(cache.ped)
    local targetPed, targetCoords = lib.getClosestPlayer(coords, 3.0, false)

    if not targetPed then
        return lib.notify({ title = 'Carry', description = 'Žádný hráč v blízkosti.', type = 'error' })
    end

    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
    TriggerServerEvent('fr_carry:server:request', targetServerId)
end

RegisterCommand('carry', function()
    requestCarry()
end, false)

-- Callback pro příjemce žádosti (ox_lib alertDialog)
lib.callback.register('fr_carry:client:askPermission', function(requesterName)
    if beingCarried or carrying or cache.vehicle or LocalPlayer.state.isDead then
        return false
    end

    local alert = lib.alertDialog({
        header = 'Žádost o přenesení',
        content = ('Hráč **%s** tě chce vzít na záda. Souhlasíš?'):format(requesterName),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Souhlasit',
            cancel = 'Odmítnout'
        }
    })

    return alert == 'confirm'
end)

-- Smyčka pro hráče, který NESE (zákaz běhu, skákání a kontrola animace)
local function startCarrierLoop()
    if carryThreadRunning then return end
    carryThreadRunning = true

    lib.RequestAnimDict(anims.carrier.dict)
    lib.showTextUI('[X] - Pustit hráče')

    CreateThread(function()
        while carrying do
            Wait(0)

            -- Zákaz sprintu, skákání, útoku a nastupování do aut
            DisableControlAction(0, 21, true) -- INPUT_SPRINT (Shift)
            DisableControlAction(0, 22, true) -- INPUT_JUMP (Space)
            DisableControlAction(0, 24, true) -- INPUT_ATTACK
            DisableControlAction(0, 25, true) -- INPUT_AIM
            DisableControlAction(0, 23, true) -- INPUT_ENTER (F)

            -- Udržování animace
            if not IsEntityPlayingAnim(cache.ped, anims.carrier.dict, anims.carrier.clip, 3) then
                TaskPlayAnim(cache.ped, anims.carrier.dict, anims.carrier.clip, 8.0, -8.0, -1, anims.carrier.flag, 0, false, false, false)
            end

            -- Puštění klávesou X (INPUT_VEH_DUCK - 73) nebo pokud hráč zemře / sedne do auta
            if IsControlJustPressed(0, 73) or LocalPlayer.state.isDead or cache.vehicle then
                TriggerServerEvent('fr_carry:server:stop')
                Wait(500)
            end
        end

        lib.hideTextUI()
        ClearPedSecondaryTask(cache.ped)
        RemoveAnimDict(anims.carrier.dict)
        carryThreadRunning = false
    end)
end

-- Smyčka pro hráče, který JE NESEN (attach + animace)
local function startCarriedLoop(carrierServerId)
    if carryThreadRunning then return end
    carryThreadRunning = true

    local carrierPlayer = GetPlayerFromServerId(carrierServerId)
    if carrierPlayer == -1 then
        carryThreadRunning = false
        return
    end

    local carrierPed = GetPlayerPed(carrierPlayer)
    lib.RequestAnimDict(anims.carried.dict)

    -- Připojení na záda hráče
    AttachEntityToEntity(cache.ped, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
    lib.showTextUI('[X] - Seskočit ze zad')

    CreateThread(function()
        while beingCarried do
            Wait(0)

            -- Zákaz většiny akcí během nesení
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 23, true)

            if not IsEntityPlayingAnim(cache.ped, anims.carried.dict, anims.carried.clip, 3) then
                TaskPlayAnim(cache.ped, anims.carried.dict, anims.carried.clip, 8.0, -8.0, -1, anims.carried.flag, 0, false, false, false)
            end

            -- Možnost seskočit ze zad klávesou X
            if IsControlJustPressed(0, 73) then
                TriggerServerEvent('fr_carry:server:stop')
                Wait(500)
            end
        end

        lib.hideTextUI()
        DetachEntity(cache.ped, true, false)
        ClearPedTasksImmediately(cache.ped)
        RemoveAnimDict(anims.carried.dict)
        carryThreadRunning = false
    end)
end

-- Sledování State Bagů pro toho, kdo NESE
AddStateBagChangeHandler('carryingTarget', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        carrying = true
        startCarrierLoop()
    else
        carrying = false
    end
end)

-- Sledování State Bagů pro toho, kdo JE NESEN
AddStateBagChangeHandler('carriedBy', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        beingCarried = true
        startCarriedLoop(value)
    else
        beingCarried = false
    end
end)

-- Ošetření při zastavení resource
AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end
    if carrying or beingCarried then
        lib.hideTextUI()
        DetachEntity(cache.ped, true, false)
        ClearPedTasks(cache.ped)
    end
end)
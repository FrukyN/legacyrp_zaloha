local isDead = false
local deathTimer = 0
local canRespawn = false

-- Animace pro stav bezvědomí
local deadAnimDict = 'combat@damage@writhe'
local deadAnim = 'writhe_loop'

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Hlavní funkce pro spuštění stavu smrti
local function startDeathLoop()
    if isDead then return end
    isDead = true
    deathTimer = Config.BleedoutTimer
    canRespawn = false

    -- Efekt obrazovky a zvuk
    StartScreenEffect('DeathFailOut', 0, true)
    PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)

    loadAnimDict(deadAnimDict)

    CreateThread(function()
        while isDead do
            Wait(0)
            local ped = cache.ped

            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- Look Left/Right
            EnableControlAction(0, 2, true)   -- Look Up/Down
            EnableControlAction(0, 249, true) -- Push to Talk (N)

            if not IsEntityPlayingAnim(ped, deadAnimDict, deadAnim, 3) then
                TaskPlayAnim(ped, deadAnimDict, deadAnim, 8.0, -8.0, -1, 33, 0, false, false, false)
            end

            if canRespawn and IsDisabledControlJustPressed(0, 38) then -- Klávesa E
                local alert = lib.alertDialog({
                    header = 'Převoz do nemocnice',
                    content = 'Opravdu se chceš nechat převézt do nemocnice? Můžeš přijít o věci u sebe.',
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    TriggerServerEvent('fr_death:server:respawnInHospital')
                end
            end
        end
    end)

    CreateThread(function()
        local earlyTime = Config.BleedoutTimer - Config.EarlyRespawnTimer

        while isDead and deathTimer > 0 do
            Wait(1000)
            deathTimer -= 1

            if deathTimer <= earlyTime then
                canRespawn = true
                lib.showTextUI(('[E] Převoz do nemocnice (%s s do vykrvácení)'):format(deathTimer), {
                    position = "bottom-center",
                    icon = 'skull',
                    style = { backgroundColor = '#8a1c1c', color = 'white' }
                })
            else
                lib.showTextUI(('Jsi v bezvědomí (%s s)'):format(deathTimer), {
                    position = "bottom-center",
                    icon = 'heart-pulse'
                })
            end
        end

        if isDead and deathTimer <= 0 then
            TriggerServerEvent('fr_death:server:respawnInHospital')
        end
    end)
end

-- Funkce pro oživení hráče
local function revivePlayer(coords, heading)
    isDead = false
    canRespawn = false
    lib.hideTextUI()
    StopScreenEffect('DeathFailOut')

    local ped = cache.ped
    local pos = coords or GetEntityCoords(ped)
    local head = heading or GetEntityHeading(ped)

    DoScreenFadeOut(500)
    Wait(500)

    -- Samotný GTA V resurekce ped-a
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, head, 0, false)
    SetEntityInvincible(ped, false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))

    Wait(500)
    DoScreenFadeIn(500)

    lib.notify({
        title = 'Zdravotní stav',
        description = 'Byl jsi úspěšně ošetřen.',
        type = 'success'
    })
end

-- Zachycení smrti přes nativní GTA event
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim, attacker, victimDied = data[1], data[2], data[4]
        if victim == cache.ped and victimDied and not isDead then
            local ped = cache.ped
            local coords = GetEntityCoords(ped)

            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), 0, false)
            SetEntityInvincible(ped, true)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))

            TriggerServerEvent('fr_death:server:setDeathStatus', true)
            startDeathLoop()
        end
    end
end)

AddEventHandler('ox:playerLoaded', function()
    Wait(1000)
    local deadState = LocalPlayer.state.isDead
    if deadState then
        SetEntityInvincible(cache.ped, true)
        startDeathLoop()
        lib.notify({
            title = 'Bezvědomí',
            description = 'Odpojil ses v bezvědomí, tvůj stav trvá.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('fr_death:client:revive', function(coords, heading)
    revivePlayer(coords, heading)
end)

exports('isDead', function()
    return isDead
end)
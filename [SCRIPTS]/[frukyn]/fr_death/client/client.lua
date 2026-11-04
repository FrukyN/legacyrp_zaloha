local isDead = false
local deathTimer = 0
local canRespawn = false

-- Hlavní funkce pro spuštění stavu smrti
local function startDeathLoop()
    if isDead then return end
    isDead = true
    deathTimer = Config.BleedoutTimer
    canRespawn = false

    -- 1. Zablokování a okamžité zavření ox_inventory
    LocalPlayer.state:set('invBusy', true, false)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:closeInventory()
    end

    -- Efekt obrazovky a zvuk
    StartScreenEffect('DeathFailOut', 0, true)
    PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)

    -- Vlákno pro ragdoll, kameru a blokaci kláves (běží jen při smrti)
    CreateThread(function()
        while isDead do
            Wait(0)
            local ped = cache.ped

            -- 2. Vynucení 3rd person kamery (pokud je ve First Person = 4, přepne na střední 3rd person = 2)
            if GetFollowPedCamViewMode() == 4 then
                SetFollowPedCamViewMode(2)
            end
            if IsPedInAnyVehicle(ped, false) and GetFollowVehicleCamViewMode() == 4 then
                SetFollowVehicleCamViewMode(2)
            end

            -- 3. Zakázání všech ovládacích prvků (včetně V pro změnu kamery a F2/Tab pro inventář)
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- Pohyb kamery doleva/doprava (myš)
            EnableControlAction(0, 2, true)   -- Pohyb kamery nahoru/dolů (myš)
            EnableControlAction(0, 249, true) -- Push to Talk (N)

            -- Explicitní pojistka proti změně kamery a otevření inventáře
            DisableControlAction(0, 0, true)   -- V (Next Camera)
            DisableControlAction(0, 289, true) -- F2 (Inventář)
            DisableControlAction(0, 37, true)  -- TAB (Weapon Wheel / Inventář)

            -- 4. Udržování postavy v čistém ragdollu (mimo vozidlo)
            if not IsPedInAnyVehicle(ped, false) then
                SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
            end

            -- Kontrola stisku klávesy E pro respawn
            if canRespawn and IsDisabledControlJustPressed(0, 38) then -- Klávesa E
                local alert = lib.alertDialog({
                    header = 'Převoz do nemocnice',
                    content = 'Opravdu se chceš nechat převézt do nemocnice? Můžeš přijít o věci u sebe.',
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' and isDead then
                    TriggerServerEvent('fr_death:server:respawnInHospital')
                end
            end
        end
    end)

    -- Vlákno pro odpočet času (běží 1x za sekundu = 0.00ms zátěž)
    CreateThread(function()
        local earlyTime = Config.BleedoutTimer - Config.EarlyRespawnTimer

        while isDead and deathTimer > 0 do
            Wait(1000)
            
            -- OPRAVA: Pokud byl hráč oživen během čekání Wait(1000), okamžitě ukončíme cyklus a nezobrazíme TextUI!
            if not isDead then
                lib.hideTextUI()
                return
            end

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

        -- Pokud vyprší čas úplně, vynutíme respawn v nemocnici
        if isDead and deathTimer <= 0 then
            lib.hideTextUI()
            TriggerServerEvent('fr_death:server:respawnInHospital')
        end
    end)
end

-- Funkce pro oživení hráče
local function revivePlayer(coords, heading)
    isDead = false
    canRespawn = false
    deathTimer = 0

    -- Skrytí TextUI a případného otevřeného dialogu
    lib.hideTextUI()
    lib.closeAlertDialog()
    StopScreenEffect('DeathFailOut')

    -- Odblokování inventáře
    LocalPlayer.state:set('invBusy', false, false)

    local ped = cache.ped
    local pos = coords or GetEntityCoords(ped)
    local head = heading or GetEntityHeading(ped)

    DoScreenFadeOut(500)
    Wait(500)

    -- Pojistka: Znovu skryjeme TextUI, kdyby doběhlo vlákno těsně při stmívání
    lib.hideTextUI()

    -- Postavení postavy z ragdollu a obnova zdraví
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, head, true, false)
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
            local inVeh = IsPedInAnyVehicle(ped, false)
            local veh, seat = nil, nil

            if inVeh then
                veh = GetVehiclePedIsIn(ped, false)
                for i = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                    if GetPedInVehicleSeat(veh, i) == ped then
                        seat = i
                        break
                    end
                end
            end

            -- Oživení pro engine (zruší GTA Wasted screen) a okamžitý přechod do ragdollu
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetEntityInvincible(ped, true)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))

            if inVeh and veh and seat then
                SetPedIntoVehicle(ped, veh, seat)
            end

            TriggerServerEvent('fr_death:server:setDeathStatus', true)
            startDeathLoop()
        end
    end
end)

-- Načtení postavy přes ox_core (Anti-CombatLog)
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

-- Event ze serveru pro oživení
RegisterNetEvent('fr_death:client:revive', function(coords, heading)
    revivePlayer(coords, heading)
end)

-- Dodatečná pojistka: Sledování změny StateBagu isDead ze serveru
AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value == false and isDead then
        revivePlayer()
    end
end)

-- Exporty pro ostatní skripty
exports('isDead', function()
    return isDead
end)
local currentSkills = {}
local isLoaded = false

-- Funkce, která reálně propíše hodnoty do fyziky postavy
local function applySkillEffects()
    if not isLoaded then return end
    local ped = cache.ped

    -- 1. Nastavení nativních GTA V statů (0 - 100)
    for skillName, cfg in pairs(Config.Skills) do
        local val = math.floor(currentSkills[skillName] or 0)
        if cfg.stat then
            StatSetInt(joaat(cfg.stat), val, true)
        end
    end

    -- 2. Reálný efekt: Stamina -> Rychlejší běh a plavání (max +15 % rychlosti na 100 %)
    local stamina = currentSkills.stamina or 0.0
    local speedMult = 1.0 + ((stamina / 100.0) * 0.15)
    SetRunSprintMultiplierForPlayer(cache.playerId, speedMult)
    SetSwimMultiplierForPlayer(cache.playerId, 1.0 + ((stamina / 100.0) * 0.10))

    -- 3. Reálný efekt: Kapacita plic -> Čas pod vodou (základ 10s + až 30s navíc na 100 %)
    local lungs = currentSkills.lung_capacity or 0.0
    local underwaterTime = 10.0 + ((lungs / 100.0) * 30.0)
    SetPedMaxTimeUnderwater(ped, underwaterTime)

    -- 4. Reálný efekt: Střelba -> Přesnost
    local shooting = currentSkills.shooting or 0.0
    SetPedAccuracy(ped, math.floor(shooting))
end

-- Přidání skillu lokálně + odeslání na server
local function addSkill(skillName, customGain)
    if not isLoaded or not Config.Skills[skillName] then return end
    local current = currentSkills[skillName] or 0.0
    if current >= 100.0 then return end

    local gain = customGain or Config.Skills[skillName].gain
    local oldFloor = math.floor(current)
    local newVal = math.min(100.0, current + gain)
    
    currentSkills[skillName] = newVal
    applySkillEffects()

    -- Notifikace pouze při dosažení nového celého procenta (1%, 2%, atd.)
    if math.floor(newVal) > oldFloor then
        lib.notify({
            title = 'Zlepšení dovednosti',
            description = ('%s zvýšena na %d%%'):format(Config.Skills[skillName].label, math.floor(newVal)),
            type = 'success',
            icon = Config.Skills[skillName].icon
        })
    end

    TriggerServerEvent('fr_skills:server:addSkill', skillName, gain)
end

-- Načtení dat ze serveru
RegisterNetEvent('fr_skills:client:setSkills', function(skills)
    currentSkills = skills
    isLoaded = true
    applySkillEffects()
end)

-- Zajištění, že po změně peda (respawn, změna skinu) zůstanou modifikátory aktivní
lib.onCache('ped', function()
    if isLoaded then
        Wait(500)
        applySkillEffects()
    end
end)

-- Otevření ox_lib menu
local function openSkillMenu()
    if not isLoaded then return end
    local options = {}

    for k, cfg in pairs(Config.Skills) do
        local val = currentSkills[k] or 0.0
        local rounded = math.floor(val * 10) / 10

        local color = 'red'
        if val >= 75 then color = 'green'
        elseif val >= 35 then color = 'yellow' end

        options[#options + 1] = {
            title = ('%s - %s%%'):format(cfg.label, rounded),
            description = cfg.description,
            icon = cfg.icon,
            progress = math.floor(val),
            colorScheme = color,
            metadata = {
                { label = 'Přesná hodnota', value = rounded .. ' / 100%' }
            }
        }
    end

    lib.registerContext({
        id = 'fr_skills_menu',
        title = 'Dovednosti postavy',
        options = options
    })

    lib.showContext('fr_skills_menu')
end

-- Příkaz a klávesová zkratka
RegisterCommand(Config.Command, openSkillMenu, false)
if Config.Keybind then
    lib.addKeybind({
        name = 'open_fr_skills',
        description = 'Otevřít menu dovedností',
        defaultKey = Config.Keybind,
        onPressed = openSkillMenu
    })
end

-- HLAVNÍ SMYČKA PRO POHYB (2500ms interval -> 0.00ms resmon)
CreateThread(function()
    while true do
        Wait(2500)
        if isLoaded then
            local ped = cache.ped

            -- Sprintování nebo plavání -> Stamina
            if IsPedSprinting(ped) or (IsPedSwimming(ped) and GetEntitySpeed(ped) > 1.5) then
                addSkill('stamina')
            end

            -- Potápění -> Kapacita plic
            if IsPedSwimmingUnderWater(ped) then
                addSkill('lung_capacity')
            end

            -- Řízení vozidla (pouze řidič při rychlosti > 80 km/h) -> Řízení
            local veh = cache.vehicle
            if veh and cache.seat == -1 then
                local speedKmH = GetEntitySpeed(veh) * 3.6
                if speedKmH > 80.0 then
                    addSkill('driving')
                end
            end
        end
    end
end)

-- SMYČKA PRO BOJ A STŘELBU (Dynamický sleep)
CreateThread(function()
    while true do
        local sleep = 1000
        if isLoaded then
            local ped = cache.ped
            
            -- Pokud hráč drží střelnou zbraň
            if IsPedArmed(ped, 4) then
                sleep = 200
                if IsPedShooting(ped) then
                    addSkill('shooting')
                    
                    -- Snížení třesu kamery při střelbě podle úrovně skillu
                    local shootSkill = currentSkills.shooting or 0.0
                    if shootSkill < 100.0 then
                        local shake = 0.15 * (1.0 - (shootSkill / 100.0))
                        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', shake)
                    end
                    Wait(500) -- Cooldown aby samopal nevyexpil skill za 10 vteřin
                end
            -- Boj na blízko (pěstmi nebo tupou zbraní)
            elseif IsPedInMeleeCombat(ped) then
                sleep = 200
                if IsPedPerformingMeleeAction(ped) then
                    addSkill('strength')
                    Wait(1000) -- Cooldown mezi údery
                end
            end
        end
        Wait(sleep)
    end
end)

-- Exporty pro ostatní scripty (např. posilovna, střelnice, autoškola)
exports('GetSkill', function(skillName)
    return currentSkills[skillName] or 0.0
end)

exports('AddSkill', function(skillName, amount)
    addSkill(skillName, amount)
end)
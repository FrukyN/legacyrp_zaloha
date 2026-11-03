local state = { loaded = false, data = nil, pendingToken = nil }
local isShaking = false
local promptActive = false

local function notify(description, ntype)
    lib.notify({ title = 'Needs', description = description, type = ntype or 'inform' })
end

local function applyEffects(data)
    if not data then return end

    -- Efekt hladovění a žízně
    if (data.hunger or 0) >= Config.Starvation.hungerThreshold or (data.thirst or 0) >= Config.Starvation.thirstThreshold then
        StartScreenEffect('DeathFailOut', 1500, false)
    end

    -- Efekt vysokého stresu (rozmazání)
    if (data.stress or 0) >= Config.Stress.highThreshold then
        StartScreenEffect('Rampage', Config.Stress.blurDurationMs, false)
    end

    -- Třes kamery při extrémním stresu (s korektním vypínáním)
    if (data.stress or 0) >= Config.Stress.shakeThreshold then
        if not isShaking then
            ShakeGameplayCam('DRUNK_SHAKE', 0.18)
            isShaking = true
        end
    elseif isShaking then
        StopGameplayCamShaking(false)
        isShaking = false
    end
end

local function getUseContext()
    local ped = cache.ped or PlayerPedId()
    return {
        isSwimming = IsPedSwimming(ped),
        isSprinting = IsPedSprinting(ped)
    }
end

local function showUseTextUi(itemName, usesLeft, maxUses, freshness)
    if promptActive then return end
    promptActive = true

    local text = ('[E] Pouzit | [H] Schovat | %s (%s/%s) | cerstvost: %s%%'):format(itemName, usesLeft, maxUses, freshness or 100)
    lib.showTextUI(text, { position = 'right-center', icon = 'utensils' })

    CreateThread(function()
        local timeout = GetGameTimer() + Config.UsePromptTimeoutMs
        local currentToken = state.pendingToken

        while promptActive and state.pendingToken == currentToken and GetGameTimer() < timeout do
            Wait(0)
            if IsControlJustPressed(0, 38) then -- [E]
                promptActive = false
                lib.hideTextUI()
                TriggerServerEvent('fr_needs:server:usePromptResult', currentToken, 'use', getUseContext())
                return
            end
            if IsControlJustPressed(0, 74) then -- [H]
                promptActive = false
                lib.hideTextUI()
                TriggerServerEvent('fr_needs:server:usePromptResult', currentToken, 'hide')
                return
            end
        end

        if promptActive and state.pendingToken == currentToken then
            promptActive = false
            lib.hideTextUI()
            TriggerServerEvent('fr_needs:server:usePromptResult', currentToken, 'hide')
        end
    end)
end

RegisterNetEvent('fr_needs:client:setState', function(newState)
    state.loaded = true
    state.data = newState
    applyEffects(newState)
end)

RegisterNetEvent('fr_needs:client:showUsePrompt', function(token, itemName, usesLeft, maxUses, freshness)
    state.pendingToken = token
    showUseTextUi(itemName, usesLeft, maxUses, freshness)
end)

RegisterNetEvent('fr_needs:client:consumed', function(itemName, usesLeft, freshness)
    notify(('Zbyvajici pouziti: %s | cerstvost: %s%%'):format(usesLeft, freshness or 100), 'success')
end)

RegisterNetEvent('fr_needs:client:hidden', function()
    notify('Item schovan.', 'inform')
end)

RegisterNetEvent('fr_needs:client:warn', function(message)
    notify(message, 'warning')
end)

RegisterNetEvent('fr_needs:client:stumble', function()
    local ped = cache.ped or PlayerPedId()
    if ped and ped ~= 0 and not IsPedRagdoll(ped) and not IsPedInAnyVehicle(ped, false) then
        SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
    end
end)

RegisterNetEvent('fr_needs:client:blackout', function()
    local ped = cache.ped or PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    DoScreenFadeOut(800)
    Wait(800)
    if not IsPedInAnyVehicle(ped, false) then
        SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
    end
    Wait(2500)
    DoScreenFadeIn(1500)
end)

RegisterNetEvent('fr_needs:client:applyDamage', function(damage)
    local ped = cache.ped or PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    local currentHealth = GetEntityHealth(ped)
    local newHealth = math.max(100, currentHealth - damage) -- 100 HP je hranice přežití u GTA V peda

    if newHealth < currentHealth then
        SetEntityHealth(ped, newHealth)
    end
end)

CreateThread(function()
    local serverState = lib.callback.await('fr_needs:server:getState', false)
    if serverState then
        state.loaded = true
        state.data = serverState
        applyEffects(serverState)
    end

    for i = 1, #Config.TargetDrinkStations do
        local station = Config.TargetDrinkStations[i]
        exports.ox_target:addSphereZone({
            coords = station.coords,
            radius = station.radius or 1.0,
            debug = Config.Debug,
            drawSprite = true,
            options = {
                {
                    name = ('fr_needs_drink_%s'):format(i),
                    icon = station.icon or 'fa-solid fa-glass-water',
                    label = station.label or 'Napij se',
                    onSelect = function()
                        TriggerServerEvent('fr_needs:server:drinkStation', i)
                    end
                }
            }
        })
    end
end)
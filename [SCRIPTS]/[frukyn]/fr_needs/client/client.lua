local state = { loaded = false, data = nil }

local function notify(description, ntype)
    lib.notify({ title = 'Needs', description = description, type = ntype or 'inform' })
end

local function applyEffects(data)
    if not data then return end
    if (data.hunger or 0) >= Config.Starvation.hungerThreshold or (data.thirst or 0) >= Config.Starvation.thirstThreshold then StartScreenEffect('DeathFailOut', 1500, false) end
    if (data.stress or 0) >= Config.Stress.highThreshold then StartScreenEffect('Rampage', Config.Stress.blurDurationMs, false) end
    if (data.stress or 0) >= Config.Stress.shakeThreshold then ShakeGameplayCam('DRUNK_SHAKE', 0.18) end
end

local function getUseContext()
    local ped = cache.ped
    return { isSwimming = IsPedSwimming(ped), isSprinting = IsPedSprinting(ped), inVehicle = IsPedInAnyVehicle(ped, false) }
end

local function showUseTextUi(itemName, usesLeft, maxUses, freshness)
    local done = false
    local text = ('[E] Pouzit | [H] Schovat | %s (%s/%s) | cerstvost: %s%%'):format(itemName, usesLeft, maxUses, freshness or 100)
    lib.showTextUI(text, { position = 'right-center', icon = 'utensils' })

    CreateThread(function()
        local timeout = GetGameTimer() + Config.UsePromptTimeoutMs
        while not done and GetGameTimer() < timeout do
            Wait(0)
            if IsControlJustPressed(0, 38) then
                done = true
                lib.hideTextUI()
                TriggerServerEvent('fr_needs:server:usePromptResult', state.pendingToken, 'use', getUseContext())
                return
            end
            if IsControlJustPressed(0, 74) then
                done = true
                lib.hideTextUI()
                TriggerServerEvent('fr_needs:server:usePromptResult', state.pendingToken, 'hide')
                return
            end
        end
        if not done then
            lib.hideTextUI()
            TriggerServerEvent('fr_needs:server:usePromptResult', state.pendingToken, 'hide')
        end
    end)
end

RegisterNetEvent('fr_needs:client:setState', function(newState) state.loaded = true state.data = newState applyEffects(newState) end)
RegisterNetEvent('fr_needs:client:showUsePrompt', function(token, itemName, usesLeft, maxUses, freshness) state.pendingToken = token showUseTextUi(itemName, usesLeft, maxUses, freshness) end)
RegisterNetEvent('fr_needs:client:consumed', function(itemName, usesLeft, freshness) notify(('Zbyvajici pouziti: %s | cerstvost: %s%%'):format(usesLeft, freshness or 100), 'success') end)
RegisterNetEvent('fr_needs:client:hidden', function() notify('Item schovan.', 'inform') end)
RegisterNetEvent('fr_needs:client:warn', function(message) notify(message, 'warning') end)
RegisterNetEvent('fr_needs:client:needsTick', function(newState) state.data = newState applyEffects(newState) end)
RegisterNetEvent('fr_needs:client:stumble', function() if cache.ped and cache.ped ~= 0 then SetPedToRagdoll(cache.ped, 1500, 1500, 0, false, false, false) end end)

CreateThread(function()
    local serverState = lib.callback.await('fr_needs:server:getState', false)
    if serverState then state.loaded = true state.data = serverState applyEffects(serverState) end

    for i = 1, #Config.TargetDrinkStations do
        local station = Config.TargetDrinkStations[i]
        exports.ox_target:addSphereZone({
            coords = station.coords,
            radius = station.radius or 1.0,
            debug = Config.Debug,
            drawSprite = true,
            options = { { name = ('fr_needs_drink_%s'):format(i), icon = station.icon or 'fa-solid fa-glass-water', label = station.label or 'Napij se', onSelect = function() TriggerServerEvent('fr_needs:server:drinkStation', i) end } }
        })
    end
end)

RegisterNetEvent('fr_needs:client:applyDamage', function(damage)
    local ped = cache.ped or PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    local currentHealth = GetEntityHealth(ped)
    local newHealth = math.max(100, currentHealth - damage) -- U GTA V pedů bývá základní/smrtící hranice 100 HP

    SetEntityHealth(ped, newHealth)
end)
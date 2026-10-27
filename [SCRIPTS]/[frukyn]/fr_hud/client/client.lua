FR_HUD = {
    isVisible = false,
    inCinematic = false,
    showLogo = true
}

local currentVoiceRange = 2

-- ==========================================
-- NAČTENÍ ULOŽENÝCH DAT (KVP PAMĚŤ)
-- ==========================================
local savedPos = GetResourceKvpString("fr_hud_position") or "top-right"

local savedLogo = GetResourceKvpString("fr_hud_logo")
if savedLogo == "false" then
    FR_HUD.showLogo = false
else
    FR_HUD.showLogo = true
end

CreateThread(function()
    Wait(1000)

    SendNUIMessage({ action = "setVisible", state = false })
    SendNUIMessage({ action = "setPosition", position = savedPos })
    SendNUIMessage({ action = "setLogo", state = FR_HUD.showLogo })

    -- OPRAVA: Získání aktuální vzdálenosti z pma-voice ihned po startu a odeslání do UI
    if LocalPlayer.state.proximity then
        currentVoiceRange = LocalPlayer.state.proximity.mode or 2
    end
    SendNUIMessage({ action = "updateVoiceRange", mode = currentVoiceRange })
end)


-- ==========================================
-- EXPORTY A INTEGRACE
-- ==========================================
exports('toggleHud', function(state)
    FR_HUD.isVisible = state
    SendNUIMessage({ action = "setVisible", state = FR_HUD.isVisible and not FR_HUD.inCinematic and
    not IsPauseMenuActive() })
end)

exports('loadHud', function()
    FR_HUD.isVisible = true
    SendNUIMessage({ action = "setVisible", state = true })
    SendNUIMessage({ action = "setPosition", position = GetResourceKvpString("fr_hud_position") or "top-right" })
    SendNUIMessage({ action = "setLogo", state = FR_HUD.showLogo })
end)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    currentVoiceRange = mode
    SendNUIMessage({ action = "updateVoiceRange", mode = mode })
end)

CreateThread(function()
    local wasTalking = false
    local isPaused = false

    while true do
        Wait(150)

        local pauseMenu = IsPauseMenuActive()
        if pauseMenu ~= isPaused then
            isPaused = pauseMenu
            local state = FR_HUD.isVisible and not FR_HUD.inCinematic and not isPaused
            SendNUIMessage({ action = "setVisible", state = state })
        end

        -- OPRAVA: Detekce mluvení vytažena ven. Nyní běží neustále a synchronizuje UI i když je HUD zrovna schovaný přes ESC.
        local isTalking = NetworkIsPlayerTalking(PlayerId())
        if isTalking ~= wasTalking then
            wasTalking = isTalking
            SendNUIMessage({ action = "updateTalkingState", state = isTalking })
        end
    end
end)

-- ==========================================
-- OX_LIB NASTAVENÍ (Rozšířené Menu s pamětí)
-- ==========================================
local function setPosition(pos)
    SetResourceKvp("fr_hud_position", pos)
    SendNUIMessage({ action = "setPosition", position = pos })
    lib.notify({ title = 'HUD', description = 'Pozice změněna a uložena.', type = 'success' })
end

lib.registerContext({
    id = 'fr_hud_position_menu',
    title = 'Pozice HUDu',
    menu = 'fr_hud_settings',
    options = {
        { title = 'Vpravo nahoře', icon = 'arrow-up-right',   onSelect = function() setPosition('top-right') end },
        { title = 'Vlevo nahoře',  icon = 'arrow-up-left',    onSelect = function() setPosition('top-left') end },
        { title = 'Vlevo dole',    icon = 'arrow-down-left',  onSelect = function() setPosition('bottom-left') end },
        { title = 'Vpravo dole',   icon = 'arrow-down-right', onSelect = function() setPosition('bottom-right') end }
    }
})

lib.registerContext({
    id = 'fr_hud_settings',
    title = 'Nastavení HUDu',
    options = {
        {
            title = 'Pozice HUDu',
            description = 'Změnit roh, kde se nachází status postavy.',
            icon = 'arrows-up-down-left-right',
            menu = 'fr_hud_position_menu'
        },
        {
            title = 'Zobrazit/Skrýt Logo',
            description = 'Vypne nebo zapne logo serveru (uloží se)',
            icon = 'image',
            onSelect = function()
                FR_HUD.showLogo = not FR_HUD.showLogo
                SetResourceKvp("fr_hud_logo", tostring(FR_HUD.showLogo))
                SendNUIMessage({ action = "setLogo", state = FR_HUD.showLogo })
            end
        },
        {
            title = 'Filmový režim (Cinematic)',
            description = 'Skryje veškerý HUD na obrazovce a přidá pruhy.',
            icon = 'film',
            onSelect = function()
                FR_HUD.inCinematic = not FR_HUD.inCinematic
                SendNUIMessage({ action = "setVisible", state = not FR_HUD.inCinematic })
                SendNUIMessage({ action = "setCinematic", state = FR_HUD.inCinematic })
                lib.notify({ title = 'HUD', description = FR_HUD.inCinematic and 'Filmový režim ZAPNUT' or
                'Filmový režim VYPNUT', type = 'info' })
                ExecuteCommand("clear")
            end
        },
        {
            title = 'Kompletně vypnout HUD',
            description = 'Zcela vypne script prvků.',
            icon = 'eye-slash',
            onSelect = function()
                exports['fr_hud']:toggleHud(not FR_HUD.isVisible)
                ExecuteCommand("clear")
            end
        }
    }
})

RegisterCommand('hudsettings', function()
    lib.showContext('fr_hud_settings')
end, false)

RegisterCommand('hudreset', function()
    exports['fr_hud']:toggleHud(not FR_HUD.isVisible)
end, false)

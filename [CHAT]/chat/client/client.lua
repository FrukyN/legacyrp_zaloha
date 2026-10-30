local isRDR = not TerraingridActivate and true or false

local chatInputActive = false
local chatHidden = true
local chatLoaded = false
local isChatHudHidden = false -- Stav skrytí z HUDu / menu

RegisterNetEvent('chatMessage')
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')

-- internal events
RegisterNetEvent('__cfx_internal:serverPrint')
RegisterNetEvent('_chat:messageEntered')

-- ====================================================================
-- OVLÁDÁNÍ VIDITELNOSTI CHATU
-- ====================================================================
local function setChatState(hidden)
  isChatHudHidden = hidden

  if isChatHudHidden then
    chatInputActive = false
    SetNuiFocus(false, false)
  end

  -- Posíláme obě zprávy pro 100% kompatibilitu s NUI
  SendNUIMessage({
    type = 'SET_CHAT_HIDDEN',
    state = isChatHudHidden
  })
  SendNUIMessage({
    type = isChatHudHidden and 'ON_HIDE' or 'ON_SHOW'
  })
end

exports('setChatHidden', function(state)
  setChatState(state)
end)

exports('toggleChat', function()
  setChatState(not isChatHudHidden)
  return isChatHudHidden
end)

exports('isChatHidden', function()
  return isChatHudHidden
end)

-- ====================================================================
-- PŘÍKAZ /clear
-- ====================================================================
RegisterCommand('clear', function()
  TriggerEvent('chat:clear')
end, false)

-- deprecated, use chat:addMessage
AddEventHandler('chatMessage', function(author, color, text)
  if isChatHudHidden then return end -- Pokud je skrytý, neposílá se do UI

  local args = { text }
  if author ~= "" then
    table.insert(args, 1, author)
  end
  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = {
      color = color,
      multiline = true,
      args = args
    }
  })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
  if isChatHudHidden then return end

  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = {
      templateId = 'print',
      multiline = true,
      args = { msg }
    }
  })
end)

AddEventHandler('chat:addMessage', function(message)
  if isChatHudHidden then return end

  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = message
  })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
  SendNUIMessage({
    type = 'ON_SUGGESTION_ADD',
    suggestion = {
      name = name,
      help = help,
      params = params or nil
    }
  })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
  SendNUIMessage({
    type = 'ON_SUGGESTIONS_ADD',
    suggestions = suggestions
  })
end)

AddEventHandler('chat:removeSuggestion', function(name)
  SendNUIMessage({
    type = 'ON_SUGGESTION_REMOVE',
    name = name
  })
end)

AddEventHandler('chat:addTemplate', function(id, html)
  SendNUIMessage({
    type = 'ON_TEMPLATE_ADD',
    template = {
      id = id,
      html = html
    }
  })
end)

AddEventHandler('chat:clear', function(name)
  SendNUIMessage({
    type = 'ON_CLEAR'
  })
end)

RegisterNUICallback('chatResult', function(data, cb)
  chatInputActive = false
  SetNuiFocus(false, false)

  if not data.canceled then
    local id = PlayerId()
    local r, g, b = 0, 0x99, 255
    if data.message:sub(1, 1) == '/' then
      ExecuteCommand(data.message:sub(2))
    else
      TriggerServerEvent('_chat:messageEntered', GetPlayerName(id), { r, g, b }, data.message)
    end
  end

  cb('ok')
end)

local function openChatInput()
  -- Pokud je chat skrytý, vůbec ho neotevře
  if chatInputActive or isChatHudHidden then
    return
  end

  chatInputActive = true

  SendNUIMessage({
    type = 'ON_OPEN'
  })

  Citizen.CreateThread(function()
    Wait(0)
    SetNuiFocus(true, false)
  end)
end

local function refreshCommands()
  if GetRegisteredCommands then
    local registeredCommands = GetRegisteredCommands()
    local suggestions = {}

    for _, command in ipairs(registeredCommands) do
        if IsAceAllowed(('command.%s'):format(command.name)) then
            table.insert(suggestions, {
                name = '/' .. command.name,
                help = ''
            })
        end
    end

    table.insert(suggestions, {
        name = '/clear',
        help = 'Vymaže celou historii zpráv v chatu'
    })

    TriggerEvent('chat:addSuggestions', suggestions)
  end
end

local function refreshThemes()
  local themes = {}

  for resIdx = 0, GetNumResources() - 1 do
    local resource = GetResourceByFindIndex(resIdx)

    if GetResourceState(resource) == 'started' then
      local numThemes = GetNumResourceMetadata(resource, 'chat_theme')

      if numThemes > 0 then
        local themeName = GetResourceMetadata(resource, 'chat_theme', 0)
        local themeData = json.decode(GetResourceMetadata(resource, 'chat_theme_extra', 0) or 'null')

        if themeName and themeData then
          themeData.baseUrl = 'nui://' .. resource .. '/'
          themes[themeName] = themeData
        end
      end
    end
  end

  SendNUIMessage({
    type = 'ON_UPDATE_THEMES',
    themes = themes
  })
end

AddEventHandler('onClientResourceStart', function(resName)
  Wait(500)
  refreshCommands()
  refreshThemes()
end)

AddEventHandler('onClientResourceStop', function(resName)
  Wait(500)
  refreshCommands()
  refreshThemes()
end)

RegisterNUICallback('loaded', function(data, cb)
  TriggerServerEvent('chat:init')
  refreshCommands()
  refreshThemes()
  chatLoaded = true
  cb('ok')
end)

RegisterCommand('openChat', function()
  openChatInput()
end, false)

if not isRDR then
  RegisterKeyMapping('openChat', "<font face='ChakraPetch-Regular'>Otevřít chat</font>", 'keyboard', 't')
end

Citizen.CreateThread(function()
  SetTextChatEnabled(false)
  SetNuiFocus(false, false)

  while true do
    Wait(isRDR and 0 or 250)

    if isRDR and not chatInputActive and IsControlJustPressed(0, 245) then
      openChatInput()
    end

    if chatLoaded then
      local shouldBeHidden = false

      if IsScreenFadedOut() or IsPauseMenuActive() or isChatHudHidden then
        shouldBeHidden = true
      end

      if (shouldBeHidden and not chatHidden) or (not shouldBeHidden and chatHidden) then
        chatHidden = shouldBeHidden

        SendNUIMessage({
          type = 'ON_SCREEN_STATE_CHANGE',
          shouldHide = shouldBeHidden
        })
      end
    end
  end
end)
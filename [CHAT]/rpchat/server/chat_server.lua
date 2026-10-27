local Framework = require 'server.framework'

function GetRealPlayerName(playerId)
  local xPlayer = Framework.getPlayer(playerId)
  return Framework.getCharacterName(xPlayer, playerId)
end

AddEventHandler('chatMessage', function(source, name, message)
  if string.sub(message, 1, string.len('/')) ~= '/' then
    CancelEvent()
    local xPlayer = Framework.getPlayer(source)
    local name = GetPlayerName(source)
    local admin = false
    if wx.LOOCAdminPrefixes then
      if Framework.isAdmin(xPlayer) then admin = true end
    end
    TriggerClientEvent('wx_rpchat:sendLocalOOC', -1, source, name, message, admin);
  end
end)

RegisterCommand('me', function(source, args, raw)
  local args = table.concat(args, ' ')
  local name = GetRealPlayerName(source)

  TriggerClientEvent('wx_rpchat:sendMe', -1, source, name, args, { 196, 33, 246 })
  TriggerClientEvent('3dme:triggerDisplay', -1, args, source)
end, false)

RegisterCommand('do', function(source, args, raw)
  local args = table.concat(args, ' ')
  local name = GetRealPlayerName(source)

  TriggerClientEvent('wx_rpchat:sendDo', -1, source, name, args, { 255, 198, 0 })
  TriggerClientEvent('3ddo:triggerDisplay', -1, "* " .. args .. " *", source)
end, false)

RegisterCommand('try', function(source, args, raw)
  local result = "NE"
  local name = GetRealPlayerName(source)
  local random = math.random(1, 2)
  if random == 1 then
    result = "ANO"
    TriggerClientEvent('wx_rpchat:sendTry', -1, source, name, result, { 255, 198, 0 })
    TriggerClientEvent('3dme:triggerDisplay', -1, "* " .. result .. " *", source)
  else
    TriggerClientEvent('wx_rpchat:sendTry', -1, source, name, result, { 255, 198, 0 })
    TriggerClientEvent('3dme:triggerDisplay', -1, "* " .. result .. " *", source)
  end
end, false)

RegisterCommand('doc', function(source, args, raw)
  local name = GetRealPlayerName(source)
  if args[1] ~= nil then
    local c = 0
    local count = tonumber(args[1])
    if count < wx.MaxDocCount then
      while c < count do
        c = c + 1
        TriggerClientEvent('wx_rpchat:sendDoc', -1, source, name, c .. "/" .. count, { 255, 198, 0 })
        TriggerClientEvent('3ddoa:triggerDisplay', -1, c .. "/" .. count, source)
        Wait(1518)
      end
    end
  end
end, false)

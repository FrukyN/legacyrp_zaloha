local displayHeight = 1

RegisterNetEvent('wx_rpchat:sendMe')
AddEventHandler('wx_rpchat:sendMe', function(playerId, title, message, color)
    local source = GetPlayerServerId(PlayerId())
    local target = GetPlayerFromServerId(playerId)
    local sourcePed, targetPed = PlayerPedId(), GetPlayerPed(target)
    local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)
    if target == -1 then return end
    if target == source or GetDistanceBetweenCoords(sourceCoords, targetCoords, true) < 10 then
      TriggerEvent('chat:addMessage', {
        template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">ID: {0}</font>
          </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #296317ff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">ME</font>
          </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
      </div>
        ]],
        args = { source,title, message }
      })
    end
end)

RegisterNetEvent('wx_rpchat:sendTry')
AddEventHandler('wx_rpchat:sendTry', function(playerId, title, message, color)
    local source = GetPlayerServerId(PlayerId())
    local target = GetPlayerFromServerId(playerId)
    local sourcePed, targetPed = PlayerPedId(), GetPlayerPed(target)
    local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)

    if target == -1 then
        return
    end

    if target == source or GetDistanceBetweenCoords(sourceCoords, targetCoords, true) < 10 then
      TriggerEvent('chat:addMessage', {
        template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">ID: {0}</font>
          </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: rgba(52, 185, 167, 0.81); padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">TRY</font>
          </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
      </div>
        ]],
        args = { source,title, message }
      })
    end
end)

RegisterNetEvent('wx_rpchat:sendDo')
AddEventHandler('wx_rpchat:sendDo', function(playerId, title, message, color)
  local source = GetPlayerServerId(PlayerId())
  local target = GetPlayerFromServerId(playerId)
  local sourcePed, targetPed = PlayerPedId(), GetPlayerPed(target)
  local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)
  if target == -1 then
    return
  end
  if target == source or GetDistanceBetweenCoords(sourceCoords, targetCoords, true) < 10 then
    TriggerEvent('chat:addMessage', {
      template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
            <font style="font-weight: 400;">ID: {0}</font>
        </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #919c2cff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
            <font style="font-weight: 400;">DO</font>
        </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
    </div>
      ]],
      args = { source,title, message }
    })
  end
end)

RegisterNetEvent('wx_rpchat:sendDoc')
AddEventHandler('wx_rpchat:sendDoc', function(playerId, title, message, color)
    local source = GetPlayerServerId(PlayerId())
    local target = GetPlayerFromServerId(playerId)
    local sourcePed, targetPed = PlayerPedId(), GetPlayerPed(target)
    local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)

    if target == -1 then
        return
    end

    if target == source or GetDistanceBetweenCoords(sourceCoords, targetCoords, true) < 10 then
      TriggerEvent('chat:addMessage', {
        template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">ID: {0}</font>
          </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: rgba(167, 61, 209, 0.9); padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
              <font style="font-weight: 400;">DOC</font>
          </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
      </div>
        ]],
        args = { source,title, message }
      })
    end
end)

local cooldown = false
RegisterNetEvent('wx_rpchat:sendLocalOOC')
AddEventHandler('wx_rpchat:sendLocalOOC', function(playerId, title, message, admin)
	local source = GetPlayerServerId(PlayerId())
	local target = GetPlayerFromServerId(playerId)
  local fal = GetPlayerName(PlayerId())
	if target ~= -1 then
    local sourcePed, targetPed = PlayerPedId(), GetPlayerPed(target)
    local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)

    if targetPed == source or #(sourceCoords - targetCoords) < 10 then
      if admin then
        TriggerEvent('chat:addMessage', {
            template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
                  <font style="font-weight: 400;">ID: {0}</font>
              </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #8f8f8fff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
                  <font style="font-weight: 400;">L-OOC</font>
              </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #962819ff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
                  <font style="font-weight: 400;">ADMIN</font>
              </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
          </div>
            ]],
            args = { playerId,title, message }
          })
        else
          TriggerEvent('chat:addMessage', {
            template = [[
          <div style="padding: 0.15vw; height: 1.3vw; width: 100%; margin: 0.2vw;  background-color: rgba(6, 11, 34, 0.75); border-radius: 4px; padding-top: 0.4vw; border: none; box-shadow: 0px 0px 11px rgba(34, 34, 34, 0.35)">

          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #4b4b4bff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
                  <font style="font-weight: 400;">ID: {0}</font>
              </font>
          <font style="padding: 0.15vw; margin: 0.22vw; background-color: #8f8f8fff; padding-left: 1%; border-radius: 1px; border: none; font-size: 13px">
                  <font style="font-weight: 400;">L-OOC</font>
              </font>
          <font style="font-size: 14px; padding-left: 5px; color: #dfddddff; margin: auto; font-weight:400">{1}:</font>
          <font class="message" style="font-size: 14px; color: #dfddddff; margin: auto; font-weight:400"> {2}</font>
          </div>
            ]],
            args = { playerId,title, message }
          })
        end
    end
end
end)


RegisterNetEvent('wx_rpchat:getCoords')
AddEventHandler('wx_rpchat:getCoords', function(player)
	  local ped = PlayerPedId()
    local coords = GetEntityCoords(ped, false)
    local heading = GetEntityHeading(ped)

    local message = tostring("X: " .. coords.x .. " Y: " .. coords.y .. " Z: " .. coords.z .. " HEADING: " .. heading)
    TriggerServerEvent('wx_rpchat:showCoord', player, message)

end)

RegisterNetEvent('3dme:triggerDisplay')
AddEventHandler('3dme:triggerDisplay', function(text, source)
    local offsetme = 2.04 + (displayHeight*0.15)
    if GetPlayerFromServerId(source) ~= -1 then
      DisplayMe(GetPlayerFromServerId(source), text, offsetme)
    end
end)

RegisterNetEvent('3ddo:triggerDisplay')
AddEventHandler('3ddo:triggerDisplay', function(text, source)
    local offsetdo = 1.34 + (displayHeight*0.15)
    if GetPlayerFromServerId(source) ~= -1 then
    DisplayDo(GetPlayerFromServerId(source), text, offsetdo)
    end
end)

RegisterNetEvent('3ddoa:triggerDisplay')
AddEventHandler('3ddoa:triggerDisplay', function(text, source)
    local offsetdoa = 1.29 + (displayHeight*0.15)
    if GetPlayerFromServerId(source) ~= -1 then
    DisplayDoa(GetPlayerFromServerId(source), text, offsetdoa)
    end
end)
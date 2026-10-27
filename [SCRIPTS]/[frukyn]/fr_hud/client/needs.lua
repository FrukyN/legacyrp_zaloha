local stressLevel = 0

local function updateHudNeeds(data)
    if not data then return end
    stressLevel = data.stress or 0
    
    SendNUIMessage({
        action = "updateNeeds",
        hunger = data.hunger or 0,
        thirst = data.thirst or 0,
        stress = data.stress or 0,
        alcohol = data.alcohol or 0,  
        drug = data.drug or 0             })
end

RegisterNetEvent('fr_needs:client:setState', function(newState) updateHudNeeds(newState) end)
RegisterNetEvent('fr_needs:client:needsTick', function(newState) updateHudNeeds(newState) end)

CreateThread(function()
    while true do
        Wait(600) 
        if FR_HUD.isVisible and not FR_HUD.inCinematic then
            local ped = PlayerPedId()
            local hp = GetEntityHealth(ped) - 100
            if hp < 0 then hp = 0 end
            local armor = GetPedArmour(ped)
            
            local playerId = PlayerId()
            local staminaRemaining = GetPlayerSprintStaminaRemaining(playerId)
            local stamina = math.floor(100.0 - staminaRemaining)
            
            if stamina < 0 then stamina = 0 end
            if stamina > 100 then stamina = 100 end
            
            SendNUIMessage({
                action = "updateHealth",
                health = hp,
                armor = armor,
                stamina = stamina
            })
        end
    end
end)
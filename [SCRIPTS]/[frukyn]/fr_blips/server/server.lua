local Ox = require '@ox_core.lib.init'
local currentCounts = {}

local function fetchJobCounts()
    local counts = {}
    local players = Ox.GetPlayers()

    for _, player in pairs(players) do
        local inService = player.get('inService')
        if inService then
            counts[inService] = (counts[inService] or 0) + 1
        end

    end
    return counts
end

CreateThread(function()
    while true do
        Wait(Config.UpdateInterval)
        local newCounts = fetchJobCounts()
        local changed = false

        for job, count in pairs(newCounts) do
            if currentCounts[job] ~= count then
                changed = true
                break
            end
        end
        if not changed then
            for job, count in pairs(currentCounts) do
                if newCounts[job] ~= count then
                    changed = true
                    break
                end
            end
        end

        if changed then
            currentCounts = newCounts
            TriggerClientEvent('fr_blips:update', -1, currentCounts)
        end
    end
end)

RegisterNetEvent('fr_blips:request', function()
    TriggerClientEvent('fr_blips:update', source, currentCounts)
end)

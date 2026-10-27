local Ox = require '@ox_core.lib.init'
local currentCounts = {}

local function fetchJobCounts()
    local counts = {}
    local players = Ox.GetPlayers()

    for _, player in pairs(players) do
        local groups = player.getGroups()
        if groups then
            for groupName, grade in pairs(groups) do
                counts[groupName] = (counts[groupName] or 0) + 1
            end
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
            TriggerClientEvent('dynblips:update', -1, currentCounts)
        end
    end
end)

RegisterNetEvent('dynblips:request', function()
    TriggerClientEvent('dynblips:update', source, currentCounts)
end)

local Ox = require '@ox_core.lib.init'

local function getPlayer(source)
    return Ox.GetPlayer(source)
end

local function getPlayerJobName(player)
    if not player then return nil end
    local group = player.getGroup and player.getGroup('job')
    if type(group) == 'table' then
        return group.name or group.group or group.id
    end

    if player.getGroups then
        local groups = player.getGroups()
        if type(groups) == 'table' then
            local job = groups.job
            if type(job) == 'string' then
                return job
            elseif type(job) == 'table' then
                return job.name or job.group or job.id
            end
        end
    end

    return nil
end

local function getPlayerJobLabel(player)
    if not player then return 'Nezaměstnaný' end
    local group = player.getGroup and player.getGroup('job')
    if type(group) == 'table' then
        return group.label or group.name or 'Nezaměstnaný'
    end
    return getPlayerJobName(player) or 'Nezaměstnaný'
end

local function getPlayerJobGradeLabel(player)
    if not player then return '' end
    local group = player.getGroup and player.getGroup('job')
    if type(group) == 'table' then
        local grade = group.grade
        if type(grade) == 'table' then
            return grade.label or tostring(grade.name or grade.level or '')
        end
        return tostring(group.gradeLabel or group.rank or '')
    end
    return ''
end

local function isAdmin(player)
    if not player then return false end
    if player.getGroups then
        local groups = player.getGroups() or {}
        for groupName in pairs(wx.AdminGroups) do
            if groups[groupName] ~= nil then
                return true
            end
        end
    end
    return false
end

local function getCharacterName(player, source)
    if not player then return GetPlayerName(source) end

    if wx.OnlyInicials then
        local firstName
        local lastName

        if player.get then
            firstName = player.get('firstName')
            lastName = player.get('lastName')
        end

        if (not firstName or not lastName) and player.getName then
            local fullName = player.getName()
            local parts = {}
            for part in tostring(fullName):gmatch('%S+') do
                parts[#parts + 1] = part
            end
            firstName = firstName or parts[1]
            lastName = lastName or parts[2] or parts[1]
        end

        if firstName and lastName then
            return string.sub(firstName, 1, 1) .. '. ' .. string.sub(lastName, 1, 1) .. '. '
        end
    end

    if player.getName then
        return player.getName()
    end

    return GetPlayerName(source)
end

local function getAdminsOnline()
    local admins = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local player = getPlayer(id)
        if isAdmin(player) then
            admins[#admins + 1] = id
        end
    end
    return admins
end

return {
    getPlayer = getPlayer,
    getPlayerJobName = getPlayerJobName,
    getPlayerJobLabel = getPlayerJobLabel,
    getPlayerJobGradeLabel = getPlayerJobGradeLabel,
    isAdmin = isAdmin,
    getCharacterName = getCharacterName,
    getAdminsOnline = getAdminsOnline,
}

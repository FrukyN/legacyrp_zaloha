local playerSkills = {}
local dirtyPlayers = {}

local function getDefaultSkills()
    local tbl = {}
    for k, _ in pairs(Config.Skills) do
        tbl[k] = 0.0
    end
    return tbl
end

local function loadPlayerSkills(source, charId)
    if not charId then return end
    
    local result = MySQL.scalar.await('SELECT skills FROM fr_skills WHERE charId = ?', { charId })
    local skills = getDefaultSkills()

    if result then
        local decoded = json.decode(result)
        for k, v in pairs(decoded) do
            if skills[k] ~= nil then
                skills[k] = math.min(100.0, math.max(0.0, tonumber(v) or 0.0))
            end
        end
    else
        MySQL.insert.await('INSERT INTO fr_skills (charId, skills) VALUES (?, ?)', {
            charId, json.encode(skills)
        })
    end

    playerSkills[source] = { charId = charId, data = skills }
    TriggerClientEvent('fr_skills:client:setSkills', source, skills)
end

local function savePlayerSkills(source)
    local pData = playerSkills[source]
    if pData and dirtyPlayers[source] then
        MySQL.update('UPDATE fr_skills SET skills = ? WHERE charId = ?', {
            json.encode(pData.data),
            pData.charId
        })
        dirtyPlayers[source] = nil
    end
end

-- Načtení postavy v ox_core
AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    loadPlayerSkills(source, charid)
end)

-- Odpojení hráče z ox_core / serveru
AddEventHandler('ox:playerLogout', function(source)
    savePlayerSkills(source)
    playerSkills[source] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    savePlayerSkills(src)
    playerSkills[src] = nil
end)

-- Podpora pro restart scriptu za běhu serveru
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    for _, player in pairs(Ox.GetPlayers()) do
        if player.charId then
            loadPlayerSkills(player.source, player.charId)
        end
    end
end)

-- Přidávání zkušeností z klienta (s ochranou proti exploitům)
RegisterNetEvent('fr_skills:server:addSkill', function(skillName, amount)
    local src = source
    local pData = playerSkills[src]
    if not pData or not Config.Skills[skillName] then return end

    -- Anti-cheat: Omezení maximálního přírůstku za jeden tick
    amount = tonumber(amount) or 0.0
    if amount <= 0 or amount > 1.0 then return end

    local current = pData.data[skillName] or 0.0
    if current >= 100.0 then return end

    local newSkill = math.min(100.0, math.floor((current + amount) * 100) / 100)
    pData.data[skillName] = newSkill
    dirtyPlayers[src] = true
end)

-- Pravidelné ukládání do DB (optimalizace DB dotazů)
CreateThread(function()
    while true do
        Wait(Config.SaveInterval * 60000)
        for src, _ in pairs(dirtyPlayers) do
            savePlayerSkills(src)
        end
    end
end)
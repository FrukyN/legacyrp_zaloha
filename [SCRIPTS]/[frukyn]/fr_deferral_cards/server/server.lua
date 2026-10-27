local Queue = {}               -- Pole hráčů čekajících ve frontě
local ReservedLocks = {}       -- Zámky slotů pro hráče, kteří jsou ve fázi tlačítka "Vstoupit" nebo se načítají do hry
local ReconnectTracker = {}    -- Sledování pokusů o připojení (ochrana proti reconnect spamu)
local JoinCounter = 0          -- Monotónní počítadlo pro 100% přesné pořadí při shodě bodů
local RawCardTemplate = nil

-- Načtení šablony JSONu při startu resource
CreateThread(function()
    RawCardTemplate = LoadResourceFile(GetCurrentResourceName(), "server/karta.json")
    if not RawCardTemplate then
        print("^1[QUEUE CHYBA] Nepodařilo se načíst soubor server/karta.json! Zkontroluj fxmanifest.lua.^7")
    end
end)

-- Pomocná funkce pro bezpečné escapování textu do JSONu (ochrana proti pádům, když má hráč v nicku uvozovky)
local function escapeJsonString(str)
    if not str then return "" end
    return tostring(str):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
end

-- Formátování vteřin na MM:SS pro čekání ve frontě
local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Získání identifikátorů hráče
local function getIdentifiers(src)
    local ids = {}
    for _, rawId in ipairs(GetPlayerIdentifiers(src)) do
        local prefix, val = string.match(rawId, "([^:]+):(.+)")
        if prefix and val then
            ids[prefix] = val
        end
    end
    return ids
end

-- Dotaz na Discord API – vždy čerstvé načtení rolí a sečtení (stackování) bodů
local function fetchDiscordPriority(discordId)
    local p = promise.new()

    if not discordId or Config.Discord.BotToken == "TVUJ_DISCORD_TOKEN" then
        p:resolve({ points = 0, isReserved = false, rolesFound = false })
        return Citizen.Await(p)
    end

    local endpoint = string.format("https://discord.com/api/v10/guilds/%s/members/%s", Config.Discord.GuildId, discordId)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bot " .. Config.Discord.BotToken
    }

    PerformHttpRequest(endpoint, function(statusCode, response, _)
        if statusCode == 200 and response then
            local data = json.decode(response)
            local totalPoints = 0
            local hasReserved = false

            if data and data.roles then
                for _, roleId in ipairs(data.roles) do
                    local roleCfg = Config.Roles[tostring(roleId)]
                    if roleCfg then
                        totalPoints = totalPoints + (roleCfg.points or 0)
                        if roleCfg.isReserved then
                            hasReserved = true
                        end
                    end
                end
            end

            p:resolve({ points = totalPoints, isReserved = hasReserved, rolesFound = true })
        else
            -- Hráč není na Discordu nebo API vrátilo chybu
            p:resolve({ points = 0, isReserved = false, rolesFound = false })
        end
    end, "GET", "", headers)

    return Citizen.Await(p)
end

-- Řazení fronty:
-- 1. Vyšší počet bodů má přednost.
-- 2. Při shodě bodů rozhoduje dřívější příchod do fronty (nižší joinOrder).
local function sortQueue()
    table.sort(Queue, function(a, b)
        if a.points ~= b.points then
            return a.points > b.points
        end
        return a.joinOrder < b.joinOrder
    end)
end

-- Získání pozice hráče ve frontě
local function getQueuePosition(identifier)
    for idx, entry in ipairs(Queue) do
        if entry.identifier == identifier then
            return idx
        end
    end
    return nil
end

-- Odebrání hráče z fronty
local function removeFromQueue(identifier)
    for idx, entry in ipairs(Queue) do
        if entry.identifier == identifier then
            table.remove(Queue, idx)
            return true
        end
    end
    return false
end

-- Spočítání obsazených slotů (online hráči + hráči, kteří právě dostali slot a připojují se)
local function getSlotCounts()
    local maxClients = GetConvarInt("sv_maxclients", 64)
    local reservedCfg = math.min(Config.ReservedSlots or 0, maxClients)
    local publicMax = maxClients - reservedCfg

    local onlineCount = #GetPlayers()
    local lockedCount = 0

    local now = os.time()
    for id, lock in pairs(ReservedLocks) do
        if now > lock.expires then
            ReservedLocks[id] = nil
        else
            lockedCount = lockedCount + 1
        end
    end

    local totalOccupied = onlineCount + lockedCount
    return {
        online = onlineCount,
        locked = lockedCount,
        totalOccupied = totalOccupied,
        maxClients = maxClients,
        publicMax = publicMax
    }
end

-- Kontrola, zda je pro daného hráče volný slot
local function canPlayerTakeSlot(isReservedPlayer)
    local counts = getSlotCounts()
    if isReservedPlayer then
        -- Hráč s rezervovanou rolí může obsadit jakýkoliv volný slot až do sv_maxclients
        return counts.totalOccupied < counts.maxClients
    else
        -- Běžný hráč může obsadit pouze veřejné sloty (sv_maxclients - ReservedSlots)
        return counts.totalOccupied < counts.publicMax
    end
end

-- Vyhodnocení fronty: uvolnil-li se slot, posune prvního vhodného hráče do fáze "READY" (zobrazí se mu tlačítko)
local function processQueue()
    sortQueue()
    if #Queue == 0 then return end

    local counts = getSlotCounts()
    if counts.totalOccupied >= counts.maxClients then
        return -- Server je 100% plný včetně rezervovaných slotů
    end

    for _, entry in ipairs(Queue) do
        if canPlayerTakeSlot(entry.isReserved) then
            -- Zamkneme slot pro tohoto hráče a přepneme ho do stavu READY
            ReservedLocks[entry.identifier] = {
                expires = os.time() + Config.AutoConnectTimeout + Config.ConnectingLockTimeout,
                isReserved = entry.isReserved
            }
            removeFromQueue(entry.identifier)
            entry.state = "READY"
            break
        end
    end
end

-- Sestavení Adaptive Card podle toho, zda hráč čeká ve frontě nebo má volný slot
local function buildCard(state, points, queuePos, queueTotal, timeVal)
    if not RawCardTemplate then return nil end

    local counts = getSlotCounts()
    local subtitle = (state == "READY")
        and "Místo na serveru je připraveno! Můžeš vstoupit do hry."
        or "Server je momentálně plný, čekáš ve frontě..."

    local timeLabel = (state == "READY") and "⏳ Automatické připojení za:" or "⏳ Čas ve frontě:"
    local timeValue = (state == "READY") and (tostring(timeVal) .. "s") or formatTime(timeVal)
    local frontCountText = (state == "READY") and "Připraven ke vstupu" or string.format("%d / %d", queuePos or 1, queueTotal or 1)

    local cardString = RawCardTemplate
    cardString = cardString:gsub("{SUBTITLE}", escapeJsonString(subtitle))
    cardString = cardString:gsub("{ONLINE_PLAYERS}", tostring(counts.online))
    cardString = cardString:gsub("{MAX_CLIENTS}", tostring(counts.maxClients))
    cardString = cardString:gsub("{TIME_LABEL}", escapeJsonString(timeLabel))
    cardString = cardString:gsub("{TIME_VALUE}", escapeJsonString(timeValue))
    cardString = cardString:gsub("{POCET_BODU}", tostring(points))
    cardString = cardString:gsub("{FRONT_COUNT}", escapeJsonString(frontCountText))

    local card = json.decode(cardString)
    if not card then return nil end

    card.actions = {}

    -- Pokud je volný slot (stav READY), zobrazíme tlačítko "Vstoupit do hry"
    if state == "READY" then
        table.insert(card.actions, {
            type = "Action.Submit",
            title = string.format("Vstoupit do hry (%ds)", timeVal),
            style = "positive",
            data = { action = "play" }
        })
    end

    -- Odkazová tlačítka
    if Config.Links.Web and Config.Links.Web ~= "" then
        table.insert(card.actions, {
            type = "Action.OpenUrl",
            title = "Web",
            url = Config.Links.Web
        })
    end

    if Config.Links.Shop and Config.Links.Shop ~= "" then
        table.insert(card.actions, {
            type = "Action.OpenUrl",
            title = "Obchod",
            url = Config.Links.Shop
        })
    end

    return card
end

-- Hlavní obsluha připojujícího se hráče
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    Wait(100)
    deferrals.update("Ověřuji identifikátory a načítám prioritu z Discordu...")

    if not RawCardTemplate then
        deferrals.done("Chyba serveru: Šablona karty (karta.json) nebyla nalezena.")
        return
    end

    local ids = getIdentifiers(src)
    local primaryId = ids.license or ids.discord or ids.steam or tostring(src)

    -- Kontrola zapnutého Discordu
    if Config.Discord.RequireDiscord and not ids.discord then
        deferrals.done("❌ Pro připojení na server musíš mít zapnutý a propojený Discord!")
        return
    end

    -- Ochrana proti duplicitnímu připojení se stejným identifikátorem
    if getQueuePosition(primaryId) ~= nil then
        removeFromQueue(primaryId)
    end

    -- Ochrana proti opakovanému odpojování a připojování (Anti-Reconnect Abuse)
    local now = os.time()
    local tracker = ReconnectTracker[primaryId]
    if tracker then
        local diff = now - tracker.lastAttempt
        if diff < Config.ReconnectCooldown then
            tracker.rapidCount = tracker.rapidCount + 1
            local waitPenalty = Config.ReconnectCooldown - diff
            if tracker.rapidCount >= Config.MaxRapidReconnects then
                waitPenalty = waitPenalty + (tracker.rapidCount * 3)
            end

            for i = waitPenalty, 1, -1 do
                if GetPlayerPing(src) == 0 then return end
                deferrals.update(string.format("⚠️ Připojuješ se příliš rychle! Vyčkej ještě %ds...", i))
                Wait(1000)
            end
        else
            tracker.rapidCount = 0
        end
        tracker.lastAttempt = os.time()
    else
        ReconnectTracker[primaryId] = { lastAttempt = now, rapidCount = 0 }
    end

    -- Vždy čerstvé načtení bodů z Discordu (obnovení priority po reconnectu)
    local discordData = fetchDiscordPriority(ids.discord)
    local points = discordData.points
    local isReserved = discordData.isReserved

    -- Zápis hráče
    JoinCounter = JoinCounter + 1
    local playerEntry = {
        source = src,
        identifier = primaryId,
        name = playerName,
        points = points,
        isReserved = isReserved,
        joinOrder = JoinCounter, -- Rozhoduje při shodě bodů (žádné předbíhání)
        queueStartTime = os.time(),
        state = "QUEUE"
    }

    -- Zjistíme, zda je rovnou volný slot (a fronta před ním je prázdná)
    sortQueue()
    if #Queue == 0 and canPlayerTakeSlot(isReserved) then
        playerEntry.state = "READY"
        ReservedLocks[primaryId] = {
            expires = os.time() + Config.AutoConnectTimeout + Config.ConnectingLockTimeout,
            isReserved = isReserved
        }
    else
        table.insert(Queue, playerEntry)
        sortQueue()
    end

    local isFinished = false

    local function finishConnection()
        if isFinished then return end
        isFinished = true

        -- Prodloužíme zámek slotu na dobu, než se hráč reálně načte do hry
        ReservedLocks[primaryId] = {
            expires = os.time() + Config.ConnectingLockTimeout,
            isReserved = isReserved
        }

        deferrals.update("Načítání světa, vítej ve hře!")
        Wait(500)
        deferrals.done()
    end

    -- Smyčka aktualizující kartu hráči
    CreateThread(function()
        local countdown = Config.AutoConnectTimeout

        while not isFinished do
            -- Kontrola, zda hráč nezavřel FiveM / neodpojil se z fronty
            if GetPlayerPing(src) == 0 then
                isFinished = true
                removeFromQueue(primaryId)
                ReservedLocks[primaryId] = nil
                processQueue()
                return
            end

            if playerEntry.state == "QUEUE" then
                -- Zkontrolujeme, zda se pro něj neuvolnilo místo
                processQueue()

                local pos = getQueuePosition(primaryId)
                local waitedSeconds = os.time() - playerEntry.queueStartTime
                local card = buildCard("QUEUE", playerEntry.points, pos, #Queue, waitedSeconds)

                if card then
                    deferrals.presentCard(card)
                end

                Wait(1000)
            elseif playerEntry.state == "READY" then
                -- Hráč má volný slot -> zobrazíme tlačítko "Vstoupit do hry" a odpočet
                local card = buildCard("READY", playerEntry.points, 0, #Queue, countdown)

                if card then
                    deferrals.presentCard(card, function(data)
                        if data and data.action == "play" then
                            finishConnection()
                        end
                    end)
                end

                Wait(1000)
                countdown = countdown - 1

                -- Pokud hráč nic neudělá, po vypršení limitu se připojí automaticky
                if countdown <= 0 and not isFinished then
                    finishConnection()
                end
            end
        end
    end)
end)

-- Jakmile se hráč plně připojí na server, uvolníme dočasný zámek (už je započítán v #GetPlayers())
AddEventHandler('playerJoining', function()
    local src = source
    local ids = getIdentifiers(src)
    local primaryId = ids.license or ids.discord or ids.steam
    if primaryId and ReservedLocks[primaryId] then
        ReservedLocks[primaryId] = nil
    end
end)

-- Při odpojení hráče ze serveru uvolníme případný zámek a rovnou posuneme frontu
AddEventHandler('playerDropped', function()
    local src = source
    local ids = getIdentifiers(src)
    local primaryId = ids.license or ids.discord or ids.steam
    if primaryId then
        removeFromQueue(primaryId)
        ReservedLocks[primaryId] = nil
    end
    processQueue()
end)
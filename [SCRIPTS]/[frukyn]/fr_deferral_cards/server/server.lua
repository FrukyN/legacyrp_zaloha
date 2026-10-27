-- Funkce pro generování karty s předaným zbývajícím časem
local function createWelcomeCard(playerName, identifiers, timeLeft)
    local onlinePlayers = #GetPlayers()
    local maxClients = GetConvarInt("sv_maxclients", 64)

    return {
        ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
        ["type"] = "AdaptiveCard",
        ["version"] = "1.3",
        ["body"] = {
            -- 1. Hlavička
            {
                ["type"] = "ColumnSet",
                ["columns"] = {
                    {
                        ["type"] = "Column",
                        ["width"] = "auto",
                        ["items"] = {
                            {
                                ["type"] = "Image",
                                ["url"] = "https://assets.cfx.re/logos/fivem.png", -- Odkaz na tvoje logo
                                ["size"] = "Medium",
                                ["style"] = "Person"
                            }
                        }
                    },
                    {
                        ["type"] = "Column",
                        ["width"] = "stretch",
                        ["verticalContentAlignment"] = "Center",
                        ["items"] = {
                            {
                                ["type"] = "TextBlock",
                                ["text"] = "VÍTEJ V NAŠEM SVĚTĚ",
                                ["weight"] = "Bolder",
                                ["size"] = "Large",
                                ["spacing"] = "None"
                            },
                            {
                                ["type"] = "TextBlock",
                                ["text"] = "Přejeme ti příjemný a nerušený Roleplay, **" .. playerName .. "**!",
                                ["isSubtle"] = true,
                                ["spacing"] = "None"
                            }
                        }
                    }
                }
            },

            -- 2. Dvousloupcový přehled (Stav & Profil)
            {
                ["type"] = "ColumnSet",
                ["separator"] = true,
                ["spacing"] = "Medium",
                ["columns"] = {
                    {
                        ["type"] = "Column",
                        ["width"] = "1",
                        ["items"] = {
                            {
                                ["type"] = "TextBlock",
                                ["text"] = "STAV SERVERU",
                                ["weight"] = "Bolder",
                                ["color"] = "Accent",
                                ["size"] = "Small"
                            },
                            {
                                ["type"] = "FactSet",
                                ["spacing"] = "Small",
                                ["facts"] = {
                                    { ["title"] = "Hráči:", ["value"] = onlinePlayers .. " / " .. maxClients },
                                    { ["title"] = "Server stav:", ["value"] = "🟢 Online" },
                                    { ["title"] = "Automatický vstup:", ["value"] = "za " .. timeLeft .. "s" }
                                }
                            }
                        }
                    },
                    {
                        ["type"] = "Column",
                        ["width"] = "1",
                        ["items"] = {
                            {
                                ["type"] = "TextBlock",
                                ["text"] = "TVOJE IDENTIFIKACE",
                                ["weight"] = "Bolder",
                                ["color"] = "Accent",
                                ["size"] = "Small"
                            },
                            {
                                ["type"] = "FactSet",
                                ["spacing"] = "Small",
                                ["facts"] = {
                                    { ["title"] = "Discord:", ["value"] = identifiers.discord and ("<@" .. identifiers.discord .. ">") or "Nepropojeno" },
                                    { ["title"] = "Steam:", ["value"] = identifiers.steam and "Propojeno" or "Nepropojeno" },
                                    { ["title"] = "FiveM ID:", ["value"] = identifiers.fivem or "Nenalezeno" }
                                }
                            }
                        }
                    }
                }
            },

            -- 3. Krátký boxík
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["spacing"] = "Medium",
                ["items"] = {
                    {
                        ["type"] = "TextBlock",
                        ["text"] = "📢 Novinky a oznámení",
                        ["weight"] = "Bolder"
                    },
                    {
                        ["type"] = "TextBlock",
                        ["text"] = "Proběhla aktualizace herních systémů. Pokud narazíš na jakýkoli problém, neváhej kontaktovat náš support tým na Discordu.",
                        ["wrap"] = true,
                        ["isSubtle"] = true,
                        ["spacing"] = "Small"
                    }
                }
            }
        },

        -- 4. Tlačítka (tlačítko vstupu dynamicky ukazuje zbývající čas)
        ["actions"] = {
            {
                ["type"] = "Action.Submit",
                ["title"] = "🚀 Vstoupit do hry (" .. timeLeft .. "s)",
                ["style"] = "positive",
                ["data"] = {
                    ["action"] = "play"
                }
            },
            {
                ["type"] = "Action.OpenUrl",
                ["title"] = "🌐 Web",
                ["url"] = "https://google.com"
            },
            {
                ["type"] = "Action.OpenUrl",
                ["title"] = "💬 Discord",
                ["url"] = "https://discord.gg/fivem"
            },
            {
                ["type"] = "Action.OpenUrl",
                ["title"] = "📜 Pravidla",
                ["url"] = "https://google.com"
            }
        }
    }
end

-- Obsluha připojení
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    Wait(250)
    deferrals.update("Připravuji přehled serveru...")

    -- Vytáhneme identifikátory
    local ids = {}
    for _, rawId in ipairs(GetPlayerIdentifiers(src)) do
        local prefix, val = string.match(rawId, "([^:]+):(.+)")
        if prefix and val then
            ids[prefix] = val
        end
    end

    local isDone = false
    local countdown = 10 -- Počet vteřin, než hráče pustíme automaticky

    -- Pomocná funkce pro vpuštění hráče (aby se nevolala 2x)
    local function finishConnection(reason)
        if isDone then return end
        isDone = true

        deferrals.update("Načítání světa, vítej ve hře!")
        Wait(800)
        deferrals.done()
    end

    -- Vlákno s odpočtem
    CreateThread(function()
        while countdown > 0 and not isDone do
            -- Zobrazíme/aktualizujeme kartu s novým časem
            local card = createWelcomeCard(playerName, ids, countdown)
            
            deferrals.presentCard(card, function(data, rawData)
                if data and data.action == "play" then
                    finishConnection("clicked")
                end
            end)

            Wait(1000)
            countdown = countdown - 1
        end

        -- Čas vypršel a hráč ještě nekliknul
        if not isDone then
            finishConnection("timeout")
        end
    end)
end)
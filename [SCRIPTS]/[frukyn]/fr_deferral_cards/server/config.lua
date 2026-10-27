Config = {}

-- Nastavení Discord API (pro čerstvé načítání rolí při každém připojení)
Config.Discord = {
    GuildId = "TVOJE_GUILD_ID",       -- ID tvého Discord serveru
    BotToken = "TVUJ_DISCORD_TOKEN",  -- Token tvého Discord bota (musí být na serveru)
    RequireDiscord = true             -- Vyžadovat zapnutý Discord pro připojení?
}

-- Nastavení slotů a časovačů
Config.ReservedSlots = 4              -- Počet slotů vyhrazených pouze pro hráče s isReserved = true
Config.AutoConnectTimeout = 10        -- Počet vteřin na stisknutí tlačítka "Vstoupit do hry", než systém hráče připojí sám
Config.ConnectingLockTimeout = 90     -- Jak dlouho (v s) držet slot hráči, který už prošel frontou a načítá do hry
Config.ReconnectCooldown = 5          -- Ochrana proti spamování připojení (vteřiny mezi pokusy o reconnect)
Config.MaxRapidReconnects = 3         -- Po kolika rychlých reconnectech po sobě dostane hráč penalizaci

-- Stackování priorit podle Discord rolí
-- Hráči se sečtou body ze VŠECH rolí, které na Discordu má.
-- Pokud má alespoň jedna jeho role "isReserved = true", může využít rezervované sloty.
Config.Roles = {
    ["111111111111111111"] = { name = "Majitel / Vedení", points = 1000, isReserved = true },
    ["222222222222222222"] = { name = "Admin",            points = 500,  isReserved = true },
    ["333333333333333333"] = { name = "Support",          points = 250,  isReserved = true },
    ["444444444444444444"] = { name = "VIP Diamond",      points = 100,  isReserved = false },
    ["555555555555555555"] = { name = "VIP Gold",         points = 50,   isReserved = false },
    ["666666666666666666"] = { name = "Server Booster",   points = 25,   isReserved = false },
    ["777777777777777777"] = { name = "Whitelist",        points = 10,   isReserved = false },
}

-- Odkazy na tlačítka v kartě
Config.Links = {
    Web = "https://google.com",
    Shop = "https://snipe.tebex.io/"
}
Config = {}

Config.Discord = {
    GuildId = "918973469725708359",
    BotToken = GetConvar('fr_discord_token', ''),
    RequireDiscord = true
}

Config.ReservedSlots = 2          -- Počet slotů vyhrazených pouze pro hráče s isReserved = true
Config.AutoConnectTimeout = 10    -- Počet vteřin na stisknutí tlačítka "Vstoupit do hry", než systém hráče připojí sám
Config.ConnectingLockTimeout = 90 -- Jak dlouho (v s) držet slot hráči, který už prošel frontou a načítá do hry
Config.ReconnectCooldown = 5      -- Ochrana proti spamování připojení (vteřiny mezi pokusy o reconnect)
Config.MaxRapidReconnects = 3     -- Po kolika rychlých reconnectech po sobě dostane hráč penalizaci

Config.Roles = {
    ["976922481199837255"] = { name = "Majitel / Vedení", points = 1000, isReserved = true },
    --   ["222222222222222222"] = { name = "Admin",            points = 500,  isReserved = true },
    --  ["333333333333333333"] = { name = "Support",          points = 250,  isReserved = true },
    --  ["444444444444444444"] = { name = "VIP Diamond",      points = 100,  isReserved = false },
    --  ["555555555555555555"] = { name = "VIP Gold",         points = 50,   isReserved = false },
    --  ["666666666666666666"] = { name = "Server Booster",   points = 25,   isReserved = false },
    --  ["777777777777777777"] = { name = "Whitelist",        points = 10,   isReserved = false },
}

Config.Links = {
    Web = "https://google.com",
    Shop = "https://google.com"
}

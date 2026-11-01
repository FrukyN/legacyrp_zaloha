Config = {}

Config.KeyItem = 'carkey'
Config.LockpickItem = 'lockpick'

Config.LockKeybind = 'U'      -- Klávesa na zamknutí/odemknutí
Config.EngineKeybind = 'G'    -- Klávesa na vypnutí/zapnutí motoru
Config.LockDistance = 8.0     -- Dosah dálkového ovládání klíče

Config.Lockpick = {
    BreakChance = 35, -- % šance na zlomení šperháku při neúspěchu
    OutsideDifficulty = {'easy', 'medium', 'medium'},
    HotwireDifficulty = {'medium', 'medium', 'hard'}
}

-- Zámečník pro kopírování klíčů
Config.Keysmith = {
    Coords = vec4(170.12, -1799.45, 29.32, 320.0), -- Uprav podle sebe
    Model = `s_m_m_autoshop_02`,
    Price = 500
}

Config.NPCLock = {
    Enabled = true,
    LockParkedChance = 100,  -- % šance, že zaparkované NPC auto bude zamčené (100 = vždy)
    LockDrivenChance = 100,  -- % šance, že jedoucí NPC auto bude zamčené (zabrání vytažení řidiče bez vypáčení)
    IgnoreModels = {         -- Modely, které se nikdy nezamknou (např. kola, čtyřkolky, lodě)
        [`bmx`] = true,
        [`cruiser`] = true,
        [`fixter`] = true,
        [`scorcher`] = true,
        [`tribike`] = true,
        [`tribike2`] = true,
        [`tribike3`] = true,
        [`blazer`] = true,
    }
}
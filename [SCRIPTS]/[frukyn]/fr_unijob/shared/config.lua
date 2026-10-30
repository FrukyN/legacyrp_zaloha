Config = {}

Config.Items = {
    Cuffs = 'handcuffs',      -- Item pro spoutání
    Key = 'handcuff_key'      -- Item pro odemknutí pout
}

Config.Jobs = {
    ['police'] = {
        label = 'Policie',
        canCuff = true,       -- Povolí této frakci poutat a dávat do vozidla
        blip = {
            enabled = true,
            coords = vec3(425.1, -979.5, 30.7),
            sprite = 60,
            scale = 0.8,
            dynamic = true,      -- Bude měnit barvu podle počtu lidí
            minOnline = 1,       -- Od kolika lidí zezelená
            offlineColor = 39,   -- Šedá (mimo provoz)
            onlineColor = 2      -- Zelená (aktivní)
        },
        duty = {
            vec3(441.79, -982.07, 30.69)
        },
        wardrobes = {
            vec3(450.12, -990.51, 30.69)
        },
        alarms = {
            vec3(440.10, -975.80, 30.69)
        },
        bossmenu = {
            coords = vec3(448.4, -973.2, 30.6),
            minGrade = 3
        },
        stashes = {
            {
                id = 'police_armory',
                label = 'Policejní zbrojnice (Frakční)',
                coords = vec3(452.30, -980.10, 30.69),
                slots = 100,
                weight = 500000,
                shared = true,  -- Frakční sklad (vidí všichni s přístupem)
                minGrade = 1    -- Minimální hodnost pro otevření
            },
            {
                id = 'police_locker',
                label = 'Osobní skříňka',
                coords = vec3(455.00, -985.20, 30.69),
                slots = 30,
                weight = 50000,
                shared = false, -- Osobní sklad (každý policista má svůj vlastní prostor)
                minGrade = 1
            }
        }
    },

    ['bennys'] = {
        label = 'Bennys Mechanici',
        canCuff = false,
        duty = {
            vec3(-205.50, -1310.10, 31.29)
        },
        wardrobes = {
            vec3(-210.15, -1320.40, 31.29)
        },
        alarms = {
            vec3(-198.20, -1315.50, 31.29)
        },
        bossmenu = {
            coords = vec3(448.4, -973.2, 30.6),
            minGrade = 3
        },
        stashes = {
            {
                id = 'bennys_shared',
                label = 'Sklad dílů',
                coords = vec3(-215.30, -1318.90, 31.29),
                slots = 80,
                weight = 300000,
                shared = true,
                minGrade = 1
            }
        }
    }
}
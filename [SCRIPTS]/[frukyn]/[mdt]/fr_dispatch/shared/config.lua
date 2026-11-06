Config = {}

Config.Debug = false

-- Frakce, které přijímají dispatch hlášení a mají přístup k systému
Config.EmergencyJobs = {
    ['police'] = true,
    ['lspd'] = true,
    ['sheriff'] = true,
    ['bcso'] = true,
    ['sasp'] = true,
    ['ambulance'] = true,
    ['ems'] = true,
}

-- Práce, které vidí zdravotnické výzvy (155, 10-14 atd.)
Config.MedicJobs = {
    ['ambulance'] = true,
    ['ems'] = true,
}

-- Klávesová zkratka pro rychlé nastavení GPS na poslední hovor
Config.QuickRespondKey = 'G'

-- Doba trvání zobrazení notifikace na obrazovce (v ms)
Config.NotificationDuration = 8000

-- Doba zobrazení blipu na mapě (v sekundách)
Config.BlipDuration = 60

-- Synchronizace live GPS jednotek (policie/EMS) na mapě
Config.LiveUnitBlips = true
Config.LiveBlipInterval = 3000 -- v ms

-- Ignorované zbraně pro hlášení střelby (tlumiče, paintball, taser, sněhové koule apod.)
Config.IgnoredWeapons = {
    `WEAPON_STUNGUN`,
    `WEAPON_SNOWBALL`,
    `WEAPON_BALL`,
    `WEAPON_FLARE`,
    `WEAPON_FIREEXTINGUISHER`,
    `WEAPON_PETROLCAN`,
    `WEAPON_HAZARDCAN`
}

-- Cooldowny pro detektory na klientovi (proti spamu hlášení)
Config.Cooldowns = {
    gunshot = 4000,       -- 4 sekundy mezi hlášením střelby ze stejné zbraně
    vehicleTheft = 15000, -- 15 sekund mezi hlášením krádeže stejného auta
    speeding = 20000,     -- 20 sekund mezi hlášením rychlosti
}

-- Typy hlášení (10-kódy a šablony)
Config.Alerts = {
    ['shots_fired'] = {
        code = '10-71',
        title = 'Střelba na veřejnosti',
        icon = 'fa-solid fa-person-rifle',
        color = '#e74c3c',
        blip = { sprite = 110, color = 1, scale = 1.0, radius = 50.0 },
        sound = 'gunshot',
        priority = 2
    },
    ['shots_fired_vehicle'] = {
        code = '10-71',
        title = 'Střelba z vozidla',
        icon = 'fa-solid fa-car-burst',
        color = '#e74c3c',
        blip = { sprite = 110, color = 1, scale = 1.1, radius = 60.0 },
        sound = 'gunshot',
        priority = 2
    },
    ['vehicle_theft'] = {
        code = '10-60',
        title = 'Krádež vozidla',
        icon = 'fa-solid fa-key',
        color = '#e67e22',
        blip = { sprite = 225, color = 47, scale = 0.9, radius = 40.0 },
        sound = 'vehicle_theft',
        priority = 1
    },
    ['officer_down'] = {
        code = '10-13',
        title = 'DŮSTOJNÍK V BEZVĚDOMÍ',
        icon = 'fa-solid fa-user-injured',
        color = '#c0392b',
        blip = { sprite = 303, color = 75, scale = 1.3, flash = true },
        sound = 'officer_down',
        priority = 3
    },
    ['panic_button'] = {
        code = '10-99',
        title = 'TÍSŇOVÉ TLAČÍTKO (PANIC)',
        icon = 'fa-solid fa-triangle-exclamation',
        color = '#ff0055',
        blip = { sprite = 161, color = 76, scale = 1.4, flash = true },
        sound = 'panic',
        priority = 3
    },
    ['silent_alarm'] = {
        code = '10-31',
        title = 'Tichý poplach objektu',
        icon = 'fa-solid fa-bell',
        color = '#9b59b6',
        blip = { sprite = 161, color = 27, scale = 1.1, flash = true },
        sound = 'alarm',
        priority = 3
    },
    ['car_crash'] = {
        code = '10-50',
        title = 'Vážná dopravní nehoda',
        icon = 'fa-solid fa-car-crash',
        color = '#3498db',
        blip = { sprite = 380, color = 3, scale = 0.9 },
        sound = 'accident',
        priority = 1
    },
    ['speeding'] = {
        code = '10-43',
        title = 'Nebezpečná rychlá jízda',
        icon = 'fa-solid fa-gauge-high',
        color = '#f1c40f',
        blip = { sprite = 227, color = 5, scale = 0.8 },
        sound = 'blip',
        priority = 1
    },
    ['citizen_call'] = {
        code = '158',
        title = 'Tísňové volání (Policie)',
        icon = 'fa-solid fa-phone',
        color = '#2ecc71',
        blip = { sprite = 480, color = 2, scale = 1.0 },
        sound = 'call',
        priority = 2
    },
    ['medic_call'] = {
        code = '155',
        title = 'Tísňové volání (Záchranka)',
        icon = 'fa-solid fa-heart-pulse',
        color = '#e84393',
        blip = { sprite = 153, color = 8, scale = 1.0 },
        sound = 'medic',
        priority = 2
    }
}

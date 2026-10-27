Config = Config or {}

Config.baseSlots = 1
Config.defaultOrigin = 'immigrant'
Config.newCharacterSpawn = vec3(243.7077, -880.3877, 30.4919)
Config.newCharacterHeading = 301.7720

Config.preview = {
    -- Postava stojí v chodbě před kamerou a dívá se směrem do kamery (heading 56.74)
    pedCoords = vec4(-1569.2500, -3227.5200, 26.3362, 56.7415),
    cameraPos = vec3(-1571.3068, -3226.1580, 26.3362),
    cameraLookAt = vec3(-1569.2500, -3227.5200, 26.3362)
}

Config.slotUnlocks = {
    -- Example: Discord role IDs can unlock additional slots.
    -- { role = '123456789012345678', slots = 2 },
}

Config.origins = {
    immigrant = {
        label = 'Přistěhovalec',
        startMoney = 2500,
        description = 'Výchozí start na LSIA s balíčkem základních věcí.',
        items = {
            { name = 'water', count = 2 },
            { name = 'sandwich', count = 1 },
        },
        spawn = vec3(-1035.06, -2735.42, 20.16),
        heading = 130.0,
    },
    resident = {
        label = 'Místní',
        startMoney = 3500,
        description = 'Start v místním prostředí, krátkodobý motel a základní dokumenty.',
        items = {
            { name = 'id_card', count = 1 },
            { name = 'driver_license', count = 1 },
            { name = 'water', count = 1 },
        },
        spawn = vec3(246.0897, -883.0647, 30.4921),
        heading = 20.7808,
    }
}
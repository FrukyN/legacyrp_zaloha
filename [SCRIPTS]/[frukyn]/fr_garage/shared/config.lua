Config = {}

Config.Debug = false
Config.KeyItem = 'vehicle_key'
Config.KeyShareSeconds = 3600
Config.InteractKey = 38 -- E
Config.SaveInterval = 30000
Config.MileageInterval = 15000
Config.SpawnClearance = 3.0
Config.DefaultFuel = 100.0
Config.DefaultGarage = 'legion'
Config.FactionManagerGrade = { police = 4 }
Config.FuelResource = 'fr_fuel'

Config.Fuel = {
    get = function(vehicle)
        local state = Entity(vehicle).state
        return tonumber(state.fuel) or GetVehicleFuelLevel(vehicle)
    end,
    set = function(vehicle, value, fuelType, dirtyFuel)
        value = value + 0.0
        SetVehicleFuelLevel(vehicle, value)

        local state = Entity(vehicle).state
        state:set('fuel', value, true)

        if fuelType and fuelType ~= '' then
            state:set('fr_tankFuelType', fuelType, true)
        end

        if dirtyFuel ~= nil then
            state:set('fr_wrongFuel', dirtyFuel == true or dirtyFuel == 1, true)
        end
    end,
    getType = function(vehicle) return Entity(vehicle).state.fr_tankFuelType end,
    getDirty = function(vehicle) return Entity(vehicle).state.fr_wrongFuel == true end,
}

Config.Housing = { enabled = false }

Config.Impound = {
    moneyItem = 'money',
    storeName = 'impound',
    releaseGarage = 'legion',
    releaseJob = { police = 0 },
    towJobs = { mechanic = 0, police = 0 },
    blockJobs = { police = 0 },
    feesByClass = { [0]=500, [1]=750, [2]=1000, [3]=750, [4]=750, [5]=1000, [6]=1250, [7]=2500, [8]=400, [9]=1000, [10]=1500, [11]=1000, [12]=1000, [13]=250, [14]=1500, [15]=2500, [16]=3000, [17]=750, [18]=1000, [19]=2500, [20]=1500, [21]=1000 },
    feePerDay = 250,
}

Config.Garages = {
    legion = {
        label = 'Legion Square Garáž',
        type = 'car',
        kind = 'public',
        coords = vec3(215.8, -810.1, 30.7),
        radius = 5.0,
        blip = { id = 357, color = 3, scale = 0.7 },
        spawns = { vec4(229.7, -800.1, 30.6, 157.0), vec4(233.0, -801.3, 30.5, 157.0), vec4(236.4, -802.7, 30.4, 157.0) }
    },
    marina = {
        label = 'Přístav',
        type = 'boat',
        kind = 'public',
        coords = vec3(-806.2, -1496.7, 1.6),
        radius = 8.0,
        blip = { id = 427, color = 3, scale = 0.7 },
        spawns = { vec4(-802.0, -1503.0, 0.2, 110.0), vec4(-796.0, -1505.0, 0.2, 110.0) }
    },
    airport = {
        label = 'Letiště Hangar',
        type = 'air',
        kind = 'public',
        coords = vec3(-970.0, -2995.0, 13.9),
        radius = 12.0,
        blip = { id = 359, color = 3, scale = 0.7 },
        spawns = { vec4(-979.0, -2990.0, 13.9, 60.0), vec4(-988.0, -2985.0, 13.9, 60.0) }
    },
    police = {
        label = 'Policejní garáž',
        type = 'car',
        kind = 'faction',
        group = 'police',
        coords = vec3(454.6, -1017.4, 28.4),
        radius = 6.0,
        blip = { id = 357, color = 38, scale = 0.7 },
        spawns = { vec4(438.4, -1018.3, 27.7, 90.0), vec4(438.4, -1022.0, 27.7, 90.0) }
    },
    hayes = {
        label = 'hayes Garáž',
        type = 'car',
        kind = 'faction',
        group = 'hayes',
        coords = vec3(493.2413, -1330.7740, 29.0323),
        radius = 6.0,
        blip = { id = 357, color = 38, scale = 0.7 },
        spawns = { vec4(493.2413, -1330.7740, 29.0323, 90.0), vec4(493.2413, -1330.7740, 29.0323, 90.0) }
    },
}

Config.Locale = {
    garage = 'Garáž',
    store = 'Zaparkovat vozidlo',
    impound = 'Zabavit vozidlo',
    noVehicle = 'Nejsi ve vozidle.',
    noKey = 'Nemáš klíč od tohoto vozidla.',
    noSpawn = 'Všechny výjezdy jsou obsazené.',
    impounded = 'Vozidlo je v impoundu.',
}
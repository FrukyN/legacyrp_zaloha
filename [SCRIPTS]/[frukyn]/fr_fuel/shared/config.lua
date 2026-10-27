Config = {}

Config.Debug = false
Config.DefaultFuelType = 'gasoline'
Config.TargetDistance = 2.0
Config.VehicleDistance = 4.5

Config.RefillTick = 350
Config.RefillValue = 0.75

Config.PriceUpdateMinutes = 30
Config.DefaultVolatility = 0.06

Config.Prepay = {
    minUnits = 5,
    maxUnits = 100,
    defaultUnits = 25,
    refundUnused = true
}

Config.WrongFuelDamage = {
    enabled = true,
    engineHealth = 120.0,
    petrolTankHealth = 100.0,
    bodyHealth = 650.0,
    driveBlockSeconds = 45
}

Config.Hose = {
    enabled = true,
    nozzleModel = `prop_cs_fuel_nozle`,
    length = 5.5
}

Config.PaymentMethods = {
    bank = {
        label = 'Banka',
        icon = 'credit-card'
    },
    cash = {
        label = 'Hotovost',
        icon = 'money-bill'
    }
}

Config.StationTypes = {
    pump = {
        label = 'Pumpa',
        fuels = { 'gasoline', 'diesel' }
    },
    charger = {
        label = 'Nabijecka',
        fuels = { 'electric' }
    }
}

Config.FuelTypes = {
    gasoline = {
        label = 'Benzin',
        short = 'N95',
        icon = 'gas-pump',
        price = 12.0,
        minPrice = 9.0,
        maxPrice = 17.0,
        volatility = 0.06
    },
    diesel = {
        label = 'Diesel',
        short = 'D',
        icon = 'truck',
        price = 13.5,
        minPrice = 10.0,
        maxPrice = 18.5,
        volatility = 0.05
    },
    electric = {
        label = 'Elektrina',
        short = 'kWh',
        icon = 'bolt',
        price = 7.5,
        minPrice = 5.0,
        maxPrice = 12.0,
        volatility = 0.08
    }
}

Config.PumpModels = {
    `prop_gas_pump_old2`,
    `prop_gas_pump_1a`,
    `prop_vintage_pump`,
    `prop_gas_pump_old3`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1d`
}

-- Charging is available only at these props. Replace/add your streamed charger model.
Config.ChargerModels = {
    `electric_charger`,
    `prop_electric_charger`
}

Config.ElectricModels = {
    'airtug',
    'caddy',
    'caddy2',
    'caddy3',
    'cyclone',
    'cyclone2',
    'dilettante',
    'imorgon',
    'iwagen',
    'khamelion',
    'neon',
    'omnisegt',
    'raiden',
    'surge',
    'tezeract',
    'virtue',
    'voltic',
    'voltic2'
}

Config.DieselModels = {
    'benson',
    'biff',
    'bus',
    'coach',
    'hauler',
    'hauler2',
    'mule',
    'mule2',
    'mule3',
    'mule4',
    'mule5',
    'packer',
    'phantom',
    'phantom2',
    'phantom3',
    'pounder',
    'pounder2',
    'rentalbus',
    'rubble',
    'tiptruck',
    'tiptruck2',
    'trash',
    'trash2'
}

-- Client-only fallback when a model is not listed above.
-- 10 industrial, 11 utility, 12 vans, 17 service, 20 commercial.
Config.DieselVehicleClasses = {
    [10] = true,
    [11] = true,
    [12] = true,
    [17] = true,
    [20] = true
}


-- ===============================
-- SPOTŘEBA A KANYSTR (z ox_fuel)
-- ===============================
Config.GlobalFuelConsumptionRate = 10.0 -- Násobič spotřeby GTA V

Config.PetrolCan = {
    enabled = true,
    price = 1000,          -- Cena za koupi plného kanystru
    refillPrice = 800,     -- Cena za doplnění stávajícího kanystru
    duration = 5000,       -- Doba plnění kanystru na pumpě (ms)
    durabilityTick = 1.3,  -- Kolik % durability kanystru se odečte za tick
    refillValue = 0.5,     -- Kolik % nádrže doplní kanystr za tick
    refillTick = 250       -- Interval dolévání vozidla (ms)
}

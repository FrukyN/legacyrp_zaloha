Config = {}

Config.Debug = false
Config.MaxNeed = 100
Config.SaveInterval = 120000
Config.ServerTick = 10000
Config.SpoilageCheckInterval = 300000
Config.ConsumptionCooldownMs = 1200
Config.MaxInvalidAttempts = 3
Config.UsePromptTimeoutMs = 12000

Config.Defaults = { hunger = 15, thirst = 15, stress = 15, alcohol = 0, drug = 0 }
Config.OxStatuses = {
    hunger = { default = Config.Defaults.hunger, onTick = 0.02 },
    thirst = { default = Config.Defaults.thirst, onTick = 0.05 },
    stress = { default = Config.Defaults.stress, onTick = -0.10 },
    alcohol = { default = Config.Defaults.alcohol, onTick = -0.02 },
    drug = { default = Config.Defaults.drug, onTick = -0.02 }
}
Config.Starvation = { hungerThreshold = 90, thirstThreshold = 90, stressPerTick = 2, damageEveryMs = 12000, damage = 4, blackoutChance = 6 }
Config.Stress = { highThreshold = 70, shakeThreshold = 85, blurDurationMs = 3000 }
Config.Withdrawal = { threshold = 15, stressPerTick = 2, stumbleChance = 8 }

Config.TargetDrinkStations = {
    { coords = vec3(441.2, -982.0, 30.7), radius = 0.9, label = 'Napit se vody', icon = 'fa-solid fa-glass-water', thirstGain = 12, stressRelief = 2 }
}

Config.Items = {
    water = {
        type = 'drink', remove = true, uses = 1,
        denyInVehicle = false, denyWhileSwimming = true, denyWhileSprinting = false,
        spoilage = { enabled = false },
        thirst = 23, hunger = 0, stress = -1, alcohol = 0, drug = 0
    },
    bread = {
        type = 'food', remove = true, uses = 2,
        denyInVehicle = true, denyWhileSwimming = true, denyWhileSprinting = true,
        spoilage = { enabled = true, hours = 48, onSpoil = { action = 'replace', item = 'spoiled_food', count = 1 } },
        hunger = 22, thirst = 0, stress = -1, alcohol = 0, drug = 0
    },
    beer = {
        type = 'drink', remove = true, uses = 1,
        denyInVehicle = false, denyWhileSwimming = true, denyWhileSprinting = false,
        spoilage = { enabled = false },
        thirst = 12, hunger = 0, stress = -3, alcohol = 7, drug = 0
    },
    beer_crate = {
        type = 'utility', remove = true, uses = 1,
        denyInVehicle = true, denyWhileSwimming = true, denyWhileSprinting = true,
        spoilage = { enabled = false },
        hunger = 0, thirst = 0, stress = 0, alcohol = 0, drug = 0,
        giveItems = { { name = 'beer', count = 10 } }
    },
    joint = {
        type = 'drug', remove = true, uses = 3,
        denyInVehicle = false, denyWhileSwimming = true, denyWhileSprinting = true,
        spoilage = { enabled = true, hours = 72, onSpoil = { action = 'delete' } },
        thirst = -2, hunger = 1, stress = -5, alcohol = 0, drug = 8
    }
}

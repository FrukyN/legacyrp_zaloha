Config = {}
Config.MaxTheoryErrors = 2
Config.MaxDriveErrors = 3
Config.SpeedLimit = 50.0

Config.Location = vec3(223.2037, 373.0146, 106.3730)
Config.PedHeading = 75.0
Config.PedModel = 'ig_paper'
Config.VehicleSpawn = vector4(219.39, 381.71, 106.94, 165.31)

Config.Licenses = {
    ['A'] = {
        label = 'Skupina A (Motocykl)',
        price = 250, -- JINÁ CENA
        vehicle = 'sanchez',
        theory = {
            {
                question = "Jaká je maximální povolená rychlost v obci?",
                answers = { "50 km/h", "70 km/h", "90 km/h" },
                correct = 0
            },
            {
                question = "Kdo má přednost na křižovatce bez dopravního značení?",
                answers = { "Vozidlo jedoucí rychleji", "Vozidlo přijíždějící zprava", "Vozidlo přijíždějící zleva" },
                correct = 1
            }
        },
        route = {
            { coords = vec3(216.0, -1390.0, 30.5), msg = "Pokračujte opatrně, dodržujte rychlost." }
        }
    },
    ['B'] = {
        label = 'Skupina B (Osobní automobil)',
        price = 500, -- CENA TESTU
        vehicle = 'blista',
        theory = {
            {
                question = "Jaká je maximální povolená rychlost v obci?",
                answers = { "50 km/h", "70 km/h", "90 km/h" },
                correct = 0
            },
            {
                question = "Kdo má přednost na křižovatce bez dopravního značení?",
                answers = { "Vozidlo jedoucí rychleji", "Vozidlo přijíždějící zprava", "Vozidlo přijíždějící zleva" },
                correct = 1
            }
        },
        route = {
            { coords = vec3(216.4300, 371.9668, 105.9375), msg = "Pokračujte rovně, dodržujte rychlost." },
            --   { coords = vec3(170.0, -1450.0, 29.0), msg = "Na další křižovatce odbočte vpravo." }
        }
    },
}

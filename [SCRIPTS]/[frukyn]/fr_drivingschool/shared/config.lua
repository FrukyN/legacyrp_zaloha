Config = {}
Config.MaxTheoryErrors = 2
Config.MaxDriveErrors = 3
Config.SpeedLimit = 50.0

-- LOKACE AUTOŠKOLY
Config.Location = vec3(239.4, -1380.8, 33.7)
Config.PedHeading = 140.0
Config.PedModel = 'ig_paper' 
Config.VehicleSpawn = vector4(249.5, -1390.0, 30.5, 140.0)

Config.Licenses = {
    ['B'] = {
        label = 'Skupina B (Osobní automobil)',
        price = 500, -- CENA TESTU
        vehicle = 'blista',
        theory = {
            {
                question = "Jaká je maximální povolená rychlost v obci?",
                answers = {"50 km/h", "70 km/h", "90 km/h"},
                correct = 0 
            },
            {
                question = "Kdo má přednost na křižovatce bez dopravního značení?",
                answers = {"Vozidlo jedoucí rychleji", "Vozidlo přijíždějící zprava", "Vozidlo přijíždějící zleva"},
                correct = 1
            }
        },
        route = {
            { coords = vec3(216.0, -1390.0, 30.5), msg = "Pokračujte rovně, dodržujte rychlost." },
         --   { coords = vec3(170.0, -1450.0, 29.0), msg = "Na další křižovatce odbočte vpravo." }
        }
    },
    ['A'] = {
        label = 'Skupina A (Motocykl)',
        price = 250, -- JINÁ CENA
        vehicle = 'sanchez',
        theory = {
            {
                question = "Musí mít řidič motocyklu za jízdy ochrannou přilbu?",
                answers = {"Ne, pokud jede pomalu", "Ano, je to povinné", "Pouze na dálnici"},
                correct = 1 
            }
        },
        route = {
            { coords = vec3(216.0, -1390.0, 30.5), msg = "Pokračujte opatrně, dodržujte rychlost." }
        }
    }
}
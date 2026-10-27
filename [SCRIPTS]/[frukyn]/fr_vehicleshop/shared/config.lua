Config = {}

Config.Locale = 'cs'
Config.Debug = false

Config.EnableBanOnExploit = true
Config.ExploitStrikeLimit = 3
Config.ExploitStrikeWindowSeconds = 120

Config.TestDriveSeconds = 90
Config.TestDriveCooldownSeconds = 300

Config.RequireJobForSocietyPurchase = true
Config.AllowSocietyPurchaseWithoutBoss = false

Config.PlateFormat = 'CW%04d'
Config.MaxOwnedVehiclesPerPlayer = 30

Config.DefaultGarageName = 'A'
Config.StoreInGarageIfBlocked = true

Config.ColorOptions = {
    { label = 'Bílá',     primary = 111, secondary = 111 },
    { label = 'Černá',    primary = 0,   secondary = 0 },
    { label = 'Červená',  primary = 27,  secondary = 27 },
    { label = 'Modrá',    primary = 64,  secondary = 64 },
    { label = 'Stříbrná', primary = 4,   secondary = 4 }
}

Config.KeysExport = {
    enabled = false,
    resource = 'mykeys',
    export = 'GiveVehicleKeys'
}

Config.Shops = {
    pdm = {
        label = 'Premium Deluxe Motorsport',
        licenseRequired = false,
        allowSociety = true,
        societyJobs = {},
        categories = {
            { key = 'albany',      label = 'Albany'},
            { key = 'annis',       label = 'Annis' },
            { key = 'benefactor',  label = 'Benefactor' },
            { key = 'bf',          label = 'BF' },
            { key = 'bollokan',    label = 'Bollokan' },
            { key = 'bravado',     label = 'Bravado' },
            { key = 'brute',       label = 'Brute' },
            { key = 'canis',       label = 'Canis' },
            { key = 'cheval',      label = 'Cheval' },
            { key = 'classique',   label = 'Classique' },
            { key = 'coil',        label = 'Coil' },
            { key = 'declasse',    label = 'Declasse' },
            { key = 'dewbauchee',  label = 'Dewbauchee' },
            { key = 'dinka',       label = 'Dinka' },
            { key = 'dundreary',   label = 'Dundreary' },
            { key = 'emperor',     label = 'Emperor' },
            { key = 'enus',        label = 'Enus' },
            { key = 'fathom',      label = 'Fathom' },
            { key = 'gallivanter', label = 'Gallivanter' },
            { key = 'grotti',      label = 'Grotti' },
            { key = 'hijak',       label = 'Hijak' },
            { key = 'hvy',         label = 'HVY' },
            { key = 'imponte',     label = 'Imponte' },
            { key = 'invetero',    label = 'Invetero' },
            { key = 'jobuilt',     label = 'Jobuilt' },
            { key = 'karin',       label = 'Karin' },
            { key = 'lampadati',   label = 'Lampadati' },
            { key = 'maibatsu',    label = 'Maibatsu' },
            { key = 'mammoth',     label = 'Mammoth' },
            { key = 'maxwell',     label = 'Maxwell' },
            { key = 'mtl',         label = 'MTL' },
            { key = 'nagasaki',    label = 'Nagasaki' },
            { key = 'obey',        label = 'Obey' },
            { key = 'ocelot',      label = 'Ocelot' },
            { key = 'overflod',    label = 'Overflod' },
            { key = 'pegassi',     label = 'Pegassi' },
            { key = 'penaud',      label = 'Penaud' },
            { key = 'pfister',     label = 'Pfister' },
            { key = 'principe',    label = 'Principe' },
            { key = 'progen',      label = 'Progen' },
            { key = 'rune',        label = 'RUNE' },
            { key = 'schyster',    label = 'Schyster' },
            { key = 'shitzu',      label = 'Shitzu' },
            { key = 'stanley',     label = 'Stanley' },
            { key = 'toundra',     label = 'Toundra' },
            { key = 'truffade',    label = 'Truffade' },
            { key = 'ubermacht',   label = 'Ubermacht' },
            { key = 'vapid',       label = 'Vapid' },
            { key = 'vulcar',      label = 'Vulcar' },
            { key = 'vysser',      label = 'Vysser' },
            { key = 'weeny',       label = 'Weeny' },
            { key = 'western',     label = 'Western' },
            { key = 'willard',     label = 'Willard' },
            { key = 'zirconium',   label = 'Zirconium' }
        },

        blip = {
            enabled = true,
            coords = vec3(-56.6, -1096.6, 26.4),
            sprite = 326,
            color = 3,
            scale = 0.8
        },
        npc = {
            model = 's_m_m_autoshop_01',
            coords = vec4(-56.6, -1096.6, 26.4, 28.0),
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        showroom = {
            previewCoords = vec4(-44.2, -1098.9, 26.4, 70.0),
            camCoords = vec3(-40.8, -1095.7, 27.6),
            spawnCoords = vec4(-28.5, -1084.2, 26.2, 70.0),
            fallbackGarage = 'PDM',
            testDrive = {
                enabled = true,
                spawnCoords = vec4(-970.7, -3356.5, 13.9, 60.0),
                returnCoords = vec4(-57.1, -1109.6, 26.4, 70.0)
            }
        },
        vehicles = {
            -- Albany
            {
                model = 'alpha',
                label = 'Albany Alpha',
                filter = 'sports',
                category = 'albany',
                price = 65000,
                seats = 2,
                estSpeed = 215,
                type = 'car'
            },
            {
                model = 'vstr',
                label = 'Albany V-STR',
                filter = 'sports',
                category = 'albany',
                price = 135000,
                seats = 4,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'primo',
                label = 'Albany Primo',
                filter = 'sedan',
                category = 'albany',
                price = 18000,
                seats = 4,
                estSpeed = 175,
                type = 'car'
            },
            {
                model = 'washington',
                label = 'Albany Washington',
                filter = 'sedan',
                category = 'albany',
                price = 22000,
                seats = 4,
                estSpeed = 180,
                type = 'car'
            },
            {
                model = 'buccaneer',
                label = 'Albany Buccaneer',
                filter = 'muscle',
                category = 'albany',
                price = 32000,
                seats = 2,
                estSpeed = 195,
                type = 'car'
            },
            {
                model = 'hermes',
                label = 'Albany Hermes',
                filter = 'muscle',
                category = 'albany',
                price = 75000,
                seats = 2,
                estSpeed = 190,
                type = 'car'
            },
            {
                model = 'cavalcade2',
                label = 'Albany Cavalcade',
                filter = 'suv',
                category = 'albany',
                price = 48000,
                seats = 4,
                estSpeed = 185,
                type = 'car'
            },
            {
                model = 'cavalcade3',
                label = 'Albany Cavalcade XL',
                filter = 'suv',
                category = 'albany',
                price = 95000,
                seats = 4,
                estSpeed = 195,
                type = 'car'
            },

            -- Annis
            {
                model = 'elegy2',
                label = 'Annis Elegy RH8',
                filter = 'sports',
                category = 'annis',
                price = 85000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'elegy',
                label = 'Annis Elegy Retro Custom',
                filter = 'sports',
                category = 'annis',
                price = 150000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'euros',
                label = 'Annis Euros',
                filter = 'sports',
                category = 'annis',
                price = 125000,
                seats = 2,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'remus',
                label = 'Annis Remus',
                filter = 'sports',
                category = 'annis',
                price = 95000,
                seats = 2,
                estSpeed = 220,
                type = 'car'
            },
            {
                model = 'zr350',
                label = 'Annis ZR350',
                filter = 'sports',
                category = 'annis',
                price = 140000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = '300r',
                label = 'Annis 300R',
                filter = 'sports',
                category = 'annis',
                price = 190000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 's80',
                label = 'Annis S80RR',
                filter = 'super',
                category = 'annis',
                price = 450000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },

            -- Benefactor
            {
                model = 'krieger',
                label = 'Benefactor Krieger',
                filter = 'super',
                category = 'benefactor',
                price = 650000,
                seats = 2,
                estSpeed = 280,
                type = 'car'
            },
            {
                model = 'schlagen',
                label = 'Benefactor Schlagen GT',
                filter = 'sports',
                category = 'benefactor',
                price = 210000,
                seats = 2,
                estSpeed = 250,
                type = 'car'
            },
            {
                model = 'sm722',
                label = 'Benefactor SM722',
                filter = 'sports',
                category = 'benefactor',
                price = 280000,
                seats = 2,
                estSpeed = 250,
                type = 'car'
            },
            {
                model = 'feltzer2',
                label = 'Benefactor Feltzer',
                filter = 'sports',
                category = 'benefactor',
                price = 110000,
                seats = 2,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'schafter2',
                label = 'Benefactor Schafter',
                filter = 'sedan',
                category = 'benefactor',
                price = 55000,
                seats = 4,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'schafter3',
                label = 'Benefactor Schafter V12',
                filter = 'sports',
                category = 'benefactor',
                price = 115000,
                seats = 4,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'dubsta',
                label = 'Benefactor Dubsta',
                filter = 'suv',
                category = 'benefactor',
                price = 80000,
                seats = 4,
                estSpeed = 185,
                type = 'car'
            },
            {
                model = 'dubsta3',
                label = 'Benefactor Dubsta 6x6',
                filter = 'offroad',
                category = 'benefactor',
                price = 160000,
                seats = 6,
                estSpeed = 180,
                type = 'car'
            },
            {
                model = 'panto',
                label = 'Benefactor Panto',
                filter = 'compacts',
                category = 'benefactor',
                price = 15000,
                seats = 2,
                estSpeed = 160,
                type = 'car'
            },

            -- BF
            {
                model = 'club',
                label = 'BF Club',
                filter = 'compacts',
                category = 'bf',
                price = 45000,
                seats = 2,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'weevil',
                label = 'BF Weevil',
                filter = 'compacts',
                category = 'bf',
                price = 35000,
                seats = 2,
                estSpeed = 170,
                type = 'car'
            },
            {
                model = 'bifta',
                label = 'BF Bifta',
                filter = 'offroad',
                category = 'bf',
                price = 25000,
                seats = 2,
                estSpeed = 185,
                type = 'car'
            },

            -- Bollokan
            {
                model = 'prairie',
                label = 'Bollokan Prairie',
                filter = 'compacts',
                category = 'bollokan',
                price = 24000,
                seats = 2,
                estSpeed = 190,
                type = 'car'
            },
            {
                model = 'envisage',
                label = 'Bollokan Envisage',
                filter = 'sports',
                category = 'bollokan',
                price = 320000,
                seats = 2,
                estSpeed = 255,
                type = 'car'
            },

            -- Bravado
            {
                model = 'banshee',
                label = 'Bravado Banshee',
                filter = 'sports',
                category = 'bravado',
                price = 95000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'buffalo',
                label = 'Bravado Buffalo',
                filter = 'sports',
                category = 'bravado',
                price = 42000,
                seats = 4,
                estSpeed = 215,
                type = 'car'
            },
            {
                model = 'buffalo2',
                label = 'Bravado Buffalo S',
                filter = 'sports',
                category = 'bravado',
                price = 65000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'buffalo4',
                label = 'Bravado Buffalo STX',
                filter = 'muscle',
                category = 'bravado',
                price = 185000,
                seats = 4,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'buffalo5',
                label = 'Bravado Buffalo EVX',
                filter = 'muscle',
                category = 'bravado',
                price = 220000,
                seats = 2,
                estSpeed = 250,
                type = 'car'
            },
            {
                model = 'gauntlet',
                label = 'Bravado Gauntlet',
                filter = 'muscle',
                category = 'bravado',
                price = 45000,
                seats = 2,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'gauntlet4',
                label = 'Bravado Gauntlet Hellfire',
                filter = 'muscle',
                category = 'bravado',
                price = 135000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'greenwood',
                label = 'Bravado Greenwood',
                filter = 'muscle',
                category = 'bravado',
                price = 85000,
                seats = 4,
                estSpeed = 200,
                type = 'car'
            },
            {
                model = 'dorado',
                label = 'Bravado Dorado',
                filter = 'suv',
                category = 'bravado',
                price = 75000,
                seats = 4,
                estSpeed = 190,
                type = 'car'
            },

            -- Canis
            {
                model = 'kamacho',
                label = 'Canis Kamacho',
                filter = 'offroad',
                category = 'canis',
                price = 95000,
                seats = 4,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'mesa',
                label = 'Canis Mesa',
                filter = 'offroad',
                category = 'canis',
                price = 34000,
                seats = 4,
                estSpeed = 175,
                type = 'car'
            },
            {
                model = 'terminus',
                label = 'Canis Terminus',
                filter = 'offroad',
                category = 'canis',
                price = 130000,
                seats = 4,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'castigator',
                label = 'Canis Castigator',
                filter = 'suv',
                category = 'canis',
                price = 110000,
                seats = 4,
                estSpeed = 215,
                type = 'car'
            },

            -- Chariot
            {
                model = 'romero',
                label = 'Chariot Romero Hearse',
                filter = 'sedan',
                category = 'chariot',
                price = 35000,
                seats = 2,
                estSpeed = 160,
                type = 'car'
            },

            -- Cheval
            {
                model = 'fugitive',
                label = 'Cheval Fugitive',
                filter = 'sedan',
                category = 'cheval',
                price = 32000,
                seats = 4,
                estSpeed = 200,
                type = 'car'
            },
            {
                model = 'taipan',
                label = 'Cheval Taipan',
                filter = 'super',
                category = 'cheval',
                price = 420000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },
            {
                model = 'picador',
                label = 'Cheval Picador',
                filter = 'muscle',
                category = 'cheval',
                price = 21000,
                seats = 2,
                estSpeed = 175,
                type = 'car'
            },

            -- Classique
            {
                model = 'broadway',
                label = 'Classique Broadway',
                filter = 'classic',
                category = 'classique',
                price = 85000,
                seats = 2,
                estSpeed = 170,
                type = 'car'
            },

            -- Coil
            {
                model = 'cyclone',
                label = 'Coil Cyclone',
                filter = 'super',
                category = 'coil',
                price = 520000,
                seats = 2,
                estSpeed = 265,
                type = 'car'
            },
            {
                model = 'cyclone2',
                label = 'Coil Cyclone II',
                filter = 'super',
                category = 'coil',
                price = 620000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'raiden',
                label = 'Coil Raiden',
                filter = 'sports',
                category = 'coil',
                price = 175000,
                seats = 4,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'voltic',
                label = 'Coil Voltic',
                filter = 'super',
                category = 'coil',
                price = 120000,
                seats = 2,
                estSpeed = 220,
                type = 'car'
            },

            -- Declasse
            {
                model = 'vigero2',
                label = 'Declasse Vigero ZX',
                filter = 'muscle',
                category = 'declasse',
                price = 160000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'sabregt',
                label = 'Declasse Sabre Turbo',
                filter = 'muscle',
                category = 'declasse',
                price = 36000,
                seats = 2,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'tulip',
                label = 'Declasse Tulip',
                filter = 'muscle',
                category = 'declasse',
                price = 68000,
                seats = 4,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'impaler',
                label = 'Declasse Impaler',
                filter = 'muscle',
                category = 'declasse',
                price = 52000,
                seats = 2,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'impaler2',
                label = 'Declasse Impaler SZ',
                filter = 'sedan',
                category = 'declasse',
                price = 89000,
                seats = 4,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'draugur',
                label = 'Declasse Draugur',
                filter = 'offroad',
                category = 'declasse',
                price = 150000,
                seats = 4,
                estSpeed = 215,
                type = 'car'
            },
            {
                model = 'granger2',
                label = 'Declasse Granger 3600LX',
                filter = 'suv',
                category = 'declasse',
                price = 125000,
                seats = 8,
                estSpeed = 195,
                type = 'car'
            },
            {
                model = 'asea',
                label = 'Declasse Asea',
                filter = 'sedan',
                category = 'declasse',
                price = 14000,
                seats = 4,
                estSpeed = 165,
                type = 'car'
            },

            -- Dewbauchee
            {
                model = 'champion',
                label = 'Dewbauchee Champion',
                filter = 'super',
                category = 'dewbauchee',
                price = 380000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },
            {
                model = 'vagner',
                label = 'Dewbauchee Vagner',
                filter = 'super',
                category = 'dewbauchee',
                price = 550000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'massacro',
                label = 'Dewbauchee Massacro',
                filter = 'sports',
                category = 'dewbauchee',
                price = 115000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'specter',
                label = 'Dewbauchee Specter',
                filter = 'sports',
                category = 'dewbauchee',
                price = 155000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'exemplar',
                label = 'Dewbauchee Exemplar',
                filter = 'coupe',
                category = 'dewbauchee',
                price = 88000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },

            -- Dinka
            {
                model = 'jester4',
                label = 'Dinka Jester RR',
                filter = 'sports',
                category = 'dinka',
                price = 175000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'jester3',
                label = 'Dinka Jester Classic',
                filter = 'sports',
                category = 'dinka',
                price = 145000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'rt3000',
                label = 'Dinka RT3000',
                filter = 'sports',
                category = 'dinka',
                price = 130000,
                seats = 2,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'sugoi',
                label = 'Dinka Sugoi',
                filter = 'sports',
                category = 'dinka',
                price = 95000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'blista3',
                label = 'Dinka Blista Kanjo',
                filter = 'compacts',
                category = 'dinka',
                price = 48000,
                seats = 2,
                estSpeed = 200,
                type = 'car'
            },
            {
                model = 'kanjosj',
                label = 'Dinka Kanjo SJ',
                filter = 'coupe',
                category = 'dinka',
                price = 55000,
                seats = 2,
                estSpeed = 205,
                type = 'car'
            },

            -- Dundreary
            {
                model = 'landstalker2',
                label = 'Dundreary Landstalker XL',
                filter = 'suv',
                category = 'dundreary',
                price = 78000,
                seats = 4,
                estSpeed = 190,
                type = 'car'
            },
            {
                model = 'stretch',
                label = 'Dundreary Stretch',
                filter = 'sedan',
                category = 'dundreary',
                price = 65000,
                seats = 4,
                estSpeed = 175,
                type = 'car'
            },

            -- Emperor
            {
                model = 'vectre',
                label = 'Emperor Vectre',
                filter = 'sports',
                category = 'emperor',
                price = 160000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'etr1',
                label = 'Emperor ETR1',
                filter = 'super',
                category = 'emperor',
                price = 480000,
                seats = 2,
                estSpeed = 265,
                type = 'car'
            },
            {
                model = 'habanero',
                label = 'Emperor Habanero',
                filter = 'suv',
                category = 'emperor',
                price = 34000,
                seats = 4,
                estSpeed = 175,
                type = 'car'
            },

            -- Enus
            {
                model = 'deity',
                label = 'Enus Deity',
                filter = 'sedan',
                category = 'enus',
                price = 195000,
                seats = 4,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'paragon',
                label = 'Enus Paragon R',
                filter = 'sports',
                category = 'enus',
                price = 230000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'jubilee',
                label = 'Enus Jubilee',
                filter = 'suv',
                category = 'enus',
                price = 210000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'windsor',
                label = 'Enus Windsor',
                filter = 'coupe',
                category = 'enus',
                price = 180000,
                seats = 2,
                estSpeed = 220,
                type = 'car'
            },

            -- Fathom
            {
                model = 'fr36',
                label = 'Fathom FR36',
                filter = 'coupe',
                category = 'fathom',
                price = 115000,
                seats = 2,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'fq2',
                label = 'Fathom FQ 2',
                filter = 'suv',
                category = 'fathom',
                price = 35000,
                seats = 4,
                estSpeed = 180,
                type = 'car'
            },

            -- Gallivanter
            {
                model = 'baller7',
                label = 'Gallivanter Baller ST',
                filter = 'suv',
                category = 'gallivanter',
                price = 120000,
                seats = 4,
                estSpeed = 215,
                type = 'car'
            },
            {
                model = 'baller2',
                label = 'Gallivanter Baller II',
                filter = 'suv',
                category = 'gallivanter',
                price = 65000,
                seats = 4,
                estSpeed = 190,
                type = 'car'
            },

            -- Grotti
            {
                model = 'turismo3',
                label = 'Grotti Turismo Omaggio',
                filter = 'super',
                category = 'grotti',
                price = 580000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'italirsx',
                label = 'Grotti Itali RSX',
                filter = 'sports',
                category = 'grotti',
                price = 480000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },
            {
                model = 'italigto',
                label = 'Grotti Itali GTO',
                filter = 'sports',
                category = 'grotti',
                price = 320000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },
            {
                model = 'furia',
                label = 'Grotti Furia',
                filter = 'super',
                category = 'grotti',
                price = 590000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'stingertt',
                label = 'Grotti Stinger TT',
                filter = 'sports',
                category = 'grotti',
                price = 360000,
                seats = 2,
                estSpeed = 265,
                type = 'car'
            },
            {
                model = 'cheetah2',
                label = 'Grotti Cheetah Classic',
                filter = 'classic',
                category = 'grotti',
                price = 220000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },

            -- HVY
            {
                model = 'nightshark',
                label = 'HVY Nightshark',
                filter = 'offroad',
                category = 'hvy',
                price = 280000,
                seats = 4,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'insurgent',
                label = 'HVY Insurgent',
                filter = 'offroad',
                category = 'hvy',
                price = 320000,
                seats = 6,
                estSpeed = 180,
                type = 'car'
            },

            -- Imponte
            {
                model = 'ruiner3',
                label = 'Imponte Ruiner ZZ-8',
                filter = 'muscle',
                category = 'imponte',
                price = 95000,
                seats = 2,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'arbitergt',
                label = 'Imponte Arbiter GT',
                filter = 'muscle',
                category = 'imponte',
                price = 115000,
                seats = 2,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'dukes',
                label = 'Imponte Dukes',
                filter = 'muscle',
                category = 'imponte',
                price = 48000,
                seats = 2,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'phoenix',
                label = 'Imponte Phoenix',
                filter = 'muscle',
                category = 'imponte',
                price = 40000,
                seats = 2,
                estSpeed = 210,
                type = 'car'
            },

            -- Invetero
            {
                model = 'coquette4',
                label = 'Invetero Coquette D10',
                filter = 'sports',
                category = 'invetero',
                price = 310000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },
            {
                model = 'coquette5',
                label = 'Invetero Coquette D1',
                filter = 'classic',
                category = 'invetero',
                price = 110000,
                seats = 2,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'coquette',
                label = 'Invetero Coquette',
                filter = 'sports',
                category = 'invetero',
                price = 105000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },

            -- Karin
            {
                model = 'sultan',
                label = 'Karin Sultan',
                filter = 'sedan',
                category = 'karin',
                price = 52000,
                seats = 4,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'sultanrs',
                label = 'Karin Sultan RS',
                filter = 'super',
                category = 'karin',
                price = 175000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'sultan3',
                label = 'Karin Sultan Classic',
                filter = 'sports',
                category = 'karin',
                price = 95000,
                seats = 4,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'sultan4',
                label = 'Karin Sultan RS Classic',
                filter = 'sports',
                category = 'karin',
                price = 135000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'kuruma',
                label = 'Karin Kuruma',
                filter = 'sports',
                category = 'karin',
                price = 75000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'futo',
                label = 'Karin Futo',
                filter = 'sports',
                category = 'karin',
                price = 28000,
                seats = 2,
                estSpeed = 195,
                type = 'car'
            },
            {
                model = 'futo2',
                label = 'Karin Futo GTX',
                filter = 'sports',
                category = 'karin',
                price = 78000,
                seats = 2,
                estSpeed = 215,
                type = 'car'
            },
            {
                model = 'calico',
                label = 'Karin Calico GT-F',
                filter = 'sports',
                category = 'karin',
                price = 160000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'previon',
                label = 'Karin Previon',
                filter = 'coupe',
                category = 'karin',
                price = 88000,
                seats = 2,
                estSpeed = 220,
                type = 'car'
            },
            {
                model = 'intruder',
                label = 'Karin Intruder',
                filter = 'sedan',
                category = 'karin',
                price = 24000,
                seats = 4,
                estSpeed = 185,
                type = 'car'
            },
            {
                model = 'asterope',
                label = 'Karin Asterope',
                filter = 'sedan',
                category = 'karin',
                price = 22000,
                seats = 4,
                estSpeed = 185,
                type = 'car'
            },
            {
                model = 'everon',
                label = 'Karin Everon',
                filter = 'offroad',
                category = 'karin',
                price = 110000,
                seats = 4,
                estSpeed = 195,
                type = 'car'
            },

            -- Lampadati
            {
                model = 'corsita',
                label = 'Lampadati Corsita',
                filter = 'sports',
                category = 'lampadati',
                price = 290000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },
            {
                model = 'cinquemila',
                label = 'Lampadati Cinquemila',
                filter = 'sedan',
                category = 'lampadati',
                price = 185000,
                seats = 4,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'komoda',
                label = 'Lampadati Komoda',
                filter = 'sports',
                category = 'lampadati',
                price = 145000,
                seats = 4,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'novak',
                label = 'Lampadati Novak',
                filter = 'suv',
                category = 'lampadati',
                price = 120000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },

            -- Maibatsu
            {
                model = 'penumbra2',
                label = 'Maibatsu Penumbra FF',
                filter = 'sports',
                category = 'maibatsu',
                price = 110000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'monstrociti',
                label = 'Maibatsu MonstroCiti',
                filter = 'offroad',
                category = 'maibatsu',
                price = 85000,
                seats = 2,
                estSpeed = 205,
                type = 'car'
            },

            -- Obey
            {
                model = 'tenf',
                label = 'Obey 10F',
                filter = 'sports',
                category = 'obey',
                price = 240000,
                seats = 2,
                estSpeed = 255,
                type = 'car'
            },
            {
                model = 'drafter',
                label = 'Obey 8F Drafter',
                filter = 'sports',
                category = 'obey',
                price = 160000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'tailgater2',
                label = 'Obey Tailgater S',
                filter = 'sedan',
                category = 'obey',
                price = 125000,
                seats = 4,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'omnisegt',
                label = 'Obey Omnis e-GT',
                filter = 'sports',
                category = 'obey',
                price = 210000,
                seats = 4,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'ninef',
                label = 'Obey 9F',
                filter = 'sports',
                category = 'obey',
                price = 120000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },

            -- Ocelot
            {
                model = 'virtue',
                label = 'Ocelot Virtue',
                filter = 'super',
                category = 'ocelot',
                price = 620000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'pariah',
                label = 'Ocelot Pariah',
                filter = 'sports',
                category = 'ocelot',
                price = 260000,
                seats = 2,
                estSpeed = 265,
                type = 'car'
            },
            {
                model = 'jugular',
                label = 'Ocelot Jugular',
                filter = 'sports',
                category = 'ocelot',
                price = 185000,
                seats = 4,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'xa21',
                label = 'Ocelot XA-21',
                filter = 'super',
                category = 'ocelot',
                price = 580000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },

            -- Overflod
            {
                model = 'pipistrello',
                label = 'Overflod Pipistrello',
                filter = 'super',
                category = 'overflod',
                price = 720000,
                seats = 2,
                estSpeed = 280,
                type = 'car'
            },
            {
                model = 'zeno',
                label = 'Overflod Zeno',
                filter = 'super',
                category = 'overflod',
                price = 590000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'entitymt',
                label = 'Overflod Entity MT',
                filter = 'super',
                category = 'overflod',
                price = 680000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'autarch',
                label = 'Overflod Autarch',
                filter = 'super',
                category = 'overflod',
                price = 620000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },

            -- Pegassi
            {
                model = 'torero2',
                label = 'Pegassi Torero XO',
                filter = 'super',
                category = 'pegassi',
                price = 710000,
                seats = 2,
                estSpeed = 280,
                type = 'car'
            },
            {
                model = 'ignus',
                label = 'Pegassi Ignus',
                filter = 'super',
                category = 'pegassi',
                price = 690000,
                seats = 2,
                estSpeed = 280,
                type = 'car'
            },
            {
                model = 'zentorno',
                label = 'Pegassi Zentorno',
                filter = 'super',
                category = 'pegassi',
                price = 420000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },
            {
                model = 'toros',
                label = 'Pegassi Toros',
                filter = 'suv',
                category = 'pegassi',
                price = 185000,
                seats = 4,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'tempesta',
                label = 'Pegassi Tempesta',
                filter = 'super',
                category = 'pegassi',
                price = 520000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },

            -- Penaud
            {
                model = 'lacoureuse',
                label = 'Penaud La Coureuse',
                filter = 'sports',
                category = 'penaud',
                price = 210000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },

            -- Pfister
            {
                model = 'comet6',
                label = 'Pfister Comet S2',
                filter = 'sports',
                category = 'pfister',
                price = 245000,
                seats = 2,
                estSpeed = 255,
                type = 'car'
            },
            {
                model = 'growler',
                label = 'Pfister Growler',
                filter = 'sports',
                category = 'pfister',
                price = 215000,
                seats = 2,
                estSpeed = 250,
                type = 'car'
            },
            {
                model = 'neon',
                label = 'Pfister Neon',
                filter = 'sports',
                category = 'pfister',
                price = 220000,
                seats = 4,
                estSpeed = 245,
                type = 'car'
            },
            {
                model = 'astron',
                label = 'Pfister Astron',
                filter = 'suv',
                category = 'pfister',
                price = 135000,
                seats = 4,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'pfister811',
                label = 'Pfister 811',
                filter = 'super',
                category = 'pfister',
                price = 520000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },

            -- Principe
            {
                model = 'deveste',
                label = 'Principe Deveste Eight',
                filter = 'super',
                category = 'principe',
                price = 690000,
                seats = 2,
                estSpeed = 280,
                type = 'car'
            },

            -- Progen
            {
                model = 'emerus',
                label = 'Progen Emerus',
                filter = 'super',
                category = 'progen',
                price = 720000,
                seats = 2,
                estSpeed = 285,
                type = 'car'
            },
            {
                model = 't20',
                label = 'Progen T20',
                filter = 'super',
                category = 'progen',
                price = 650000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'italigtb',
                label = 'Progen Itali GTB',
                filter = 'super',
                category = 'progen',
                price = 420000,
                seats = 2,
                estSpeed = 265,
                type = 'car'
            },

            -- RUNE
            {
                model = 'cheburek',
                label = 'RUNE Cheburek',
                filter = 'compacts',
                category = 'rune',
                price = 18000,
                seats = 4,
                estSpeed = 165,
                type = 'car'
            },

            -- Toundra
            {
                model = 'panthere',
                label = 'Toundra Panthere',
                filter = 'sports',
                category = 'toundra',
                price = 190000,
                seats = 2,
                estSpeed = 245,
                type = 'car'
            },

            -- Truffade
            {
                model = 'thrax',
                label = 'Truffade Thrax',
                filter = 'super',
                category = 'truffade',
                price = 650000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'nero',
                label = 'Truffade Nero',
                filter = 'super',
                category = 'truffade',
                price = 620000,
                seats = 2,
                estSpeed = 275,
                type = 'car'
            },
            {
                model = 'adder',
                label = 'Truffade Adder',
                filter = 'super',
                category = 'truffade',
                price = 550000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },

            -- Ubermacht
            {
                model = 'niobe',
                label = 'Ubermacht Niobe',
                filter = 'sports',
                category = 'ubermacht',
                price = 310000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },
            {
                model = 'cypher',
                label = 'Ubermacht Cypher',
                filter = 'sports',
                category = 'ubermacht',
                price = 155000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },
            {
                model = 'rhinehart',
                label = 'Ubermacht Rhinehart',
                filter = 'sedan',
                category = 'ubermacht',
                price = 130000,
                seats = 4,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'rebla',
                label = 'Ubermacht Rebla GTS',
                filter = 'suv',
                category = 'ubermacht',
                price = 145000,
                seats = 4,
                estSpeed = 230,
                type = 'car'
            },
            {
                model = 'sentinel4',
                label = 'Ubermacht Sentinel Classic Widebody',
                filter = 'sports',
                category = 'ubermacht',
                price = 125000,
                seats = 2,
                estSpeed = 235,
                type = 'car'
            },

            -- Vapid
            {
                model = 'dominator8',
                label = 'Vapid Dominator GTT',
                filter = 'muscle',
                category = 'vapid',
                price = 125000,
                seats = 2,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'dominator7',
                label = 'Vapid Dominator ASP',
                filter = 'muscle',
                category = 'vapid',
                price = 165000,
                seats = 2,
                estSpeed = 240,
                type = 'car'
            },
            {
                model = 'caracara2',
                label = 'Vapid Caracara 4x4',
                filter = 'offroad',
                category = 'vapid',
                price = 115000,
                seats = 4,
                estSpeed = 200,
                type = 'car'
            },
            {
                model = 'aleutian',
                label = 'Vapid Aleutian',
                filter = 'suv',
                category = 'vapid',
                price = 125000,
                seats = 4,
                estSpeed = 210,
                type = 'car'
            },
            {
                model = 'fmj',
                label = 'Vapid FMJ',
                filter = 'super',
                category = 'vapid',
                price = 510000,
                seats = 2,
                estSpeed = 270,
                type = 'car'
            },
            {
                model = 'stanier',
                label = 'Vapid Stanier',
                filter = 'sedan',
                category = 'vapid',
                price = 18000,
                seats = 4,
                estSpeed = 175,
                type = 'car'
            },

            -- Vulcar
            {
                model = 'nebula',
                label = 'Vulcar Nebula Turbo',
                filter = 'sports',
                category = 'vulcar',
                price = 65000,
                seats = 2,
                estSpeed = 205,
                type = 'car'
            },
            {
                model = 'warrener2',
                label = 'Vulcar Warrener HKR',
                filter = 'sedan',
                category = 'vulcar',
                price = 68000,
                seats = 2,
                estSpeed = 195,
                type = 'car'
            },
            {
                model = 'fagaloa',
                label = 'Vulcar Fagaloa',
                filter = 'classic',
                category = 'vulcar',
                price = 28000,
                seats = 4,
                estSpeed = 165,
                type = 'car'
            },

            -- Vysser
            {
                model = 'neo',
                label = 'Vysser Neo',
                filter = 'sports',
                category = 'vysser',
                price = 340000,
                seats = 2,
                estSpeed = 260,
                type = 'car'
            },

            -- Weeny
            {
                model = 'issi7',
                label = 'Weeny Issi Rally',
                filter = 'sports',
                category = 'weeny',
                price = 145000,
                seats = 4,
                estSpeed = 225,
                type = 'car'
            },
            {
                model = 'issi2',
                label = 'Weeny Issi',
                filter = 'compacts',
                category = 'weeny',
                price = 22000,
                seats = 2,
                estSpeed = 180,
                type = 'car'
            },
            {
                model = 'dynasty',
                label = 'Weeny Dynasty',
                filter = 'classic',
                category = 'weeny',
                price = 35000,
                seats = 4,
                estSpeed = 160,
                type = 'car'
            },

            -- Willard
            {
                model = 'eudora',
                label = 'Willard Eudora',
                filter = 'muscle',
                category = 'willard',
                price = 78000,
                seats = 4,
                estSpeed = 180,
                type = 'car'
            },
            {
                model = 'faction',
                label = 'Willard Faction',
                filter = 'muscle',
                category = 'willard',
                price = 34000,
                seats = 2,
                estSpeed = 190,
                type = 'car'
            },

            -- Zirconium
            {
                model = 'stratum',
                label = 'Zirconium Stratum',
                filter = 'sedan',
                category = 'zirconium',
                price = 20000,
                seats = 4,
                estSpeed = 180,
                type = 'car'
            },
            {
                model = 'journey2',
                label = 'Zirconium Journey II',
                filter = 'vans',
                category = 'zirconium',
                price = 45000,
                seats = 4,
                estSpeed = 145,
                type = 'car'
            }

        }
    },
    utility_trucks = {
        label = 'Utility Trucks',
        licenseRequired = false,
        allowSociety = true,
        societyJobs = {},
        categories = {
            { key = 'light', label = 'Lehké náklaďáky' },
            { key = 'heavy', label = 'Těžké tahače' }
        },
        blip = {
            enabled = true,
            coords = vec3(1207.1, -3116.3, 5.6),
            sprite = 67,
            color = 5,
            scale = 0.8
        },
        npc = {
            model = 's_m_m_dockwork_01',
            coords = vec4(1207.1, -3116.3, 5.6, 358.0),
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
        },
        showroom = {
            previewCoords = vec4(1215.9, -3115.8, 5.5, 270.0),
            camCoords = vec3(1210.9, -3117.5, 7.0),
            spawnCoords = vec4(1232.4, -3098.1, 5.8, 90.0),
            fallbackGarage = 'TRUCK_DEPOT',
            testDrive = {
                enabled = true,
                spawnCoords = vec4(1219.5, -3038.1, 5.9, 180.0),
                returnCoords = vec4(1207.1, -3116.3, 5.6, 358.0)
            }
        },
        vehicles = {
            {
                model = 'mule',
                label = 'Maibatsu Mule',
                category = 'light',
                price = 96000,
                seats = 2,
                estSpeed = 140,
                type = 'car'
            },
            {
                model = 'phantom',
                label = 'Jobuilt Phantom',
                category = 'heavy',
                price = 180000,
                seats = 2,
                estSpeed = 135,
                type = 'car'
            }
        }
    },
    air_sea = {
        label = 'Air & Sea Dealer',
        licenseRequired = false,
        allowSociety = false,
        categories = {
            { key = 'heli',  label = 'Helikoptéry' },
            { key = 'boats', label = 'Lodě' }
        },
        blip = {
            enabled = true,
            coords = vec3(-724.6, -1444.1, 5.0),
            sprite = 410,
            color = 38,
            scale = 0.8
        },
        npc = {
            model = 's_m_y_pilot_01',
            coords = vec4(-724.6, -1444.1, 5.0, 138.0),
            scenario = 'WORLD_HUMAN_AA_COFFEE'
        },
        showroom = {
            previewCoords = vec4(-744.7, -1468.2, 5.0, 230.0),
            camCoords = vec3(-748.0, -1462.0, 7.2),
            spawnCoords = vec4(-724.2, -1467.8, 5.0, 140.0),
            fallbackGarage = 'MARINA',
            testDrive = {
                enabled = true,
                spawnCoords = vec4(-746.3, -1465.2, 5.0, 320.0),
                returnCoords = vec4(-724.6, -1444.1, 5.0, 138.0)
            }
        },
        vehicles = {
            {
                model = 'frogger',
                label = 'Frogger',
                category = 'heli',
                price = 720000,
                seats = 4,
                estSpeed = 260,
                type = 'aircraft'
            },
            {
                model = 'speeder',
                label = 'Speeder',
                category = 'boats',
                price = 315000,
                seats = 4,
                estSpeed = 150,
                type = 'boat'
            }
        }
    }
}

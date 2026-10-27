Config = {}

Config.Tests = {
    ["weapon"] = {
        label = "Zbraňový průkaz",
        price = 500,
        -- requires = "psychotests",
        blip = { sprite = 407, color = 4, scale = 0.8 },
        coords = vec3(210.3019, -1404.7943, 29.2921),
        heading = 320.0,
        ped = "a_m_y_business_02",

        minCorrect = 1,
        maxQuestions = 3,
        questions = {
            {
                question = "Jaká je maximální povolená rychlost v obci?",
                options = {
                    { label = "30 km/h", value = "30" },
                    { label = "50 km/h", value = "50" },
                    { label = "90 km/h", value = "90" }
                },
                correct = "50"
            },
        }
    },
    ["psychotests"] = {
        label = "Psychologický posudek",
        price = 200,
        -- requires = "psychotests",
        blip = { sprite = 280, color = 3, scale = 0.8 },
        coords = vec3(215.3019, -1404.7943, 29.2921),
        heading = 320.0,
        ped = "s_m_m_doctor_01",

        minCorrect = 1,
        maxQuestions = 1,
        questions = {
            {
                question = "Trpíte náhlými návaly vzteku?",
                options = {
                    { label = "Rozhodně ano!",   value = "ano" },
                    { label = "Ne, jsem klidný", value = "ne" }
                },
                correct = "ne"
            }
        }
    }
}

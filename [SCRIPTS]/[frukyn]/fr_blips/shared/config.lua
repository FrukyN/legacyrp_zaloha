Config = {}

Config.UpdateInterval = 15000

Config.Blips = {
    {
        name = "Autoškola",
        coords = vec3(215.0, -810.0, 30.0),
        sprite = 545,
        color = 38,
        scale = 0.8,
        dynamic = false
    },

    {
        name = "Kavárna (Bean Machine)",
        coords = vec3(-43.0, -1749.0, 29.0),
        sprite = 106,
        scale = 0.8,
        dynamic = true,
        job = "hayes",
        minOnline = 1,
        offlineColor = 39,
        onlineColor = 2,
    },

    {
        name = "Mission Row LSPD",
        coords = vec3(425.1, -979.5, 30.7),
        sprite = 60,
        scale = 0.8,
        dynamic = true,
        job = "police",
        minOnline = 1,
        offlineColor = 39,
        onlineColor = 2,
    }
}

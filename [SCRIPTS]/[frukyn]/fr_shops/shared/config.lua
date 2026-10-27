Config = {}

Config.ImageURL = "nui://ox_inventory/web/images/"

Config.Items = {
    ["water"] = { label = "Voda", minPrice = 10, maxPrice = 50, maxStock = 50, license = nil, grade = nil },
    ["burger"] = { label = "Hamburger", minPrice = 30, maxPrice = 100, maxStock = 20, license = nil, grade = nil },
    ["phone"] = { label = "Telefon", minPrice = 1000, maxPrice = 1650, maxStock = 4, license = nil, grade = nil },
    ["weapon_pistol"] = { label = "Pistole", minPrice = 5000, maxPrice = 15000, maxStock = 2, license = "weapon", grade = nil }
}

Config.Shops = {
    ["LTD_Davis"] = {
        name = "LTD Davis (Benzínka)",
        hours = { open = 0, close = 23},
        doorlockId = 1, -- ID dveří v ox_doorlock (pokud nevyužíváš, dej nil)
   
        register = {
            coords = vec3(-706.13, -914.51, 19.21),
            heading = 88.0,
            pedModel = `mp_m_shopkeep_01`,
        },
        
        shelves = {
            [1] = {
                label = "Lednice",
                coords = vec3(-706.5, -912.0, 19.21),
                items = { "water" } -- Co se prodává v tomto regálu
            },
            [2] = {
                label = "Pult (Elektronika)",
                coords = vec3(-705.5, -914.0, 19.21),
                items = { "phone" }
            },
            [3] = {
                label = "Regál s jídlem",
                coords = vec3(-704.5, -912.0, 19.21),
                items = { "burger" }
            }
        }
    }
}
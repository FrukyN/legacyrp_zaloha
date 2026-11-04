Config = {}

Config.BleedoutTimer = 300

Config.EarlyRespawnTimer = 10 -- po jakde dobe e na respawn

Config.HospitalCoords = vec4(307.7, -1433.4, 29.9, 142.0)


-- Skupiny (joby), které mají právo oživovat přes /revive nebo EMS interakce
Config.EMSJobs = {
    ['ambulance'] = 1, -- Název jobu a minimální grade
    ['police'] = 2
}

-- Povolené admin skupiny pro příkaz /revive
Config.AdminGroups = {
    ['group.admin'] = true,
    ['group.god'] = true
}
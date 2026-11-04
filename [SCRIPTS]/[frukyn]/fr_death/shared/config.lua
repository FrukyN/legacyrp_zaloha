Config = {}

-- Čas v sekundách, po kterém může hráč zavolat záchranku / krvácí
Config.BleedoutTimer = 300 -- 5 minut

-- Čas v sekundách, po kterém se hráč může nechat odvézt do nemocnice (Respawn)
Config.EarlyRespawnTimer = 180 -- 3 minuty

-- Souřadnice nemocnice pro respawn (Pillbox Hill)
Config.HospitalCoords = vec4(307.7, -1433.4, 29.9, 142.0)

-- Mazat inventář při respawnu v nemocnici? (Vyžaduje ox_inventory)
Config.WipeInventoryOnRespawn = false

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
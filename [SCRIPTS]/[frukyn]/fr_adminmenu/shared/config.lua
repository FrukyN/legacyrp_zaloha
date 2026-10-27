Config                      = {}

Config.OpenCommand          = 'adminmenu'
Config.OpenKey              = 'F10'
Config.NoclipKey            = 'F2'
Config.ReportCommand        = 'report'

Config.NotifyPosition       = 'top-right'
Config.NotifyTitle          = 'Admin'

-- Kdo je admin (stačí jedno):
--   1) Majitel: ACE `fradmin.owner`  (server.cfg: add_ace group.admin fradmin.owner allow)
--      nebo identifikátor v Config.Owners
--   2) Admin přidaný v menu (Správa adminů) – ukládá se do data/store.json
--   3) Jednotlivé ACE:  add_ace group.mod fradmin.use allow
--                       add_ace group.mod fradmin.players allow  atd.

Config.Owners               = {
    -- 'license:0123456789abcdef0123456789abcdef01234567',
}

Config.AllPerms             = { 'use', 'players', 'ban', 'economy', 'vehicles', 'whitelist', 'chat', 'server',
    'staffmanage' }

Config.Roles                = {
    trial  = { label = 'Trial Admin', perms = { use = true, players = true } },
    admin  = { label = 'Admin', perms = { use = true, players = true, ban = true, vehicles = true, chat = true } },
    senior = { label = 'Senior Admin', perms = { use = true, players = true, ban = true, vehicles = true, chat = true, whitelist = true, economy = true } },
    super  = { label = 'SuperAdmin', perms = { use = true, players = true, ban = true, vehicles = true, chat = true, whitelist = true, economy = true, server = true, staffmanage = true } },
}

Config.AllowedForceCommands = { pedmenu = true }

Config.ReviveEvents         = {}


Config.ShutdownCommand =
'quit'                          -- „Vypnout server“ a naplánovaný restart (txAdmin po ukončení server nastartuje znovu)
Config.RestartKickReason = 'Server se restartuje. Připoj se prosím za chvíli znovu.'
Config.MaxWarns = 3             -- při dosažení tohoto počtu varování dostane admin upozornění, že hráč zaslouží ban

Config.Teleports = {
    legion = vec3(195.17, -934.0, 30.69),
    sandy  = vec3(1853.0, 3687.0, 34.3),
}

Config.SetTime = nil

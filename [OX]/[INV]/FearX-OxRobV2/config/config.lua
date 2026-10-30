Config = {}

Config.RobCooldown = 10
Config.RobDistance = 2.0
Config.DistanceBuffer = 3.0
Config.AntiSpam = 5
Config.RequireHandsUp = true

-- 'alive', 'dead', 'both'
Config.RobMode = 'both'

Config.RobTimer = {
    min = 5,
    max = 5
}

Config.HandsUpAnims = {
    {dict = 'missminuteman_1ig_2', anim = 'handsup_base'},
    {dict = 'mp_arresting', anim = 'idle'},
    {dict = 'random@mugging3', anim = 'handsup_standing_base'}
}

Config.RobAnimations = {
    {dict = 'anim@mugging@mugger@catch_1h_gun@', anim = 'catch_object_pistol_male', flag = 49},
    {dict = 'anim@mugging@mugger@catch_1h_gun@', anim = 'catch_object_pistol_female', flag = 49},
    {dict = 'anim@mugging@mugger@catch_1h_gun@', anim = 'catch_object_pistol_male', flag = 1},
    {dict = 'anim@mugging@mugger@catch_1h_gun@', anim = 'catch_object_pistol_female', flag = 1}
}

Config.Locales = {
    ['hands_not_up'] = 'Target must have their hands up',
    ['rob_cooldown'] = 'You must wait before robbing again',
    ['target_cooldown'] = 'This person was recently robbed',
    ['rob_cancelled'] = 'Robbery cancelled',
    ['no_target'] = 'No target found',
    ['cant_rob_self'] = 'You cannot rob yourself',
    ['target_in_vehicle'] = 'Target is in a vehicle',
    ['robber_in_vehicle'] = 'You cannot rob while in a vehicle',
    ['anti_spam'] = 'You are doing this too fast',
    ['robbing_in_progress'] = 'Robbing in progress...',
    ['robbery_started'] = 'Someone is robbing you!',
    ['exploit_attempt'] = 'Someone tried to rob you from far away - make a report',
    ['target_not_dead'] = 'Target must be dead to rob',
    ['target_is_dead'] = 'Target must be alive to rob',
    ['target_moved'] = 'Target moved too far away',
    ['target_died'] = 'Target died',
    ['target_hands_down'] = 'Target put hands down',
    ['hands_up'] = 'Hands up',
    ['hands_down'] = 'Hands down',
    ['no_vehicle_handsup'] = 'Cannot put hands up in a vehicle'
}
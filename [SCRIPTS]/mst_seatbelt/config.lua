Config = {}

-- █▀▀ █▀▀ █▄░█ █▀▀ █▀█ ▄▀█ █░░
-- █▄█ ██▄ █░▀█ ██▄ █▀▄ █▀█ █▄▄

Config.Debug = false -- Enable only when troubleshooting; disables most debug prints when false

Config.VersionCheck = false -- Keep true to get important update and bug fix notifications

Config.Seatbelt = {
    enabled = true, -- If false, only the seatbelt command works; no key/button toggles seatbelt
    type = "keymapping", -- "keymapping" (players can rebind in Settings > Key Bindings) or "control" (direct control ID check)
    key = "B", -- Default key for keymapping (e.g., "B", "F1", "G") - only used if type = "keymapping"
    controlId = 29, -- Control ID for B - only used if type = "control", Reference: https://docs.fivem.net/docs/game-references/controls/
    disableAnimation = false, -- If true, disables the seatbelt animation
    disableProp = false -- If true, disables the seatbelt prop (visual object)
}

Config.BlockExitWhenBuckled = true -- If true: cannot exit while seatbelt on. If false: one F press unbuckles and exits

Config.QuickExit = {
    enabled = false, -- Enable/disable double-F quick exit feature (only when Config.BlockExitWhenBuckled is true)
    timeWindow = 500, -- Time window in milliseconds for detecting double-F press (500ms = 0.5 seconds)
    exitKey = 75, -- Default: 75 (F key - Exit Vehicle), Reference for all control IDs: https://docs.fivem.net/docs/game-references/controls/
}

Config.SeatbeltCommand = {
    enabled = true, -- Enable/disable seatbelt command
    name = "seatbelt" -- Command name (e.g., "/seatbelt" in chat)
}

Config.SpeedUnit = "kmh" -- Speed unit options: "kmh" or "mph"

Config.Notifications = {
    type = 'ox_lib', -- Options: 'ox_lib', 'esx', 'qb', 'qbx', 'wasabi', 'okok', 'custom', or 'none' ; Custom notification setup (scroll down here to add your custom notification code)
    title = 'Pás', -- Title for all notifications
    fasten = {
        text = 'Pás zapnut', -- Text for fasten notification
        duration = 3000, -- Duration in milliseconds
    },
    unfasten = {
        text = 'Pás odepnut', -- Text for unfasten notification
        duration = 3000, -- Duration in milliseconds
    },
    exitAttempt = {
        text = 'Nemůžeš opustit vozidlo, zatímco máš pás zapnut', -- Text for exit attempt notification
        duration = 3000, -- Duration in milliseconds
    }
}

Config.HUD = {
    enabled = true, -- Enable/disable HUD indicator when seatbelt is not fastened
    minSpeed = 5.0, -- Minimum speed to show HUD indicator (KMH or MPH based on Config.SpeedUnit), 0.0 = always show when unfastened
    position = { -- Default position: right-centered
        top = "50%", -- Top position (CSS value: %, px, etc.)
        right = "5%", -- Right position (CSS value: %, px, etc.)
    },
    size = {
        width = "120px", -- Indicator width (CSS value: px, %, etc.)
        height = "120px", -- Indicator height (CSS value: px, %, etc.)
    }
}

-- Reference: https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.DisableSeatbeltsForVehicleClasses = {
    8,  -- Motorcycles
    13, -- Cycles
    14, -- Boats
    15 -- Helicopters
}

-- Find vehicle spawn codes here: https://forge.plebmasters.de/vehicles
Config.DisableSeatbeltsForVehicles = {
    "bmx", -- Bike
    "cruiser" -- Bike
}

-- █▀ █▀█ █░█ █▄░█ █▀▄ █▀
-- ▄█ █▄█ █▄█ █░▀█ █▄▀ ▄█

-- Sounds: This script uses interact-sound resource for playing sounds
-- To make sounds work: Drag sound files from mst_seatbelt/sounds folder to interact-sound/client/html/sounds folder
-- Required sound files: seatbeltbuckle.ogg, seatbeltunbuckle.ogg, seatbeltalarm.ogg
-- Download interact-sound: https://github.com/plunkettscott/interact-sound
Config.Sounds = {
    playForAllInVehicle = false, -- true = everyone in vehicle hears; false = individual: only you hear your fasten/unfasten, only unfastened players hear the alarm
    fasten = {
        enabled = false, -- Enable/disable fasten sound
        volume = 1.0, -- Volume for fasten sound (0.0 to 1.0)
    },
    unfasten = {
        enabled = false, -- Enable/disable unfasten sound
        volume = 1.0, -- Volume for unfasten sound (0.0 to 1.0)
    },
    alarm = {
        enabled = false, -- Enable/disable alarm sound
        volume = 1.0, -- Volume for alarm sound (0.0 to 1.0)
        speedThreshold = 30.0, -- Speed threshold for alarm
    }
}

-- █▀▀ ░░█ █▀▀ █▀▀ ▀█▀ █ █▀█ █▄░█
-- ██▄ █▄█ ██▄ █▄▄ ░█░ █ █▄█ █░▀█

Config.Ejection = {
    ejectDistance = 1.0, -- Forward distance for ejection position
    ejectHeight = 1.0, -- Height offset for ejection position
    ejectVelocityMultiplier = 1.0, -- Velocity multiplier for ejection force
    bodyDamageThreshold = 10.0, -- Minimum body damage (frameBodyChange) required to detect a collision (distinguishes collisions from hard braking)

    -- Impact damage configuration based on collision speed (Note: With seatbelt you won't be ejected but still receive damage from collision)
    impactDamage = {
        low = {
            ejectChance = 40, -- Chance to eject when conditions are met (0-100)
            deathChance = 10, -- Chance to die on ejection (0-100), 0 = never die, 100 = always die
            speedThreshold = 80.0, -- Minimum speed for low impact category (KMH/MPH) - impacts at or above this speed are considered "low"
            minSpeedDrop = 65.0, -- Minimum absolute speed drop (KMH/MPH) required to trigger collision detection for this category
            ignoreRearCollisions = true, -- If true, rear collisions (hitting something with the back of the car) won't cause ejection for this category
            survivalDamage = {20, 40}, -- Random damage range if you survive: randomly picks a value between 20 and 40 (health loss amount)
            seatbeltDamage = {5, 15}, -- Random damage when wearing seatbelt (no ejection): picks value between 5-15 (set {0, 0} or nil to disable)
            stayDownAfterSurvival = true, -- Keep player down after surviving ejection
            stayDownDuration = 10000, -- Duration to stay down (ms)
            visualEffects = {
                enabled = true, -- Enable/disable visual effects for this impact level
                timecycleModifier = "Drunk", -- Timecycle modifier name (visual screen effect), find more timecycle modifiers here: https://forge.plebmasters.de/timecyclemods
                timecycleStrength = 0.5, -- Timecycle modifier strength (0.0 to 1.0, higher = stronger effect)
                cameraShake = "DRUNK_SHAKE", -- Camera shake type
                cameraShakeIntensity = 0.5, -- Camera shake intensity (0.0 to 1.0, higher = stronger shake)
                duration = 30000, -- Duration of visual effects in milliseconds
                movement = {
                    enabled = true, -- Enable/disable movement clipset
                    clipset = "move_m@drunk@slightlydrunk", -- Movement clipset name
                },
            },
        },
        medium = {
            ejectChance = 50, -- Chance to eject when conditions are met (0-100)
            deathChance = 35, -- Chance to die on ejection (0-100), 0 = never die, 100 = always die
            speedThreshold = 120.0, -- Minimum speed for medium impact category (KMH/MPH) - impacts at or above this speed are considered "medium"
            minSpeedDrop = 95.0, -- Minimum absolute speed drop (KMH/MPH) required to trigger collision detection for this category
            ignoreRearCollisions = true, -- If true, rear collisions (hitting something with the back of the car) won't cause ejection for this category
            survivalDamage = {20, 40}, -- Random damage range if you survive: randomly picks a value between 20 and 40 (health loss amount)
            seatbeltDamage = {15, 30}, -- Random damage when wearing seatbelt (no ejection): picks value between 15-30 (set {0, 0} or nil to disable)
            stayDownAfterSurvival = true, -- Keep player down after surviving ejection
            stayDownDuration = 15000, -- Duration to stay down (ms)
            visualEffects = {
                enabled = true, -- Enable/disable visual effects for this impact level
                timecycleModifier = "Drunk", -- Timecycle modifier name
                timecycleStrength = 0.7, -- Timecycle modifier strength (0.0 to 1.0)
                cameraShake = "DRUNK_SHAKE", -- Camera shake type
                cameraShakeIntensity = 0.7, -- Camera shake intensity (0.0 to 1.0)
                duration = 45000, -- Duration of visual effects in milliseconds
                movement = {
                    enabled = true, -- Enable/disable movement clipset
                    clipset = "move_m@drunk@moderatedrunk", -- Movement clipset name
                },
            },
        },
        high = {
            ejectChance = 100, -- Chance to eject when conditions are met (0-100)
            deathChance = 45, -- Chance to die on ejection (0-100), 0 = never die, 100 = always die
            speedThreshold = 160.0, -- Minimum speed for high impact category (KMH/MPH) - impacts at or above this speed are considered "high"
            minSpeedDrop = 110.0, -- Minimum absolute speed drop (KMH/MPH) required to trigger collision detection for this category
            ignoreRearCollisions = false, -- If true, rear collisions (hitting something with the back of the car) won't cause ejection for this category
            survivalDamage = {40, 70}, -- Random damage values taken if you survive (health loss amount)
            seatbeltDamage = {30, 50}, -- Random damage when wearing seatbelt (no ejection): picks value between 30-50 (set {0, 0} or nil to disable)
            stayDownAfterSurvival = true, -- Keep player down after surviving ejection
            stayDownDuration = 20000, -- Duration to stay down (ms)
            visualEffects = {
                enabled = true, -- Enable/disable visual effects for this impact level
                timecycleModifier = "player_transition", -- Timecycle modifier name
                timecycleStrength = 0.7, -- Timecycle modifier strength (0.0 to 1.0)
                cameraShake = "DRUNK_SHAKE", -- Camera shake type
                cameraShakeIntensity = 0.7, -- Camera shake intensity (0.0 to 1.0)
                duration = 45000, -- Duration of visual effects in milliseconds
                blackout = {
                    enabled = true, -- Enable/disable blackout effect (screen fades to black repeatedly)
                    duration = 25000, -- Total duration of blackout effect (ms) - how long the entire blackout sequence lasts
                    fadeDuration = 1000, -- Time to fade screen to black (ms) - transition time
                    blackDuration = 1500, -- Time to stay completely black (ms) - how long screen stays black
                    normalDuration = 1000, -- Time to stay normal before next blackout cycle (ms) - pause between blackouts
                    -- Cycle: fade to black → stay black → fade back → stay normal → repeat until duration ends
                },
                heartbeat = {
                    enabled = true, -- Enable/disable heartbeat sound
                    volume = 1.0, -- Volume for heartbeat sound (0.0 to 1.0)
                    duration = nil, -- Duration for heartbeat sound in milliseconds
                    -- nil = automatically uses visualEffects.duration (45000ms in this case)
                    -- Set a number (e.g., 10000) to override and use custom duration instead
                },
                movement = {
                    enabled = true, -- Enable/disable movement clipset
                    clipset = "move_m@drunk@moderatedrunk", -- Movement clipset name
                },
            },
        }
    }
}

-- █▀▀ █░█ █▄░█ █▀▀ ▀█▀ █ █▀█ █▄░█ █▀
-- █▀░ █▄█ █░▀█ █▄▄ ░█░ █ █▄█ █░▀█ ▄█

function ShowNotification(title, text, type, duration)
    if not Config.Notifications or not Config.Notifications.type or Config.Notifications.type == 'none' then
        return
    end
    
    local notificationType = Config.Notifications.type
    
    if notificationType == 'ox_lib' then
        lib.notify({
            title = title or 'Notification',
            description = text,
            type = type or 'info',
            duration = duration or 5000
        })
    elseif notificationType == 'esx' then
        if exports and exports['mst_seatbelt'] and exports['mst_seatbelt'].notifyESX then
            exports['mst_seatbelt']:notifyESX(title, text, type, duration)
        end
    elseif notificationType == 'qb' then
        if exports and exports['mst_seatbelt'] and exports['mst_seatbelt'].notifyQB then
            exports['mst_seatbelt']:notifyQB(text, type, duration)
        end
    elseif notificationType == 'qbx' then
        if exports and exports['mst_seatbelt'] and exports['mst_seatbelt'].notifyQBX then
            exports['mst_seatbelt']:notifyQBX(text, type, duration)
        end
    elseif notificationType == 'okok' then
        exports['okokNotify']:Alert(title or 'Notification', text, duration or 5000, type or 'info', false)
    elseif notificationType == 'wasabi' then
        exports.wasabi_notify:notify(title or 'Notification', text, duration or 5000, type or 'info', false, 'fas fa-bell')
    elseif notificationType == 'custom' then
        -- Note: Set Config.Notifications.type = 'custom' for this to work
        -- Add your custom notification code below this comment
        -- Example: exports['mst_notify']:Notify(title, text, type)
    end
end
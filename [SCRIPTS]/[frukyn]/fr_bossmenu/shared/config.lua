Config = {}

Config.Debug = false
Config.ResourceName = GetCurrentResourceName()

Config.Grades = {
    Finance = 1,      -- deposit/withdraw/manage account
    Employees = 1,    -- hire/fire/promote/notes/announcements/orders
    FullBoss = 1      -- highest level actions if needed
}

Config.MaxDeposit = 5000000
Config.MaxWithdraw = 2000000
Config.MaxBonus = 500000
Config.MaxAnnouncementLength = 300
Config.MaxNoteLength = 500
Config.MaxOrderAmount = 500

Config.AttendanceTickMinutes = 5
Config.PayrollOnlineOnly = true

Config.OrderSystem = {
    Enabled = true,
    DefaultDeliverySeconds = 900
}

-- Configure boss locations and stash settings per job
Config.Jobs = {
    police = {
        label = 'Police Department',
        target = {
            coords = vec3(448.4, -973.2, 30.6),
            size = vec3(1.4, 1.2, 1.8),
            rotation = 0.0,
            debug = true,
            minGrade = 0
        },
        stash = {
            id = 'society_police_stash',
            label = 'Police Company Storage',
            slots = 180,
            weight = 500000
        },
        materialsOrder = {
            enabled = true,
            deliverySeconds = 900,
            items = {
                { item = 'water', label = 'Water', price = 25 },
                { item = 'bread', label = 'Bread', price = 20 }
            }
        }
    },
    mechanic = {
        label = 'Mechanic Company',
        target = {
            coords = vec3(-337.8, -156.9, 44.6),
            size = vec3(1.6, 1.2, 1.8),
            rotation = 0.0,
            debug = false,
            minGrade = 3
        },
        stash = {
            id = 'society_mechanic_stash',
            label = 'Mechanic Company Storage',
            slots = 220,
            weight = 800000
        },
        materialsOrder = {
            enabled = true,
            deliverySeconds = 1200,
            items = {
                { item = 'repairkit', label = 'Repair Kit', price = 400 },
                { item = 'fixtool', label = 'Fix Tool', price = 650 }
            }
        }
    }
}

Config.WebhookColors = {
    Success = '65280',
    Warning = '16753920',
    Danger = '16711680',
    Info = '3447003'
}

 -- DAVE END

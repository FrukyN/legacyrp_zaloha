Config = {}

Config.Debug = false
Config.ResourceName = GetCurrentResourceName()

Config.Grades = {}

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
    --[[
   
    hayes = {
        label = 'Hayes Auto',
        target = {
            -- coords zde nemusí být, pokud otevíráš menu přes unijob target
            minGrade = 0
        },
        stash = {
            id = 'society_hayes_stash',
            label = 'Hayes Sklad',
            slots = 100,
            weight = 500000
        },
        materialsOrder = {
            enabled = false,
            items = {}
        }
    }
    ]]
}

Config = {}

Config.Skills = {
    stamina = {
        label = 'Kondice (Stamina)',
        description = 'Zvyšuje rychlost běhu a celkovou výdrž při sprintu.',
        icon = 'person-running',
        stat = 'MP0_STAMINA', -- Nativní GTA stat
        gain = 0.08, -- Zisk za cyklus (2.5s sprintu)
    },
    strength = {
        label = 'Síla (Strength)',
        description = 'Zvyšuje sílu úderu na blízko a rychlost šplhání po žebřících.',
        icon = 'dumbbell',
        stat = 'MP0_STRENGTH',
        gain = 0.15, -- Zisk za úder na blízko
    },
    lung_capacity = {
        label = 'Kapacita plic',
        description = 'Prodlužuje dobu, po kterou vydržíš pod vodou bez vzduchu.',
        icon = 'water',
        stat = 'MP0_LUNG_CAPACITY',
        gain = 0.12, -- Zisk za cyklus pod vodou
    },
    shooting = {
        label = 'Střelba (Shooting)',
        description = 'Snižuje zpětný ráz zbraní, zrychluje přebíjení a zvyšuje přesnost.',
        icon = 'crosshairs',
        stat = 'MP0_SHOOTING_ABILITY',
        gain = 0.05, -- Zisk za výstřel
    },
    driving = {
        label = 'Řízení (Driving)',
        description = 'Zlepšuje kontrolu nad vozidlem ve vzduchu a při jízdě po zadním kole.',
        icon = 'car',
        stat = 'MP0_DRIVING_ABILITY',
        gain = 0.06, -- Zisk za rychlou jízdu (> 80 km/h)
    }
}
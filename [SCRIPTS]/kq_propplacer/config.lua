Config = {}

-- Enabling this will add additional prints and display of the resource within the pot
Config.debug = false

--
Config.locale = 'cs'

Config.sql = {
    driver = 'oxmysql', -- oxmysql or ghmattimysql or mysql
    -- If you're using an older version of oxmysql set this to false
    newOxMysql = true,
}

-- Full UI customization via RGB color values
Config.uiStyling = {
    ['color-background'] = '29, 29, 51',
    ['color-background-light'] = '41, 41, 66',

    ['color-primary-dark'] = '58, 11, 204',
    ['color-primary'] = '106, 60, 255',
    ['color-primary-light'] = '139, 103, 255',
    ['color-primary-lighter'] = '180, 156, 255',

    ['color-secondary'] = '23, 23, 23',
    ['color-secondary-light'] = '81, 81, 81',

    ['color-white'] = '255, 255, 255',
    ['color-black'] = '5, 5, 5',
}


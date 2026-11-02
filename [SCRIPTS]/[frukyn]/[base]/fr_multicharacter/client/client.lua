local selectedOrigin = Config.defaultOrigin
local characters = {}
local maxSlots = Config.baseSlots or 1
local selectionOpen = false
local cam = nil

local function getDisplayName(character)
    local firstName = character.firstName or character.firstname or ''
    local lastName = character.lastName or character.lastname or ''
    local fullName = (firstName .. ' ' .. lastName):gsub('^%s*(.-)%s*$', '%1')
    return fullName ~= '' and fullName or 'Neznámá postava'
end

local function formatDateString(val)
    if not val or val == '' or val == '-' then return 'Neznámé' end

    local num = tonumber(val)
    if num then
        local sec = num > 10000000000 and math.floor(num / 1000) or math.floor(num)
        local z = math.floor((sec + 43200) / 86400) + 719468
        local era = math.floor((z >= 0 and z or z - 146096) / 146097)
        local doe = z - era * 146097
        local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
        local y = yoe + era * 400
        local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
        local mp = math.floor((5 * doy + 2) / 153)
        local d = doy - math.floor((153 * mp + 2) / 5) + 1
        local m = mp + (mp < 10 and 3 or -9)
        if m <= 2 then y = y + 1 end

        return ('%02d.%02d.%04d'):format(d, m, y)
    end

    local str = tostring(val)
    local y, m, d = str:match('^(%d%d%d%d)-(%d%d)-(%d%d)')
    if y and m and d then
        return ('%s.%s.%s'):format(d, m, y)
    end

    return str:match('^([^%s]+)') or str
end

local function formatDob(character)
    local dob = character.date or character.dateOfBirth or character.date_of_birth or character.dob
    return formatDateString(dob)
end

local function formatLastPlayed(character)
    local lastPlayed = character.lastPlayed or character.lastplayed
    return formatDateString(lastPlayed)
end

local function getJobLabel(character)
    if character.groups and type(character.groups) == 'table' and next(character.groups) ~= nil then
        local jobs = {}
        for groupName, _ in pairs(character.groups) do
            local formatted = tostring(groupName):gsub('^%l', string.upper)
            table.insert(jobs, formatted)
        end
        return table.concat(jobs, ', ')
    elseif character.job then
        if type(character.job) == 'string' then
            return character.job
        elseif type(character.job) == 'table' then
            return character.job.label or character.job.name or 'Nezaměstnaný'
        end
    end
    return 'Nezaměstnaný'
end

-- Pomocná funkce, která postavu vždy umístí před kameru a zviditelní
local function placePedInPreview()
    if not Config.preview then return end
    local ped = PlayerPedId()

    RequestCollisionAtCoord(Config.preview.pedCoords.x, Config.preview.pedCoords.y, Config.preview.pedCoords.z)
    SetEntityCoordsNoOffset(ped, Config.preview.pedCoords.x, Config.preview.pedCoords.y, Config.preview.pedCoords.z, false, false, false)
    SetEntityHeading(ped, Config.preview.pedCoords.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    ClearPedTasksImmediately(ped)
end

-- Načtení vizuálu postavy přes illenium-appearance
local function previewCharacter(character)
    if not character then return end

    if character.appearance and GetResourceState('illenium-appearance') == 'started' then
        exports['illenium-appearance']:setPlayerAppearance(character.appearance)
    else
        -- Záložní model, pokud postava ještě nemá uložený vzhled v databázi
        local modelName = (character.gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
        local model = joaat(modelName)
        if lib.requestModel(model, 5000) then
            SetPlayerModel(PlayerId(), model)
            SetPedDefaultComponentVariation(PlayerPedId())
            SetModelAsNoLongerNeeded(model)
        end
    end

    -- Po změně modelu se vytvoří nový PlayerPedId(), proto ho musíme znovu umístit a zviditelnit
    Wait(50)
    placePedInPreview()
end

-- Nastavení kamery a teleport hráče do místnosti
local function setupCamera()
    if not Config.preview then return end

    DoScreenFadeOut(0)
    placePedInPreview()

    if not cam then
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(cam, Config.preview.cameraPos.x, Config.preview.cameraPos.y, Config.preview.cameraPos.z)
        PointCamAtCoord(cam, Config.preview.cameraLookAt.x, Config.preview.cameraLookAt.y, Config.preview.cameraLookAt.z)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    Wait(500)
    DoScreenFadeIn(250)
end

local function destroyCamera()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
end

local function closeSelection()
    selectionOpen = false
    lib.hideContext(false)
    ShutdownLoadingScreenNui()
    destroyCamera()
    DoScreenFadeIn(250)
end

local openSelection
local openOriginMenu

local function openCreationDialog(originId)
    local input = lib.inputDialog('Vytvoření nové postavy', {
        { type = 'input', label = 'Jméno',          description = 'Např. Joe',  required = true, min = 2, max = 20 },
        { type = 'input', label = 'Příjmení',       description = 'Např. Deer', required = true, min = 2, max = 25 },
        { type = 'date',  label = 'Datum narození', format = "DD.MM.YYYY",      required = true },
        {
            type = 'select',
            label = 'Pohlaví',
            required = true,
            options = {
                { value = 'male',   label = 'Muž' },
                { value = 'female', label = 'Žena' }
            }
        },
        { type = 'input', label = 'Národnost', default = 'Česká', required = true, min = 2, max = 30 }
    })

    if not input then
        lib.showContext('multichar_origin_select')
        return
    end

    selectedOrigin = originId

    local payload = {
        firstName = input[1],
        lastName = input[2],
        date = input[3],
        gender = input[4],
        nationality = input[5],
        origin = originId
    }

    TriggerServerEvent('fr_multicharacter:prepareCharacter', { origin = payload.origin })
    TriggerServerEvent('ox:setActiveCharacter', payload)
end

openOriginMenu = function()
    local options = {}

    for k, v in pairs(Config.origins) do
        local metadata = {}
        if v.startMoney then
            table.insert(metadata, { label = 'Startovní hotovost', value = ('%s $'):format(v.startMoney) })
        end

        table.insert(options, {
            title = v.label,
            description = v.description,
            icon = 'passport',
            metadata = metadata,
            onSelect = function()
                openCreationDialog(k)
            end
        })
    end

    lib.registerContext({
        id = 'multichar_origin_select',
        title = 'Vyberte si původ postavy',
        menu = 'multichar_main_menu',
        canClose = false,
        options = options
    })

    lib.showContext('multichar_origin_select')
end

local function openCharacterDetail(character)
    local fullName = getDisplayName(character)
    local dob = formatDob(character)
    local lastPlayed = formatLastPlayed(character)
    local jobLabel = getJobLabel(character)

    -- Načtení vzhledu vybrané postavy
    previewCharacter(character)

    lib.registerContext({
        id = 'multichar_char_detail',
        title = fullName,
        menu = 'multichar_main_menu',
        canClose = false,
        options = {
            {
                title = 'Informace o postavě',
                icon = 'id-card',
                readOnly = true,
                metadata = {
                    { label = 'Datum narození', value = dob },
                    { label = 'Zaměstnání', value = jobLabel },
                    { label = 'Naposledy hráno', value = lastPlayed }
                }
            },
            {
                title = 'Hrát za tuto postavu',
                description = 'Připojit se do hry za postavu ' .. fullName,
                icon = 'play',
                iconColor = '#5f84ff',
                onSelect = function()
                    closeSelection()
                    TriggerServerEvent('fr_multicharacter:prepareCharacter', { origin = nil })
                    TriggerServerEvent('ox:setActiveCharacter', character.charId)
                end
            },
            {
                title = 'Smazat postavu',
                description = 'Mazání postav je momentálně zakázáno.',
                icon = 'trash',
                iconColor = '#ff6b6b',
                disabled = true
            }
        }
    })

    lib.showContext('multichar_char_detail')
end

local function buildAndShowMainMenu()
    local options = {}

    if #characters == 0 then
        table.insert(options, {
            title = 'Žádné postavy',
            description = 'Vytvoř novou postavu pro zahájení hraní.',
            icon = 'user-slash',
            readOnly = true
        })
    else
        for _, character in ipairs(characters) do
            local fullName = getDisplayName(character)
            local dob = formatDob(character)
            local lastPlayed = formatLastPlayed(character)
            local jobLabel = getJobLabel(character)

            table.insert(options, {
                title = fullName,
                description = ('Naposledy hráno: %s'):format(lastPlayed),
                icon = 'user',
                arrow = true,
                metadata = {
                    { label = 'Datum narození', value = dob },
                    { label = 'Zaměstnání', value = jobLabel },
                },
                onSelect = function()
                    openCharacterDetail(character)
                end
            })
        end
    end

    local limitReached = #characters >= maxSlots
    table.insert(options, {
        title = limitReached and ('Limit postav dosažen (%d/%d)'):format(#characters, maxSlots) or 'Vytvořit novou postavu',
        description = limitReached and 'Nemůžeš vytvořit další postavu.' or ('Volné sloty: %d/%d'):format(#characters, maxSlots),
        icon = 'user-plus',
        iconColor = limitReached and '#ff6b6b' or '#5f84ff',
        disabled = limitReached,
        onSelect = function()
            openOriginMenu()
        end
    })

    lib.registerContext({
        id = 'multichar_main_menu',
        title = 'Výběr postavy',
        canClose = false,
        options = options
    })

    lib.showContext('multichar_main_menu')
end

openSelection = function(charList)
    characters = charList or characters or {}
    ShutdownLoadingScreenNui()

    if not selectionOpen then
        selectionOpen = true
        setupCamera()
    end

    if #characters > 0 then
        previewCharacter(characters[1])
    end

    buildAndShowMainMenu()
end

RegisterNetEvent('ox:startCharacterSelect', function(_userId, charList)
    TriggerServerEvent('fr_multicharacter:enrichCharacters', charList)
end)

RegisterNetEvent('fr_multicharacter:openEnrichedSelection', function(charList, slotLimit)
    if slotLimit then
        maxSlots = slotLimit
    else
        TriggerServerEvent('fr_multicharacter:requestSlotLimit')
    end
    openSelection(charList)
end)

RegisterNetEvent('fr_multicharacter:slotLimit', function(limit)
    maxSlots = limit or 1
    if selectionOpen and lib.getOpenContextMenu() == 'multichar_main_menu' then
        buildAndShowMainMenu()
    end
end)

RegisterNetEvent('ox:setActiveCharacter', function(character)
    closeSelection()

    local ped = PlayerPedId()
    local coords, heading

    if character and character.isNew then
        local origin = selectedOrigin
        coords = Config.origins[origin] and Config.origins[origin].spawn or Config.newCharacterSpawn
        heading = Config.origins[origin] and Config.origins[origin].heading or Config.newCharacterHeading or 0.0
    else
        if character.coords then
            coords = character.coords
            heading = character.coords.w or character.heading or 0.0
        elseif character.x and character.y and character.z then
            coords = vec3(character.x, character.y, character.z)
            heading = character.heading or 0.0
        end
    end

    if coords then
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, heading)
        FreezeEntityPosition(ped, false)
    end
end)

RegisterNetEvent('ox:playerLoaded', function()
    Wait(1000)
    if GetResourceState('fr_hud') == 'started' then
        exports['fr_hud']:loadHud()
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    DoScreenFadeOut(0)
    Wait(250)

    if not selectionOpen then
        TriggerServerEvent('fr_multicharacter:requestSlotLimit')
        openSelection({})
    end
end)
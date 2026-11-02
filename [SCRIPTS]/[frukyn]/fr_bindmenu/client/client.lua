local userBinds = {}
local registeredKeys = {}

local POPULAR_KEYS = {
    { value = 'CUSTOM',   label = 'Vlastní klávesa' },

    { value = 'F1',       label = 'F1' },
    { value = 'F2',       label = 'F2' },
    { value = 'F3',       label = 'F3' },
    { value = 'F5',       label = 'F5' },
    { value = 'F6',       label = 'F6' },
    { value = 'F9',       label = 'F9' },
    { value = 'F10',      label = 'F10' },
    { value = 'F11',      label = 'F11' },

    { value = 'NUMPAD0',  label = 'Numpad 0' },
    { value = 'NUMPAD1',  label = 'Numpad 1' },
    { value = 'NUMPAD2',  label = 'Numpad 2' },
    { value = 'NUMPAD3',  label = 'Numpad 3' },
    { value = 'NUMPAD4',  label = 'Numpad 4' },
    { value = 'NUMPAD5',  label = 'Numpad 5' },
    { value = 'NUMPAD6',  label = 'Numpad 6' },
    { value = 'NUMPAD7',  label = 'Numpad 7' },
    { value = 'NUMPAD8',  label = 'Numpad 8' },
    { value = 'NUMPAD9',  label = 'Numpad 9' },

    { value = 'G',        label = 'G' },
    { value = 'H',        label = 'H' },
    { value = 'J',        label = 'J' },
    { value = 'K',        label = 'K' },
    { value = 'L',        label = 'L' },
    { value = 'X',        label = 'X' },
    { value = 'Z',        label = 'Z' },
    { value = 'U',        label = 'U' },
    { value = 'Y',        label = 'Y' },
    { value = 'B',        label = 'B' },
    { value = 'N',        label = 'N' },
    { value = 'M',        label = 'M' },

    { value = 'INSERT',   label = 'Insert' },
    { value = 'DELETE',   label = 'Delete' },
    { value = 'HOME',     label = 'Home' },
    { value = 'END',      label = 'End' },
    { value = 'PAGEUP',   label = 'Page Up' },
    { value = 'PAGEDOWN', label = 'Page Down' },
    { value = 'MINUS',    label = '-' },
    { value = 'EQUALS',   label = '=' },
    { value = 'GRAVE',    label = '~ / `' }
}

local function saveBinds()
    SetResourceKvp('custom_user_binds', json.encode(userBinds))
end

local function loadBinds()
    local raw = GetResourceKvpString('custom_user_binds')
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            userBinds = decoded
        end
    end
end

local function executeBindCommand(cmd)
    if not cmd or cmd == '' then return end
    if cmd:sub(1, 1) == '/' then
        cmd = cmd:sub(2)
    end
    ExecuteCommand(cmd)
end

local function registerKey(key)
    key = key:gsub('%s+', ''):upper()
    if registeredKeys[key] then return end
    registeredKeys[key] = true

    lib.addKeybind({
        name = ('user_bind_%s'):format(key:lower()),
        description = ('Vlastní bind pro klávesu: %s'):format(key),
        defaultKey = key,
        onPressed = function()
            local cmd = userBinds[key]
            if cmd and cmd ~= '' then
                executeBindCommand(cmd)
            end
        end
    })
end

local openBindMenu

local function editCommandDialog(key)
    local current = userBinds[key] or ''
    local input = lib.inputDialog(('Upravit bind [%s]'):format(key), {
        {
            type = 'input',
            label = 'Příkaz k vykonání',
            default = current,
            placeholder = 'e crossarms',
            required = true
        }
    })

    if not input then return openBindMenu() end

    local newCmd = input[1] and input[1]:gsub('^%s*(.-)%s*$', '%1')
    if newCmd and newCmd ~= '' then
        userBinds[key] = newCmd
        saveBinds()
        lib.notify({
            title = 'Bind Menu',
            description = ('Klávesa %s upravena na: /%s'):format(key, newCmd:gsub('^/', '')),
            type = 'success'
        })
    end

    openBindMenu()
end

local function openManageBindMenu(key)
    local currentCmd = userBinds[key]
    if not currentCmd then return openBindMenu() end

    local displayCmd = currentCmd:sub(1, 1) == '/' and currentCmd or ('/' .. currentCmd)

    lib.registerContext({
        id = 'manage_bind_sub',
        title = ('Správa klávesy: %s'):format(key),
        menu = 'player_binds_menu',
        options = {
            {
                title = 'Upravit příkaz',
                description = ('Aktuální příkaz: %s'):format(displayCmd),
                icon = 'pen-to-square',
                onSelect = function()
                    editCommandDialog(key)
                end
            },
            {
                title = 'Smazat bind',
                description = 'Odstraní příkaz přiřazený k této klávese',
                icon = 'trash',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Smazat bind?',
                        content = ('Opravdu chceš smazat bind pro klávesu **%s**?'):format(key),
                        centered = true,
                        cancel = true
                    })

                    if confirm == 'confirm' then
                        userBinds[key] = nil
                        saveBinds()
                        lib.notify({
                            title = 'Bind Menu',
                            description = ('Bind pro klávesu %s byl odstraněn.'):format(key),
                            type = 'info'
                        })
                        openBindMenu()
                    else
                        openManageBindMenu(key)
                    end
                end
            }
        }
    })

    lib.showContext('manage_bind_sub')
end

local function createBindDialog()
    local input = lib.inputDialog('Nový bind', {
        {
            type = 'select',
            label = 'Vyber klávesu',
            description = 'Vyber ze seznamu nebo zvol vlastní zadání',
            options = POPULAR_KEYS,
            default = 'NUMPAD1',
            required = true
        },
        {
            type = 'input',
            label = 'Vlastní klávesa (volitelné)',
            description = 'Vyplň pouze v případě, že jsi nahoře vybral "Vlastní klávesa"',
            placeholder = 'např. BACKSPACE, F8, O...'
        },
        {
            type = 'input',
            label = 'Příkaz',
            description = 'Použij příkaz s lomítkem a i bez něj',
            placeholder = 'e wave',
            required = true
        }
    })

    if not input then return openBindMenu() end

    local selectedOption = input[1]
    local customKeyInput = input[2]
    local cmd = input[3] and input[3]:gsub('^%s*(.-)%s*$', '%1')

    local targetKey = ''
    if selectedOption == 'CUSTOM' then
        targetKey = customKeyInput and customKeyInput:gsub('%s+', ''):upper() or ''
    else
        targetKey = selectedOption
    end

    if targetKey == '' or not cmd or cmd == '' then
        lib.notify({
            title = 'Chyba',
            description = 'Musíš vybrat platnou klávesu a vyplnit příkaz.',
            type = 'error'
        })
        return openBindMenu()
    end

    userBinds[targetKey] = cmd
    saveBinds()
    registerKey(targetKey)

    lib.notify({
        title = 'Bind Menu',
        description = ('Klávesa %s nastavena na: /%s'):format(targetKey, cmd:gsub('^/', '')),
        type = 'success'
    })

    openBindMenu()
end

openBindMenu = function()
    local options = {
        {
            title = 'Přidat nový bind',
            description = 'Vytvořit vlastní zkratku pro klávesu a příkaz',
            icon = 'plus',
            onSelect = function()
                createBindDialog()
            end
        }
    }

    local sortedKeys = {}
    for k in pairs(userBinds) do
        sortedKeys[#sortedKeys + 1] = k
    end
    table.sort(sortedKeys)

    for _, key in ipairs(sortedKeys) do
        local cmd = userBinds[key]
        local displayCmd = cmd:sub(1, 1) == '/' and cmd or ('/' .. cmd)

        options[#options + 1] = {
            title = ('Klávesa: [%s]'):format(key),
            description = ('Příkaz: %s'):format(displayCmd),
            icon = 'terminal',
            onSelect = function()
                openManageBindMenu(key)
            end
        }
    end

    lib.registerContext({
        id = 'player_binds_menu',
        title = 'Správce klávesových zkratek',
        options = options
    })

    lib.showContext('player_binds_menu')
end

CreateThread(function()
    loadBinds()
    for key in pairs(userBinds) do
        registerKey(key)
    end
end)

RegisterCommand('bindmenu', function()
    openBindMenu()
end, false)

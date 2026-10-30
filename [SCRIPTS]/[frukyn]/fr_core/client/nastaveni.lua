local isMeleeDisabled = false

lib.addRadialItem({ id = 'nastaveni', label = 'Nastavení', icon = 'gear', menu = 'nastaveni_main' })

lib.registerRadial({
    id = 'nastaveni_main',
    items = {
        {
            label = 'Přepnout mlácení R',
            icon = 'hand-fist',
            onSelect = function()
                isMeleeDisabled = not isMeleeDisabled
                if isMeleeDisabled then
                    lib.notify({ title = 'Nastavení', description = 'Mlácení R ZAKÁZÁNO', type = 'info' })
                else
                    lib.notify({ title = 'Nastavení', description = 'Mlácení R POVOLENO', type = 'info' })
                end
            end
        },
        {
            label = 'Přepnout chat',
            icon = 'comment-slash',
            onSelect = function()
                local isHidden = exports.chat:toggleChat()
                
                if isHidden then
                    lib.notify({ title = 'Nastavení', description = 'Chat byl SKRYT', type = 'info' })
                else
                    lib.notify({ title = 'Nastavení', description = 'Chat byl ZOBRAZEN', type = 'info' })
                end
            end
        },
        {
            label = 'Nastavení HUD',
            icon = 'user',
            onSelect = function()
                ExecuteCommand('hudsettings')
            end
        },
        {
            label = 'Pozice notifikací',
            icon = 'gear',
            onSelect = function()
                ExecuteCommand('ox_lib')
            end
        },
    }
})

CreateThread(function()
    while true do
        Wait(0)

        if isMeleeDisabled then
            DisableControlAction(0, 140, true) -- R
        end
    end
end)
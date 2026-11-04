local isMeleeDisabled = false

lib.addRadialItem({ id = 'nastaveni', label = 'Nastavení', icon = 'gear', menu = 'nastaveni_main' })
lib.addRadialItem({ id = 'carry', label = 'Nošení osob', icon = 'share', menu = 'carry_main' })
lib.addRadialItem({ id = 'skill', label = 'Dovednosti', icon = 'bolt', menu = 'skill_main' })
lib.addRadialItem({ id = 'report', label = 'Reportmenu', icon = 'file', menu = 'report_main' })


lib.registerRadial({
    id = 'carry_main',
    items = {
        {
            label = 'Přes záda',
            icon = 'share',
            onSelect = function()
                ExecuteCommand('carry')
            end
        },
    }
})

lib.registerRadial({
    id = 'skill_main',
    items = {
        {
            label = 'Menu dovedností',
            icon = 'bolt',
            onSelect = function()
                ExecuteCommand('skillmenu')
            end
        },
    }
})

lib.registerRadial({
    id = 'report_main',
    items = {
        {
            label = 'Otevřít report menu',
            icon = 'file',
            onSelect = function()
                ExecuteCommand('report')
            end
        },
    }
})

lib.registerRadial({
    id = 'nastaveni_main',
    items = {
        {
            label = 'Přepnout mlácení (R)',
            icon = 'hand-fist',
            onSelect = function()
                isMeleeDisabled = not isMeleeDisabled
                if isMeleeDisabled then
                    lib.notify({ title = 'Nastavení', description = 'Mlácení R ZAKÁZÁNO', type = 'warning' })
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
            label = 'Bindmenu',
            icon = 'keyboard',
            onSelect = function()
                ExecuteCommand('bindmenu')
            end
        },

        {
            label = 'Streamer mód',
            icon = 'video',
            onSelect = function()
                ExecuteCommand('streamermode')
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
            DisableControlAction(0, 140, true)
        end
    end
end)

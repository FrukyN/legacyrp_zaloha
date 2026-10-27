local Cart = {}
local CartTotal = 0
local CurrentShopData = {}
local ShopPeds = {}

local function groupDigits(value)
    local left, num, right = tostring(math.floor(tonumber(value) or 0)):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1 '):reverse()) .. right
end

local function UpdateCartUI()
    if #Cart > 0 then
        local text = "🛒 **Nákupní košík** \n\n"
        for i, item in ipairs(Cart) do
            text = text .. ("%sx %s - $%s\n"):format(item.count, item.label, groupDigits(item.price))
        end
        text = text .. "\n**Celkem: $" .. groupDigits(CartTotal) .. "**"
        lib.showTextUI(text, { position = "right-center" })
    else
        lib.hideTextUI()
    end
end

local function isShopOpen(shopConfig)
    local hours = GetClockHours()
    if shopConfig.hours.open < shopConfig.hours.close then
        return hours >= shopConfig.hours.open and hours < shopConfig.hours.close
    else
        return hours >= shopConfig.hours.open or hours < shopConfig.hours.close
    end
end

local function buildAccountOptions(accounts)
    local options = {}

    for i = 1, #accounts do
        local account = accounts[i]
        local label = ('%s - $%s'):format(account.label, groupDigits(account.balance))

        if account.isDefault then
            label = ('%s (hlavní)'):format(label)
        end

        options[#options + 1] = {
            value = tostring(account.id),
            label = label
        }
    end

    return options
end

local function selectBankAccount()
    local accounts = lib.callback.await('fr_shop:getBankAccounts', false)

    if not accounts or #accounts == 0 then
        lib.notify({ title = 'Chyba', description = 'Nemáš žádný účet, ze kterého lze platit.', type = 'error' })
        return nil
    end

    local input = lib.inputDialog('Výběr bankovního účtu', {
        {
            type = 'select',
            label = 'Účet',
            options = buildAccountOptions(accounts),
            default = tostring(accounts[1].id),
            required = true
        }
    })

    if not input then return nil end

    return tonumber(input[1])
end

local function OpenShelf(shopId, shelfIndex)
    local shop = Config.Shops[shopId]
    if not isShopOpen(shop) then
        lib.notify({title = 'Zavřeno', description = 'Tento obchod má momentálně zavřeno.', type = 'error'})
        return
    end

    CurrentShopData = lib.callback.await('fr_shop:getShopData', false) or {}
    local shelf = shop.shelves[shelfIndex]
    local options = {}

    for _, itemName in ipairs(shelf.items) do
        local itemCfg = Config.Items[itemName]
        local stockData = CurrentShopData[itemName]
        
        if stockData and stockData.count > 0 then
            table.insert(options, {
                title = itemCfg.label,
                description = ("Cena: $%s | Skladem: %s ks"):format(groupDigits(stockData.currentPrice), stockData.count),
                icon = Config.ImageURL .. itemName .. ".png",
                image = Config.ImageURL .. itemName .. ".png",
                onSelect = function()
                    local input = lib.inputDialog('Vložit do košíku', {
                        {type = 'number', label = 'Počet kusů', min = 1, max = stockData.count, default = 1}
                    })

                    if input and input[1] then
                        local count = math.floor(input[1])
                        local price = count * stockData.currentPrice
                        
                        table.insert(Cart, {
                            name = itemName,
                            label = itemCfg.label,
                            count = count,
                            price = price
                        })
                        
                        CartTotal = CartTotal + price
                        UpdateCartUI()
                        lib.notify({title = 'Přidáno do košíku', type = 'success'})
                    end
                end
            })
        end
    end

    if #options == 0 then
        table.insert(options, {title = "Prázdný regál", description = "Tento regál je momentálně vyprodaný.", disabled = true})
    end

    lib.registerContext({
        id = 'shop_shelf_menu',
        title = shelf.label,
        options = options
    })

    lib.showContext('shop_shelf_menu')
end

function Checkout(method)
    local accountId = nil

    if method == 'bank' then
        accountId = selectBankAccount()
        if not accountId then return end
    end

    local alert = lib.alertDialog({
        header = 'Chceš vytisknout účtenku?',
        content = 'Zvol si, zda chceš dostat potvrzení o nákupu.',
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Nechci',
            confirm = 'Ano, vytisknout'
        }
    })

    local printReceipt = (alert == 'confirm')

    lib.callback('fr_shop:checkout', false, function(success, message)
        if success then
            lib.notify({title = 'Nákup zaplacen', description = message, type = 'success'})
            Cart = {}
            CartTotal = 0
            UpdateCartUI()
        else
            lib.notify({title = 'Zamítnuto', description = message, type = 'error'})
        end
    end, Cart, method, accountId, printReceipt)
end

local function OpenRegister()
    if #Cart == 0 then
        lib.notify({title = 'Košík je prázdný', type = 'error'})
        return
    end

    local options = {
        {
            title = 'Platit hotově',
            description = 'Celková cena: $' .. groupDigits(CartTotal),
            icon = 'money-bill',
            onSelect = function() Checkout("cash") end
        },
        {
            title = 'Platit kartou',
            description = 'Celková cena: $' .. groupDigits(CartTotal),
            icon = 'credit-card',
            onSelect = function() Checkout("bank") end
        },
        {
            title = 'Vyprázdnit košík',
            icon = 'trash',
            onSelect = function()
                Cart = {}
                CartTotal = 0
                UpdateCartUI()
            end
        }
    }

    lib.registerContext({
        id = 'shop_register_menu',
        title = 'Pokladna',
        options = options
    })
    lib.showContext('shop_register_menu')
end

CreateThread(function()
    for shopId, shop in pairs(Config.Shops) do
        lib.requestModel(shop.register.pedModel)
        local ped = CreatePed(4, shop.register.pedModel, shop.register.coords.x, shop.register.coords.y, shop.register.coords.z - 1.0, shop.register.heading, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        table.insert(ShopPeds, ped)

        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'shop_register_'..shopId,
                icon = 'fas fa-cash-register',
                label = 'Přejít k pokladně',
                onSelect = function()
                    OpenRegister()
                end
            }
        })

        for i, shelf in ipairs(shop.shelves) do
            exports.ox_target:addBoxZone({
                coords = shelf.coords,
                size = vec3(1.5, 1.5, 2.0),
                rotation = 0.0,
                debug = false,
                options = {
                    {
                        name = 'shop_shelf_'..shopId..'_'..i,
                        icon = 'fas fa-shopping-basket',
                        label = 'Prohlédnout zboží (' .. shelf.label .. ')',
                        onSelect = function()
                            OpenShelf(shopId, i)
                        end
                    }
                }
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if GetCurrentResourceName() == resName then
        for _, ped in ipairs(ShopPeds) do
            DeletePed(ped)
        end
    end
end)

local ShopDoorStates = {}

CreateThread(function()
    while true do
        Wait(5000)
        
        for shopId, shop in pairs(Config.Shops) do
            if shop.doorlockId then
                local isOpen = isShopOpen(shop)
                local doorState = isOpen and 0 or 1 

                if ShopDoorStates[shopId] ~= doorState then
                    ShopDoorStates[shopId] = doorState
                    TriggerServerEvent('fr_shop:updateDoor', shop.doorlockId, doorState)
                end
            end
        end
    end
end)
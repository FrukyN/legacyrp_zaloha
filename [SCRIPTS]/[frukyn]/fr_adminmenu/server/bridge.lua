Bridge = {}

local Ox
if GetResourceState('ox_core') == 'started' then
    Ox = require '@ox_core.lib.init'
end

local function didAccountChange(result)
    if type(result) == 'table' and (result.next or result['then'] or result.__cfx_async_retval) then
        local ok, awaited = pcall(Citizen.Await, result)
        if not ok then return false end
        result = awaited
    end
    if type(result) == 'table' then return result.success ~= false end
    return result ~= false
end

function Bridge.getInfo(src) return {} end

function Bridge.addMoney(src, account, amount) return false end

function Bridge.removeMoney(src, account, amount) return false end

function Bridge.revive(src) end

if GetResourceState('ox_core') == 'started' then
    function Bridge.getInfo(src)
        local player = exports.ox_core:GetPlayer(src)
        if not player then return {} end

        -- ox_core ukládá data přímo do tabulky hráče
        local firstName = player.firstName or ''
        local lastName = player.lastName or ''
        local charName = (firstName .. ' ' .. lastName):gsub('^%s*(.-)%s*$', '%1')

        if charName == '' then 
            charName = GetPlayerName(src) 
        end

        local groups = type(player.getGroups) == 'function' and player:getGroups() or player.groups
        local primaryGroup = 'user'
        if type(groups) == 'table' then
            for name, grade in pairs(groups) do
                primaryGroup = name
                break
            end
        end

        return {
            charName = charName,
            group = primaryGroup,
            phone = player.phoneNumber or player.phone or 'Neznámé',
            states = ''
        }
    end

    function Bridge.addMoney(src, account, amount)
        local player = exports.ox_core:GetPlayer(src)
        if not player then return false end

        if account == 'cash' then
            return exports.ox_inventory:AddItem(src, 'money', amount)
        elseif account == 'black' then
            return exports.ox_inventory:AddItem(src, 'black_money', amount)
        elseif account == 'bank' then
            if not player.charId then return false end
            local bank = Ox.GetCharacterAccount(player.charId)
            if not bank then return false end
            local ok, result = pcall(function()
                return bank:addBalance({ amount = amount, message = 'Admin menu: úprava zůstatku' })
            end)
            return ok and didAccountChange(result)
        end
        return false
    end

    function Bridge.removeMoney(src, account, amount)
        local player = exports.ox_core:GetPlayer(src)
        if not player then return false end

        if account == 'cash' then
            return exports.ox_inventory:RemoveItem(src, 'money', amount)
        elseif account == 'black' then
            return exports.ox_inventory:RemoveItem(src, 'black_money', amount)
        elseif account == 'bank' then
            if not player.charId then return false end
            local bank = Ox.GetCharacterAccount(player.charId)
            if not bank then return false end
            local ok, result = pcall(function()
                return bank:removeBalance({ amount = amount, message = 'Admin menu: úprava zůstatku' })
            end)
            return ok and didAccountChange(result)
        end
        return false
    end
end

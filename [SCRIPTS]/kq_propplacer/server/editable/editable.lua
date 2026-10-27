
-- You can customize the permissions here

POLICY = {
    -- Whether the player can use the prop placer
    CanPlayerEdit = function(player)
        return IsPlayerAceAllowed(player, 'command')
    end,
}

RegisterCommand('propplacer', function(player)
    if not POLICY.CanPlayerEdit(player) then
        TriggerClientEvent('kq_link:client:notify', player, 'You do not have the permissions to use the Prop Placer', 'error')
        return
    end

    TriggerClientEvent('kq_propplacer:client:openEditor', player)
end, true)

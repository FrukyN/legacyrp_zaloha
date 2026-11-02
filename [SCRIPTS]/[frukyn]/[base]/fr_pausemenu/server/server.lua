lib.callback.register('fr_pausemenu:getCharData', function(source)
    local player = exports.ox_core:GetPlayer(source)

    if player and player.charId then
        local query =
        "SELECT firstName, lastName, DATE_FORMAT(dateOfBirth, '%d.%m.%Y') as dateOfBirth FROM characters WHERE charId = ?"
        local dbResult = exports.oxmysql:singleSync(query, { player.charId })

        if dbResult then
            return {
                firstName = dbResult.firstName,
                lastName = dbResult.lastName,
                dateOfBirth = dbResult.dateOfBirth
            }
        end
    end

    return nil
end)

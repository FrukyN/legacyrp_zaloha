
--- SQL Stuff
local SQL_DRIVER = Config.sql.driver
local function SqlQuery(query, data)
    if SQL_DRIVER == 'mysql' then
        return MySQL.Sync.fetchAll(query, data or {})
    end

    if SQL_DRIVER == 'oxmysql' then
        if Config.sql.newOxMysql then
            return exports[SQL_DRIVER]:fetchSync(query, data or {})
        end
        return exports[SQL_DRIVER]:query_async(query, data or {})
    else
        return exports[SQL_DRIVER]:executeSync(query, data or {})
    end
end

local function SqlMutate(query, data)
    if SQL_DRIVER == 'mysql' then
        return MySQL.Sync.insert(query, data)
    end

    if SQL_DRIVER == 'oxmysql' then
        return exports[SQL_DRIVER]:insert_async(query, data)
    else
        return exports[SQL_DRIVER]:executeSync(query, data)
    end
end


DB = {
    FetchProps = function(limit)
        local query = 'SELECT * FROM kq_propplacer ORDER BY id DESC LIMIT @limit'
        local data = {
            ['@limit'] = limit,
        }

        return SqlQuery(query, data)
    end,

    SaveNewProp = function(model, coords, rotation, metadata)
        local mutation = 'INSERT INTO kq_propplacer (`model`, `coords`, `rotation`, `metadata`) VALUES(@model, @coords, @rotation, @metadata);'
        local data = {
            ['@model'] = model,
            ['@coords'] = json.encode(coords),
            ['@rotation'] = json.encode(rotation),
            ['@metadata'] = json.encode(metadata),
        }

        return SqlMutate(mutation, data)
    end,

    UpdateProp = function(id, coords, rotation, metadata)
        local mutation = 'UPDATE kq_propplacer SET `coords` = @coords, `rotation` = @rotation, `metadata` = @metadata WHERE `id` = @id;'
        local data = {
            ['@id'] = id,
            ['@coords'] = json.encode(coords),
            ['@rotation'] = json.encode(rotation),
            ['@metadata'] = json.encode(metadata),
        }

        return SqlMutate(mutation, data)
    end,

    DeleteProp = function(id)
        local mutation = 'DELETE FROM kq_propplacer WHERE `id` = @id;'
        local data = {
            ['@id'] = id,
        }

        return SqlMutate(mutation, data)
    end,
}

DB.SqlMutate = SqlMutate
DB.SqlQuery = SqlQuery

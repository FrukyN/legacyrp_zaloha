local function EnsurePropPlacerTableExists()
    local query = [[
        SELECT COUNT(*) as count
        FROM information_schema.tables
        WHERE table_name = 'kq_propplacer'
    ]]
    
    local result = DB.SqlQuery(query)
    if result and result[1] and result[1].count == 0 then
        -- Table does not exist, create it
        local createQuery = [[
            CREATE TABLE IF NOT EXISTS `kq_propplacer` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `model` varchar(50) NOT NULL DEFAULT '0',
                `coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`coords`)),
                `rotation` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`rotation`)),
                `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
                PRIMARY KEY (`id`)
                ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
        ]]
        
        DB.SqlMutate(createQuery)
        print("^2kq_propplacer table created successfully.")
    end
end

Citizen.CreateThread(function()
    -- Call the function to ensure the table exists
    Citizen.SetTimeout(500, EnsurePropPlacerTableExists)
end)

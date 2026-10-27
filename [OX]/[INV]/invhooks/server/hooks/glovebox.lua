Hooks = Hooks or {}

local gloveboxSeatOverrides <const> = {
	default = { -1, 0 },
	-- only add vehicles IF you want to change the default -1 and 0 seats to access the glovebox
	-- so if you only want driver or passenger and not both add them, if you want front and back seat add all
	-- [Model Hash] = { valid seat indexes},
	-- i.e:
	-- [121658888] = { -1 }, -- only driver has access
	-- [121658888] = { -1, 0 }, -- pointless, already covered by default option
	-- [121658888] = { -1, 0, 1, 2 }, -- all occupants of a 4 seated vehicle have access
}

---@param payload OpenInventoryPayload
local function checkOpenInv(payload)
	lib.print.info('open inv payload', payload)

	local entity = NetworkGetEntityFromNetworkId(payload.netId)
	local vehicleModel = GetEntityModel(entity)
	local playerPed = GetPlayerPed(payload.source)
	local validSeats = gloveboxSeatOverrides[vehicleModel] or gloveboxSeatOverrides.default

	for i = 1, #validSeats do
		local seatedPed = GetPedInVehicleSeat(entity, validSeats[i])

		if playerPed == seatedPed then return true end
	end

	return false
end

Hooks.GloveBoxAccess = function ()

    RegisterHookAction('openInventory', checkOpenInv, nil, { "^glove[%w]+" })

	lib.print.info('Initialized Glovebox access openInventory hook')
end

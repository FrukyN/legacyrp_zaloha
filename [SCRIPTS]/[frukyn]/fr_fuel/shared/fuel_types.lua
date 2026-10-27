FuelTypes = FuelTypes or {}

local modelLookup

local function addModels(fuelType, models)
    for i = 1, #models do
        modelLookup[joaat(models[i])] = fuelType
    end
end

function FuelTypes.BuildModelLookup()
    if modelLookup then return modelLookup end

    modelLookup = {}
    addModels('electric', Config.ElectricModels or {})
    addModels('diesel', Config.DieselModels or {})

    return modelLookup
end

function FuelTypes.Exists(fuelType)
    return fuelType and Config.FuelTypes[fuelType] ~= nil
end

function FuelTypes.GetLabel(fuelType)
    local data = fuelType and Config.FuelTypes[fuelType]
    return data and data.label or tostring(fuelType)
end

function FuelTypes.GetExpectedType(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return Config.DefaultFuelType
    end

    local lookup = FuelTypes.BuildModelLookup()
    local modelFuelType = lookup[GetEntityModel(vehicle)]

    if modelFuelType then return modelFuelType end

    if not IsDuplicityVersion() then
        local class = GetVehicleClass(vehicle)

        if Config.DieselVehicleClasses and Config.DieselVehicleClasses[class] then
            return 'diesel'
        end
    end

    return Config.DefaultFuelType
end

function FuelTypes.GetPrices()
    local prices = GlobalState.frFuelPrices or {}
    local result = {}

    for fuelType, data in pairs(Config.FuelTypes) do
        result[fuelType] = prices[fuelType] or data.price
    end

    return result
end

function FuelTypes.FormatMoney(value)
    return ('$%s'):format(math.floor((tonumber(value) or 0) + 0.5))
end

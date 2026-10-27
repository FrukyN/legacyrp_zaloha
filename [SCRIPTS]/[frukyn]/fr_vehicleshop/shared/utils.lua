Utils = {}

local randomSeeded = false

local function ensureSeed()
    if randomSeeded then return end
    randomSeeded = true
    math.randomseed(GetGameTimer() + os.time())
end

function Utils.GeneratePlate(format)
    ensureSeed()
    local number = math.random(0, 9999)
    return (format or 'CW%04d'):format(number)
end

function Utils.Normalize(str)
    return (str or ''):lower():gsub('%s+', '')
end

function Utils.TableContains(tbl, val)
    if type(tbl) ~= 'table' then return false end
    for i = 1, #tbl do
        if tbl[i] == val then
            return true
        end
    end
    return false
end

function Utils.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

function Utils.Round(num)
    return math.floor((num or 0) + 0.5)
end

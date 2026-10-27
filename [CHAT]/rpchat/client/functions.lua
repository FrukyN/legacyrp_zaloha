local displayHeight = 1
local FontId

local function getRobotoFont()
    if not FontId then
        RegisterFontFile('ChakraPetch-Regular')
        FontId = RegisterFontId('ChakraPetch-Regular')
    end
    return FontId
end

local function displayTemporaryText(mePlayer, text, offset, duration, drawFn, zOffset)
    Citizen.CreateThread(function()
        displayHeight = displayHeight + 1

        local endTime = GetGameTimer() + duration
        while GetGameTimer() < endTime do
            local targetPed = GetPlayerPed(mePlayer)
            if targetPed ~= 0 then
                local coordsMe = GetEntityCoords(targetPed, false)
                local coords = GetEntityCoords(PlayerPedId(), false)

                if #(coordsMe - coords) < 22.36 then
                    drawFn(coordsMe.x, coordsMe.y, coordsMe.z + offset + zOffset, text)
                end
            end

            Wait(0)
        end

        displayHeight = displayHeight - 1
    end)
end

function DisplayDo(mePlayer, text, offsetme)
    displayTemporaryText(mePlayer, text, offsetme, wx.MeDoDisplayTime, DrawText3Dme, -0.550)
end

function DisplayMe(mePlayer, text, offsetdo)
    displayTemporaryText(mePlayer, text, offsetdo, wx.MeDoDisplayTime, DrawText3Ddo, -1.850)
end

function DisplayDoa(mePlayer, text, offsetdoa)
    displayTemporaryText(mePlayer, text, offsetdoa, 1500, DrawText3Ddoa, -1.250)
end

local function draw3DText(x, y, z, text, factorDivisor, rectY, rectWidth, rectAlpha)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then
        return
    end

    SetTextFont(getRobotoFont())
    SetTextScale(0.33, 0.30)
    SetTextDropshadow(10, 100, 100, 100, 255)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(screenX, screenY)

    local factor = (string.len(text)) / factorDivisor
    DrawRect(screenX, screenY + rectY, rectWidth + factor, 0.03, 0, 0, 0, rectAlpha)
end

function DrawText3Dme(x, y, z, text)
    draw3DText(x, y, z, text, 350, 0.0135, 0.025, 30)
end

function DrawText3Ddo(x, y, z, text)
    draw3DText(x, y, z, text, 370, 0.0135, 0.025, 10)
end

function DrawText3Ddoa(x, y, z, text)
    draw3DText(x, y, z, text, 370, 0.0145, 0.030, 10)
end

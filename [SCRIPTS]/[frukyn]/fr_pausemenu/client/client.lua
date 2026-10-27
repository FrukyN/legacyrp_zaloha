local charData = { fullname = "Načítání...", birth = "" }
local currentHintFormatted = ""

local hints = {
    "Nastavení klávesových zkratek najdeš v NASTAVENÍ > BINDY > FIVEM",
    "Ve vozidle se doporučujeme poutat",
    "Užívej si HRU!!!",
    "Veškeré chyby nahlaste na discord",
    "Vaše nápady piště na discord",
}

local function makeFontText(text)
    return ("<FONT FACE='ChakraPetch-Regular'>%s</FONT>"):format(text)
end

local function fetchCharacterData()
    local data = lib.callback.await('fr_pausemenu:getCharData', 1000)

    if data then
        local first = data.firstName or "Neznámé"
        local last = data.lastName or "Jméno"
        local birth = data.dateOfBirth or "00.00.0000"

        charData = {
            fullname = makeFontText(first .. " " .. last),
            birth = makeFontText(birth)
        }
    else
        charData = {
            fullname = makeFontText("Neznámé Jméno"),
            birth = makeFontText("00.00.0000")
        }
    end
end

local serverTitle = makeFontText(" Hexagon Roleplay")

RegisterNetEvent('ox:playerLoaded', function()
    fetchCharacterData()
end)

CreateThread(function()
    Wait(1000)
    fetchCharacterData()
end)

CreateThread(function()
    while true do
        currentHintFormatted = makeFontText(hints[math.random(#hints)])
        Wait(140000)
    end
end)

CreateThread(function()
    while true do
        if IsPauseMenuActive() then
            BeginScaleformMovieMethodOnFrontendHeader("SHIFT_CORONA_DESC")
            ScaleformMovieMethodAddParamBool(true)
            EndScaleformMovieMethod()

            BeginScaleformMovieMethodOnFrontendHeader("SET_HEADER_TITLE")
            ScaleformMovieMethodAddParamTextureNameString(serverTitle)
            ScaleformMovieMethodAddParamBool(true)
            ScaleformMovieMethodAddParamTextureNameString(currentHintFormatted)
            ScaleformMovieMethodAddParamBool(true)
            EndScaleformMovieMethod()

            BeginScaleformMovieMethodOnFrontendHeader("SET_HEADING_DETAILS")
            ScaleformMovieMethodAddParamTextureNameString(charData.fullname)
            ScaleformMovieMethodAddParamTextureNameString(charData.birth)
            ScaleformMovieMethodAddParamTextureNameString("")
            ScaleformMovieMethodAddParamBool(false)
            EndScaleformMovieMethod()

            Wait(1)
        else
            Wait(600)
        end
    end
end)

local function AddFontTextEntry(entry, text)
    AddTextEntry(entry, "<FONT FACE='ChakraPetch-Regular'> " .. text .. " </FONT>")
end

CreateThread(function()
    ReplaceHudColourWithRgba(117, 12, 15, 28, 220)
    ReplaceHudColourWithRgba(116, 95, 132, 255, 245)
    ReplaceHudColourWithRgba(142, 95, 132, 255, 255)

    AddFontTextEntry("PM_SCR_MAP", "Mapa")
    AddFontTextEntry("PM_SCR_STA", "Status")
    AddFontTextEntry("PM_SCR_GAM", "Hra")
    AddFontTextEntry("PM_SCR_INF", "Informace")
    AddFontTextEntry("PM_SCR_SET", "Nastavení")
    AddFontTextEntry("PM_SCR_GAL", "Galerie")

    AddFontTextEntry("PM_PANE_LEAVE", "Odpojit se ze serveru")
    AddFontTextEntry("PM_PANE_QUIT", "Vypnout hru")
end)

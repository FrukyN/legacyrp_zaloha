local initialized = false

local activeHudComponents = {}
for k, v in pairs(Config.RemoveHudComponents) do
    if v then activeHudComponents[#activeHudComponents + 1] = k end
end

local SUPPRESSED_MODELS = { `JET`, `LAZER`, `TITAN`, `BARRACKS`, `BARRACKS2`, `CRUSADER`, `RHINO`, `BLIMP` }

local function initialize()
    if initialized then return end
    initialized = true

    local playerId = cache.playerId

    if Config.DisableHealthRegeneration then SetPlayerHealthRechargeMultiplier(playerId, 0.0) end
    if Config.DisableVehicleRewards then DisablePlayerVehicleRewards(playerId) end
    if Config.DisableAimAssist then SetPlayerTargetingMode(3) end
    if Config.DisablePlayerCover then SetPlayerCanUseCover(playerId, false) end
    if Config.DisableRandomEvents then SetRandomEventFlag(false) end
    if Config.DisableDeepOceanWaves then SetDeepOceanScaler(0.0) end
    if Config.DisablePoliceScannerAudio then SetAudioFlag("PoliceScannerDisabled", true) end
    if Config.DisableFlightMusic then SetAudioFlag("DisableFlightMusic", true) end

    if Config.DisableAudioScenes then
        StartAudioScene("DLC_MPHEIST_TRANSITION_TO_APT_FADE_IN_RADIO_SCENE")
        StartAudioScene("FBI_HEIST_H5_MUTE_AMBIENCE_SCENE")
        StartAudioScene("CHARACTER_CHANGE_IN_SKY_SCENE")
    end

    if Config.DisableStaticEmitters then
        SetStaticEmitterEnabled("LOS_SANTOS_VANILLA_UNICORN_01_STAGE", false)
        SetStaticEmitterEnabled("LOS_SANTOS_VANILLA_UNICORN_02_MAIN_ROOM", false)
        SetStaticEmitterEnabled("LOS_SANTOS_VANILLA_UNICORN_03_BACK_ROOM", false)
    end

    SetAmbientZoneListStatePersistent("AZL_DLC_Hei4_Island_Disabled_Zones", false, true)
    SetAmbientZoneListStatePersistent("AZL_DLC_Hei4_Island_Zones", true, true)

    if Config.DisableDispatchServices then
        for i = 0, 15 do EnableDispatchService(i, false) end
        SetGarbageTrucks(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        DistantCopCarSirens(false)
    end

    local relationshipTypes = {
        `GANG_1`, `GANG_2`, `GANG_9`, `GANG_10`, `AMBIENT_GANG_LOST`, `AMBIENT_GANG_MEXICAN`,
        `AMBIENT_GANG_FAMILY`, `AMBIENT_GANG_BALLAS`, `AMBIENT_GANG_MARABUNTE`, `AMBIENT_GANG_CULT`,
        `AMBIENT_GANG_SALVA`, `AMBIENT_GANG_WEICHENG`, `AMBIENT_GANG_HILLBILLY`, `DEALER`, `COP`,
        `PRIVATE_SECURITY`, `SECURITY_GUARD`, `ARMY`, `MEDIC`, `FIREMAN`, `HATES_PLAYER`
    }
    for _, relationship in ipairs(relationshipTypes) do
        SetRelationshipBetweenGroups(1, relationship, `PLAYER`)
        SetRelationshipBetweenGroups(1, `PLAYER`, relationship)
    end
end

AddEventHandler('playerSpawned', initialize)
AddEventHandler('onClientResourceStart', function(resName)
    if GetCurrentResourceName() == resName then initialize() end
end)

CreateThread(function()
    while true do
        Wait(0)

        for i = 1, #activeHudComponents do
            HideHudComponentThisFrame(activeHudComponents[i])
        end

        if Config.DisableDisplayAmmo then
            DisplayAmmoThisFrame(false)
        end

        SetVehicleDensityMultiplierThisFrame(Config.TrafficDensity)
        SetPedDensityMultiplierThisFrame(Config.PedDensity)
        SetRandomVehicleDensityMultiplierThisFrame(Config.TrafficDensity)
        SetParkedVehicleDensityMultiplierThisFrame(Config.TrafficDensity)
        SetScenarioPedDensityMultiplierThisFrame(Config.PedDensity, Config.PedDensity)

        if Config.DisableAirControl and cache.vehicle then
            if IsEntityInAir(cache.vehicle) then
                DisableControlAction(0, 59, true) -- Left/Right
                DisableControlAction(0, 60, true) -- Up/Down
            end
        end

        if isMeleeDisabled then
            DisableControlAction(0, 140, true) -- R
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        for i = 1, #SUPPRESSED_MODELS do
            SetVehicleModelIsSuppressed(SUPPRESSED_MODELS[i], true)
        end

        RemoveAllPickupsOfType(`PICKUP_WEAPON_GolfClub`)
        RemoveAllPickupsOfType(`PICKUP_WEAPON_CARBINERIFLE`)
        RemoveAllPickupsOfType(`PICKUP_WEAPON_PISTOL`)

        if Config.DisableNPCDrops then
            -- Efektivnější způsob iterace přes existující pedy pomocí GetGamePool
            local peds = GetGamePool('CPed')
            for i = 1, #peds do
                local npc = peds[i]
                if not IsEntityDead(npc) then
                    SetPedDropsWeaponsWhenDead(npc, false)
                end
            end
        end
    end
end)

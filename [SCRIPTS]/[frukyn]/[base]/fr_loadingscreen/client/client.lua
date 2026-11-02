local spawn = false

AddEventHandler("playerSpawned", function()
    if not spawn then
        ShutdownLoadingScreen()
        spawn = true
    end
end)
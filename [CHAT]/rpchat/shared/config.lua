local wx = {}

wx.MaxDocCount = 60 -- Maximum /doc time player can do
wx.MeDoDisplayTime = 5000 -- [in ms] How long should /me and /do 3D texts be displayed
wx.OnlyInicials = true -- In commands like /me, /do, use only char name inicials. (John Doe -> J. D.)
wx.TransparentStatusHere = false -- Enable transparent background for /here and /status texts

Notify = function(title,desc)
    lib.notify({
        title = title,
        description = desc,
         duration = 5000
    })
end
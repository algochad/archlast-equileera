core.register_on_joinplayer(function(player)
    player:set_lighting({
		shadows = { intensity = 0.33 },
		volumetric_light = { strength = 0.45 },
		exposure = {
			luminance_min = -3.5,
			luminance_max = -2.5,
			exposure_correction = 0.35,
			speed_dark_bright = 1500,
			speed_bright_dark = 700,
		},
		saturation = 1.1,
	})
end)

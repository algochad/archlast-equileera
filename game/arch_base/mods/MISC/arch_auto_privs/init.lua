-- arch_auto_privs: Auto-grants fly, fast, noclip, server to creative players or singleplayer host
-- Solves "no fly priv" and "no permission" errors for /time, /giveme, etc. in creative/singleplayer

local AUTO_PRIVS = {"fly", "fast", "noclip", "server", "give", "teleport", "settime", "debug"}

local function grant_privs(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	local privs = minetest.get_player_privs(name)
	local changed = false
	-- Grant if singleplayer OR if player has creative privilege
	local should_grant = minetest.is_singleplayer() or privs.creative
	if should_grant then
		for _, p in ipairs(AUTO_PRIVS) do
			if not privs[p] then
				privs[p] = true
				changed = true
			end
		end
	end
	if changed then
		minetest.set_player_privs(name, privs)
		minetest.log("action", "[arch_auto_privs] Granted privs to " .. name)
	end
end

-- Grant on join
minetest.register_on_joinplayer(function(player)
	grant_privs(player)
end)

-- Re-check periodically (1Hz) in case creative mode is toggled mid-session
local accum = 0
minetest.register_globalstep(function(dtime)
	accum = accum + dtime
	if accum < 1.0 then return end
	accum = 0
	for _, player in ipairs(minetest.get_connected_players()) do
		grant_privs(player)
	end
end)
-- arch_thirdperson - Improved third-person camera
-- Based on ctf-improvedthirdperson by fancyfinn9
-- Adapted: no ctf_settings dependency, uses native set_eye_offset + chat toggle
-- Note: raised left arm in third-person is Mineclonia's default idle animation pose
-- (baked into character.b3d keyframes, not fixable via Lua bone overrides alone)
-- SPDX-License-Identifier: MIT

local TP_OFFSET_FIRST = {x = 0, y = 0, z = 0}
local TP_OFFSET_THIRD = {x = 8, y = 4, z = -1}

-- Per-player state: true = third-person offset active
local player_tp = {}

local function apply_offset(player, third_person)
	if not player or not player:is_player() then return end
	if third_person then
		player:set_eye_offset(TP_OFFSET_FIRST, TP_OFFSET_THIRD)
	else
		player:set_eye_offset(TP_OFFSET_FIRST, TP_OFFSET_FIRST)
	end
end

minetest.register_on_joinplayer(function(player)
	-- Default: third-person ON for new joins (user can toggle off)
	player_tp[player:get_player_name()] = true
	apply_offset(player, true)
end)

minetest.register_on_leaveplayer(function(player)
	player_tp[player:get_player_name()] = nil
end)

minetest.register_chatcommand("thirdperson", {
	description = "Toggle improved third-person camera offset",
	privs = {},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end
		local current = player_tp[name] or false
		local next_state = not current
		player_tp[name] = next_state
		apply_offset(player, next_state)
		if next_state then
			return true, "Third-person camera: ON (offset x=8 y=4 z=-1)"
		else
			return true, "Third-person camera: OFF (default offset)"
		end
	end,
})
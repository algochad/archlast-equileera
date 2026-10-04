-- arch_thirdperson - Improved third-person camera
-- Based on ctf-improvedthirdperson by fancyfinn9
-- Adapted: no ctf_settings dependency, uses native set_eye_offset + chat toggle
-- Leveling: third-person offset sits at shoulder height so the camera looks
-- level (not top-down) and the center-screen crosshair ray travels at
-- shoulder height when looking straight. The engine crosshair is always
-- screen-center (true aim); moving the HUD image off-center would lie about
-- aim, so we keep it centered and level the camera instead.
-- Note: in third-person FRONT view the screen-left raised arm is the player's
-- RIGHT hand holding the wielded hotbar item (mcl_player/animations.lua "when
-- holding an item" branch pitches Arm_Right_Pitch_Control forward).
-- Select an empty hotbar slot or use F5 third-person-back view and the arm rests.
-- Stand keyframes (frames 0-79) are neutral; this mod never drives arm bones.
-- SPDX-License-Identifier: MIT

local OFFSET_FIRST = {x = 0, y = 0, z = 0}
-- Shoulder-level default: ~1.0 node to the side, ~0.2 below eye height,
-- no forward push. Engine unit: 10 = 1 node. Eye is at 16.2, so y=-2
-- puts the ray at ~14.2 (~1.4 nodes, shoulder height). x=10 pushes the
-- model clear of the center crosshair.
local DEFAULT_THIRD = {x = 10, y = -2, z = 0}

-- Per-player state
local player_tp = {}      -- name -> bool (true = third-person offset active)
local player_offset = {}  -- name -> {x,y,z}

local function copy_offset(o)
	return {x = o.x, y = o.y, z = o.z}
end

local function clamp_num(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Engine clamps third-person offsets to [-10,-10,-5]..[10,15,5]; mirror that
-- here so /thirdperson feedback matches what the engine will actually use.
local function clamp_offset(o)
	return {
		x = clamp_num(o.x or 0, -10, 10),
		y = clamp_num(o.y or 0, -10, 15),
		z = clamp_num(o.z or 0, -5, 5),
	}
end

local function offset_to_string(o)
	return string.format("x=%g y=%g z=%g", o.x, o.y, o.z)
end

local function apply_offset(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	if player_tp[name] then
		local off = player_offset[name] or DEFAULT_THIRD
		-- Pass third-person offset twice so back and front views level together
		-- (front defaults to back if omitted; explicit is clearer).
		player:set_eye_offset(OFFSET_FIRST, off, off)
	else
		player:set_eye_offset(OFFSET_FIRST, OFFSET_FIRST, OFFSET_FIRST)
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	-- Default: third-person ON for new joins (user can toggle off)
	player_tp[name] = true
	if not player_offset[name] then
		player_offset[name] = copy_offset(DEFAULT_THIRD)
	end
	apply_offset(player)
	minetest.log("action", "[ARCH:CAMERA] third-person ON for " .. name
		.. " offset=(" .. offset_to_string(player_offset[name]) .. ")")
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	player_tp[name] = nil
	player_offset[name] = nil
end)

-- Eye offsets can be reset by death/detach flows; re-apply ours on respawn.
minetest.register_on_respawnplayer(function(player)
	if not player or not player:is_player() then return end
	apply_offset(player)
end)

-- Re-assert shoulder offset every frame if another mod (3d_armor_hover, mcl_cozy)
-- overwrote it, but yield to mounts/sleep (player:get_attach() ~= nil).
local reassert_accum = 0
minetest.register_globalstep(function(dtime)
	reassert_accum = reassert_accum + dtime
	if reassert_accum < 0.2 then return end -- throttle to 5Hz
	reassert_accum = 0
	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		if player_tp[name] and not player:get_attach() then
			-- Check if mcl_cozy has this player in a seated/sleeping state
			local cozy_active = false
			if mcl_cozy and mcl_cozy.players and mcl_cozy.players[name] then
				cozy_active = true
			end
			if not cozy_active then
				apply_offset(player)
			end
		end
	end
end)

minetest.register_chatcommand("thirdperson", {
	description = "Toggle third-person shoulder camera. Usage: /thirdperson [on|off|reset|get|x y z]",
	privs = {},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end
		local args = {}
		for word in string.gmatch(param or "", "%S+") do
			args[#args + 1] = word
		end
		local cmd = args[1]

		if cmd == "get" then
			local on = player_tp[name]
			local off = player_offset[name] or DEFAULT_THIRD
			return true, string.format("Third-person: %s offset=(%s)",
				on and "ON" or "OFF", offset_to_string(off))
		end

		if cmd == "reset" then
			player_tp[name] = true
			player_offset[name] = copy_offset(DEFAULT_THIRD)
			apply_offset(player)
			minetest.log("action", "[ARCH:CAMERA] " .. name .. " reset offset=("
				.. offset_to_string(player_offset[name]) .. ")")
			return true, "Third-person camera reset to shoulder-level ("
				.. offset_to_string(player_offset[name]) .. ")"
		end

		if cmd == "on" or cmd == "off" then
			local next_state = (cmd == "on")
			player_tp[name] = next_state
			apply_offset(player)
			if next_state then
				return true, "Third-person camera: ON ("
					.. offset_to_string(player_offset[name] or DEFAULT_THIRD) .. ")"
			else
				return true, "Third-person camera: OFF (default offset)"
			end
		end

		-- Three numbers: live-tune the offset, e.g. /thirdperson 6 -2 0
		if #args == 3 then
			local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
			if x and y and z then
				player_offset[name] = clamp_offset({x = x, y = y, z = z})
				player_tp[name] = true
				apply_offset(player)
				minetest.log("action", "[ARCH:CAMERA] " .. name .. " set offset=("
					.. offset_to_string(player_offset[name]) .. ")")
				return true, "Third-person camera: ON ("
					.. offset_to_string(player_offset[name]) .. ")"
			else
				return false, "Usage: /thirdperson [on|off|reset|get|x y z]"
			end
		end

		-- Bare command: toggle (backwards compatible)
		if #args == 0 then
			local current = player_tp[name] or false
			local next_state = not current
			player_tp[name] = next_state
			apply_offset(player)
			if next_state then
				return true, "Third-person camera: ON ("
					.. offset_to_string(player_offset[name] or DEFAULT_THIRD) .. ")"
			else
				return true, "Third-person camera: OFF (default offset)"
			end
		end

		return false, "Usage: /thirdperson [on|off|reset|get|x y z]"
	end,
})

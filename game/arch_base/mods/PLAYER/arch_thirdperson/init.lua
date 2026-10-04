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
-- Turn-speed "motion feel": true per-pixel motion blur is impossible from Lua
-- (no post-effect API; bloom/exposure in set_lighting can't smear frames).
-- Instead this mod widens FOV proportional to yaw rate via mcl_fovapi, which
-- reads as speed/blur on turns in ALL view modes (first + third person).
-- Tunables below; /thirdperson blur <amount 0..10|off> live-tunes it.

local OFFSET_FIRST = {x = 0, y = 0, z = 0}
-- Shoulder-level default: ~1.0 node to the side, ~0.2 below eye height,
-- no forward push. Engine unit: 10 = 1 node. Eye is at 16.2, so y=-2
-- puts the ray at ~14.2 (~1.4 nodes, shoulder height). x=10 pushes the
-- model clear of the center crosshair.
local DEFAULT_THIRD = {x = 10, y = -2, z = 0}

-- Per-player state
local player_tp = {}      -- name -> bool (true = third-person offset active)
local player_offset = {}  -- name -> {x,y,z}

-- Turn-blur tuning (FOV multiplier widens with yaw rate; eases back when still)
local BLUR_MOD_NAME = "arch_thirdperson:turn_blur"
local BLUR_DEFAULT_AMOUNT = 5        -- default 0..10 scale
local BLUR_MAX_MULT = 1.18           -- FOV multiplier at full deflection (amount=10)
local BLUR_YAW_FULL = 4.5            -- rad/s yaw rate that counts as "full" turn
local BLUR_APPLY_TIME = 0.12         -- fovapi transition seconds when engaging
local BLUR_RESET_TIME = 0.35         -- fovapi transition seconds when easing back
local BLUR_IDLE_CUTOFF = 0.35        -- below this rad/s, blur eases out

local player_blur = {}    -- name -> amount 0..10 (0 = off)
local player_last_yaw = {}-- name -> last get_look_horizontal()
local player_blur_on = {} -- name -> bool (modifier currently applied)

-- Register the FOV modifier (mcl_fovapi loads before us via depends).
if minetest.global_exists("mcl_fovapi") then
	mcl_fovapi.register_modifier({
		name = BLUR_MOD_NAME,
		fov_factor = 1.0, -- placeholder; real value set per update below
		time = BLUR_APPLY_TIME,
		reset_time = BLUR_RESET_TIME,
		is_multiplier = true,
		exclusive = false,
	})
end

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
-- Turn-speed blur: widen FOV with yaw rate (all view modes), ease back idle.
-- fovapi-compliant: mutate the registered modifier's fov_factor, apply/remove.
local function update_turn_blur(player, dtime)
	if not player or not player:is_player() then return end
	if not minetest.global_exists("mcl_fovapi") then return end
	if dtime <= 0 then return end
	local name = player:get_player_name()
	local amount = player_blur[name]
	if amount == nil then amount = BLUR_DEFAULT_AMOUNT end
	if amount <= 0 then
		if player_blur_on[name] then
			mcl_fovapi.remove_modifier(player, BLUR_MOD_NAME)
			player_blur_on[name] = false
		end
		player_last_yaw[name] = player:get_look_horizontal()
		return
	end
	local yaw = player:get_look_horizontal()
	local last = player_last_yaw[name]
	player_last_yaw[name] = yaw
	if last == nil then return end
	-- Shortest-arc yaw delta (handles -pi/pi wrap)
	local dyaw = yaw - last
	if dyaw > math.pi then dyaw = dyaw - 2 * math.pi end
	if dyaw < -math.pi then dyaw = dyaw + 2 * math.pi end
	local rate = math.abs(dyaw) / dtime
	if rate < BLUR_IDLE_CUTOFF then
		if player_blur_on[name] then
			mcl_fovapi.remove_modifier(player, BLUR_MOD_NAME, BLUR_RESET_TIME)
			player_blur_on[name] = false
		end
		return
	end
	local deflection = math.min(rate / BLUR_YAW_FULL, 1.0)
	local strength = (amount / 10) * deflection
	local mult = 1.0 + (BLUR_MAX_MULT - 1.0) * strength
	mcl_fovapi.registered_modifiers[BLUR_MOD_NAME].fov_factor = mult
	if not player_blur_on[name] then
		mcl_fovapi.apply_modifier(player, BLUR_MOD_NAME, BLUR_APPLY_TIME)
		player_blur_on[name] = true
	else
		-- Already applied: re-apply refreshed factor (fovapi skips if present,
		-- so remove+apply to push the new multiplier).
		mcl_fovapi.remove_modifier(player, BLUR_MOD_NAME, 0)
		mcl_fovapi.apply_modifier(player, BLUR_MOD_NAME, BLUR_APPLY_TIME)
	end
end

-- Drive blur from the player globalstep (runs for every player each tick).
if minetest.global_exists("mcl_player") and mcl_player.register_globalstep then
	mcl_player.register_globalstep(function(player, dtime)
		update_turn_blur(player, dtime)
	end)
else
	minetest.register_globalstep(function(dtime)
		for _, player in ipairs(minetest.get_connected_players()) do
			update_turn_blur(player, dtime)
		end
	end)
end


minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	-- Default: third-person ON for new joins (user can toggle off)
	player_tp[name] = true
	if not player_offset[name] then
		player_offset[name] = copy_offset(DEFAULT_THIRD)
	end
	apply_offset(player)
	if player_blur[name] == nil then
		player_blur[name] = BLUR_DEFAULT_AMOUNT
	end
	player_last_yaw[name] = nil
	player_blur_on[name] = false
	minetest.log("action", "[ARCH:CAMERA] third-person ON for " .. name
		.. " offset=(" .. offset_to_string(player_offset[name]) .. ")")
end)

minetest.register_on_leaveplayer(function(player)
	player_tp[name] = nil
	player_offset[name] = nil
	player_blur[name] = nil
	player_last_yaw[name] = nil
	player_blur_on[name] = nil
end)

-- Eye offsets can be reset by death/detach flows; re-apply ours on respawn.
minetest.register_on_respawnplayer(function(player)
	if not player or not player:is_player() then return end
	apply_offset(player)
end)

minetest.register_chatcommand("thirdperson", {
	description = "Third-person shoulder camera + turn-blur. Usage: /thirdperson [on|off|reset|get|x y z|blur [get|off|<0..10>]]",
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
		if cmd == "blur" then
			local sub = args[2]
			if sub == "get" or sub == nil then
				local amt = player_blur[name]
				if amt == nil then amt = BLUR_DEFAULT_AMOUNT end
				return true, string.format("Turn blur: %s (amount %g/10)",
					amt > 0 and "ON" or "OFF", amt)
			end
			if sub == "off" then
				player_blur[name] = 0
				if player_blur_on[name] and minetest.global_exists("mcl_fovapi") then
					local pl = minetest.get_player_by_name(name)
					if pl then mcl_fovapi.remove_modifier(pl, BLUR_MOD_NAME) end
					player_blur_on[name] = false
				end
				return true, "Turn blur: OFF"
			end
			local amt = tonumber(sub)
			if amt then
				amt = math.max(0, math.min(10, amt))
				player_blur[name] = amt
				minetest.log("action", "[ARCH:CAMERA] " .. name
					.. " turn blur amount=" .. amt)
				if amt > 0 then
					return true, string.format("Turn blur: ON (amount %g/10)", amt)
				else
					return true, "Turn blur: OFF"
				end
			end
			return false, "Usage: /thirdperson blur [get|off|<0..10>]"
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
				return false, "Usage: /thirdperson [on|off|reset|get|x y z|blur [get|off|<0..10>]]"
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

		return false, "Usage: /thirdperson [on|off|reset|get|x y z|blur [get|off|<0..10>]]"
	end,
})

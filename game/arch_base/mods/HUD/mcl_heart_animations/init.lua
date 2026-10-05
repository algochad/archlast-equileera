-- mcl_heart_animations: Minecraft-like heart bar animations for Arch Base.
--
-- Flashes the hudbars "health" statbar white on damage (3x) / heal (2x),
-- and jitters the bar offsets while at 4 HP or less (low-health shake).
--
-- Arch Base port notes (upstream: https://github.com/fennelfox/mcl_heart_animations):
-- * Upstream draws 10 duplicate per-heart statbars with hardcoded offsets and
--   hides the hudbars "health" bar every globalstep. This port instead animates
--   the existing hudbars statbar in place via hud_change, so status icons keep
--   working (poison hbhunger_icon_health_poison.png, regen
--   hudbars_icon_regenerate.png, frozen frozen_heart.png from mcl_potions /
--   mcl_powder_snow) and no duplicate hearts are drawn.
-- * Upstream hardcodes offsets {-258, -110} which only match the default
--   statbar_modern zigzag slot 0 (health). This port reads the live hudbars
--   offset via player:hud_get and only jitters y around it, so custom
--   hudbars_sorting / hudbars_start_statbar_offset_* settings keep working.
-- * Upstream has no leaveplayer cleanup (leaks per-player tables) and its
--   minetest.after flash callbacks can fire for offline players. Fixed here.
-- * Upstream checks `hp_change >= 1` for the heal branch; hp_change can be a
--   fractional float in Mineclonia, so any positive delta counts as a heal.

local FLASH_ON_MOD = "^[brighten"
local FLASH_PERIOD = 0.15

local SHAKE_HP_THRESHOLD = 4
local SHAKE_AMOUNT = 2

local shake_base_y = {}

local function set_flash(player, on)
	local name = player:get_player_name()
	local hudtable = hb.get_hudtable("health")
	if not hudtable or not hudtable.hudids[name] then return end
	local hud_id = hudtable.hudids[name].bar
	if not hud_id then return end
	local def = player:hud_get(hud_id)
	if not def then return end

	local base_icon = def.text:gsub("%^%[brighten$", "")
	local base_bg = (def.text2 or ""):gsub("%^%[brighten$", "")
	if on then
		if not def.text:find("%^%[brighten$") then
			player:hud_change(hud_id, "text", base_icon .. FLASH_ON_MOD)
		end
		if def.text2 and def.text2 ~= "" and not def.text2:find("%^%[brighten$") then
			player:hud_change(hud_id, "text2", base_bg .. FLASH_ON_MOD)
		end
	else
		if def.text:find("%^%[brighten$") then
			player:hud_change(hud_id, "text", base_icon)
		end
		if def.text2 and def.text2:find("%^%[brighten$") then
			player:hud_change(hud_id, "text2", base_bg)
		end
	end
end

local function health_visible(player)
	if not hb.get_hudtable("health") then return false end
	local state = hb.get_hudbar_state(player, "health")
	return state and not state.hidden
end

local function flash_sequence(player, flashes)
	local name = player:get_player_name()
	for i = 0, flashes - 1 do
		core.after(FLASH_PERIOD * (2 * i), function()
			local p = core.get_player_by_name(name)
			if p and health_visible(p) then set_flash(p, true) end
		end)
		core.after(FLASH_PERIOD * (2 * i + 1), function()
			local p = core.get_player_by_name(name)
			if p then set_flash(p, false) end
		end)
	end
end

core.register_on_player_hpchange(function(player, hp_change)
	local name = player:get_player_name()
	if not player:is_player() then return hp_change end
	if not hb.players[name] then return hp_change end
	if not health_visible(player) then return hp_change end
	if player:get_hp() > SHAKE_HP_THRESHOLD then
		if shake_base_y[name] ~= nil then
			local hudtable = hb.get_hudtable("health")
			local hud_id = hudtable and hudtable.hudids[name] and hudtable.hudids[name].bar
			local def = hud_id and player:hud_get(hud_id)
			if def and def.offset then
				player:hud_change(hud_id, "offset", { x = def.offset.x, y = shake_base_y[name] })
			end
			shake_base_y[name] = nil
		end
	end
	if hp_change and hp_change > 0 then
		flash_sequence(player, 2)
	else
		flash_sequence(player, 3)
	end
	return hp_change
end)

core.register_on_leaveplayer(function(player)
	shake_base_y[player:get_player_name()] = nil
end)

local shake_timer = 0
core.register_globalstep(function(dtime)
	shake_timer = shake_timer + dtime
	if shake_timer < 0.1 then return end
	shake_timer = 0
	for _, player in pairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if hb.players[name] and health_visible(player) and player:get_hp() <= SHAKE_HP_THRESHOLD then
			local hudtable = hb.get_hudtable("health")
			local hud_id = hudtable and hudtable.hudids[name] and hudtable.hudids[name].bar
			local def = hud_id and player:hud_get(hud_id)
			if def and def.offset then
				if shake_base_y[name] == nil then
					shake_base_y[name] = def.offset.y
				end
				local jitter = math.random(-SHAKE_AMOUNT, SHAKE_AMOUNT)
				player:hud_change(hud_id, "offset", { x = def.offset.x, y = shake_base_y[name] + jitter })
			end
		elseif shake_base_y[name] ~= nil then
			local hudtable = hb.get_hudtable("health")
			local hud_id = hudtable and hudtable.hudids[name] and hudtable.hudids[name].bar
			local def = hud_id and player:hud_get(hud_id)
			if def and def.offset then
				player:hud_change(hud_id, "offset", { x = def.offset.x, y = shake_base_y[name] })
			end
			shake_base_y[name] = nil
		end
	end
end)

-- Exposed for checks: pure timing + threshold constants.
mcl_heart_animations = {
	FLASH_PERIOD = FLASH_PERIOD,
	SHAKE_HP_THRESHOLD = SHAKE_HP_THRESHOLD,
	flashes_for = function(hp_change)
		if hp_change and hp_change > 0 then return 2 end
		return 3
	end,
}

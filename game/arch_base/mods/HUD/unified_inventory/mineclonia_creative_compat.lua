-- Arch Base / Mineclonia: preserved creative-mode behaviors from deleted mcl_inventory/creative.lua
-- This file is loaded by unified_inventory/init.lua after the upstream stack is initialized.

local S = core.get_translator("unified_inventory")
local ui = unified_inventory

------------------------------------------------------------------------
-- Infinite node placement (except shulker_box group)
------------------------------------------------------------------------
core.register_on_placenode(function(_, _, placer, _, itemstack)
	if placer and core.is_creative_enabled(placer:get_player_name()) then
		local group = core.get_item_group(itemstack:get_name(), "shulker_box")
		return group == 0 or group == nil
	end
end)

------------------------------------------------------------------------
-- Creative node-drop handling: give directly to inventory instead of dropping
------------------------------------------------------------------------
local old_handle_node_drops = core.handle_node_drops

---@diagnostic disable-next-line: duplicate-set-field
function core.handle_node_drops(pos, drops, digger)
	if digger and core.is_creative_enabled(digger:get_player_name()) then
		if not digger:is_player() then
			for _, item in ipairs(drops) do
				core.add_item(pos, item)
			end
		else
			local inv = digger:get_inventory()
			if inv then
				for _, item in ipairs(drops) do
					if not inv:contains_item("main", item, true) then
						inv:add_item("main", item)
					end
				end
			end
		end
	else
		return old_handle_node_drops(pos, drops, digger)
	end
end

------------------------------------------------------------------------
-- Stack-max fill on put in creative mode
------------------------------------------------------------------------
core.register_on_player_inventory_action(function(player, action, _, info)
	if core.is_creative_enabled(player:get_player_name())
		and action == "put"
		and info.listname == "main" then
		local stack = info.stack
		stack:set_count(stack:get_stack_max())
		player:get_inventory():set_stack("main", info.index, stack)
	end
end)

------------------------------------------------------------------------
-- Touch-mode refresh on globalstep (window information may change after join)
------------------------------------------------------------------------
local players_touch_state = {}

mcl_player.register_globalstep_slow(function(player)
	local name = player:get_player_name()
	if core.is_creative_enabled(name) then
		local window = core.get_player_window_information(name)
		local touch = window and window.touch_controls
		if touch ~= players_touch_state[name] then
			players_touch_state[name] = touch
			ui.set_inventory_formspec(player, ui.current_page[name])
		end
	end
end)

core.register_on_leaveplayer(function(player)
	players_touch_state[player:get_player_name()] = nil
end)

------------------------------------------------------------------------
-- Gamemode change handler: refresh formspec when switching creative/survival
------------------------------------------------------------------------
mcl_gamemode.register_on_gamemode_change(function(player)
	ui.set_inventory_formspec(player, ui.current_page[player:get_player_name()] or ui.default)
end)

------------------------------------------------------------------------
-- Visual change handler (armor equip, skin change, etc.)
------------------------------------------------------------------------
mcl_player.register_on_visual_change(function(player)
	ui.set_inventory_formspec(player, ui.current_page[player:get_player_name()] or ui.default)
end)

------------------------------------------------------------------------
-- Return-to-inventory button in player settings
------------------------------------------------------------------------
mcl_player.register_player_settings_button({
	field = "__unified_inventory_return",
	icon = "crafting_creative_prev.png",
	description = S("Return to player inventory"),
	priority = math.huge,
})

core.register_on_player_receive_fields(function(player, _, fields)
	if fields.__unified_inventory_return then
		ui.set_inventory_formspec(player, ui.default)
		return false
	end
end)

-------------------------------------------------------------------------
-- Crafting-grid helpers migrated from deleted mcl_inventory/init.lua
-- (sole consumer: mcl_craftguide copy-recipe-to-grid + fill-grid button)
-------------------------------------------------------------------------
local function ui_return_item(itemstack, dropper, pos, inv)
	if dropper:is_player() then
		if inv:room_for_item("main", itemstack) then
			inv:add_item("main", itemstack)
		else
			local v = dropper:get_look_dir()
			local p = vector.offset(pos, 0, 1.2, 0)
			p.x = p.x + (math.random(1, 3) * 0.2)
			p.z = p.z + (math.random(1, 3) * 0.2)
			local obj = core.add_item(p, itemstack)
			if obj then
				v.x = v.x * 4
				v.y = v.y * 4 + 2
				v.z = v.z * 4
				obj:set_velocity(v)
				obj:get_luaentity()._insta_collect = false
			end
		end
	else
		core.add_item(pos, itemstack)
	end
	return itemstack
end

local function ui_return_fields(player, name)
	if not player or not player:get_pos() then return end
	local inv = player:get_inventory()
	local list = inv:get_list(name)
	if not list then return end
	for i, stack in ipairs(list) do
		ui_return_item(stack, player, player:get_pos(), inv)
		stack:clear()
		inv:set_stack(name, i, stack)
	end
end

local function ui_get_recipe_groups(player, craft, optional_width, optional_height)
	ui_return_fields(player, "craft")
	local pinv = player:get_inventory()
	local grid_width = optional_width or pinv:get_width("craft")
	if grid_width == 0 then
		grid_width = 3
	end
	local grid_height = optional_height or math.ceil(pinv:get_size("craft") / grid_width)
	local craft_size = table.max_index(craft.items)
	local craft_width = craft.width
	if craft_width == 0 then
		craft_width = craft_size <= 4 and 2 or 3
	end
	if craft_width > grid_width or math.ceil(craft_size / craft_width) > grid_height then
		return false
	end
	local list = "_mcl_inventory_recipe_groups"
	pinv:set_size(list, pinv:get_size("main"))
	pinv:set_list(list, pinv:get_list("main"))
	local r = {}
	local all_found = true
	local i = 0
	for k = 1, craft_size do
		local it = craft.items[k]
		local ki = k + i
		if it then
			if it:sub(1, 6) == "group:" then
				local group = it:sub(7)
				for index, stack in pairs(pinv:get_list(list)) do
					local name = stack:get_name()
					if core.get_item_group(name, group) > 0 then
						r[ki] = name
						stack:take_item(1)
						pinv:set_stack(list, index, stack)
					end
				end
				if not r[ki] then
					all_found = false
					break
				end
			elseif pinv:contains_item(list, ItemStack(it)) then
				r[ki] = it
				pinv:remove_item(list, ItemStack(it))
			else
				all_found = false
				break
			end
		else
			r[ki] = ""
		end
		if (k % craft_width) == 0 then
			for _ = 1, grid_width - craft_width do
				i = i + 1
				r[k + i] = ""
			end
		end
	end
	pinv:set_size(list, 0)
	if all_found then
		return r
	else
		return false
	end
end

function unified_inventory.to_craft_grid(player, craft)
	ui_return_fields(player, "craft")
	local pinv = player:get_inventory()
	if craft.type == "normal" then
		local recipe = ui_get_recipe_groups(player, craft)
		if recipe then
			for k, it in pairs(recipe) do
				local pit = ItemStack(it)
				if pinv:room_for_item("craft", pit) then
					local stack = pinv:remove_item("main", pit)
					pinv:set_stack("craft", k, stack)
				end
			end
		end
	end
end

function unified_inventory.fill_grid(player)
	local inv = player:get_inventory()
	local itcounts = {}
	local invcounts = {}
	for _, stack in pairs(inv:get_list("craft")) do
		local name = stack:get_name()
		if name ~= "" then
			itcounts[name] = (itcounts[name] or 0) + 1
			local c = 0
			for _, istack in pairs(inv:get_list("main")) do
				if istack:get_name() == name then
					c = c + istack:get_count()
				end
			end
			invcounts[name] = c
		end
	end
	for idx, tstack in pairs(inv:get_list("craft")) do
		local name = tstack:get_name()
		if itcounts[name] and invcounts[name] then
			local it = ItemStack(name)
			it:set_count(math.min(tstack:get_stack_max() - tstack:get_count(), math.floor(invcounts[name] / (itcounts[name] or 1))))
			tstack:add_item(inv:remove_item("main", it))
			inv:set_stack("craft", idx, tstack)
		end
	end
end

-------------------------------------------------------------------------
-- Inventory action buttons (craftguide / doc / achievements / settings)
-- Old mcl_inventory also dropped temp lists (craft, enchanting_*) on quit
-- and on leave; unified_inventory owns formname "" so it handles them here.
-------------------------------------------------------------------------
core.register_on_player_receive_fields(function(player, _, fields)
	if fields.__mcl_crafting_fillgrid then
		unified_inventory.fill_grid(player)
	elseif fields.__mcl_craftguide then
		mcl_craftguide.show(player:get_player_name())
	elseif fields.__mcl_doc then
		if rawget(_G, "doc") and doc.show_doc then
			doc.show_doc(player:get_player_name())
		end
	elseif fields.__mcl_achievements then
		if rawget(_G, "awards") and awards.show_to then
			local name = player:get_player_name()
			awards.show_to(name, name, nil, false)
		end
	elseif fields.__mcl_player_settings then
		mcl_player.show_player_settings(player)
	elseif fields.quit then
		ui_return_fields(player, "craft")
		ui_return_fields(player, "enchanting_lapis")
		ui_return_fields(player, "enchanting_item")
	end
end)

core.register_on_leaveplayer(function(player)
	ui_return_fields(player, "craft")
	ui_return_fields(player, "enchanting_lapis")
	ui_return_fields(player, "enchanting_item")
end)

-------------------------------------------------------------------------
-- Crafting-table range guard (from deleted mcl_inventory/init.lua):
-- grids wider than 2x2 need a crafting table in reach; without this,
-- 3x3 recipes stay craftable in the player grid after walking away.
-------------------------------------------------------------------------
local function ui_get_required_craft_grid_size(grid_contents, grid_width)
	if grid_width == 0 then
		grid_width = 3
	end
	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = 0, 0
	local size = #grid_contents
	local i = 0
	local row = 1
	while i < size do
		for j = 1, grid_width do
			if grid_contents[i + j] and not grid_contents[i + j]:is_empty() then
				min_x, min_y = math.min(min_x, j), math.min(min_y, row)
				max_x, max_y = math.max(max_x, j), math.max(max_y, row)
			end
		end
		i = i + grid_width
		row = row + 1
	end
	if max_x == 0 then
		return 0
	else
		return math.max(max_x - min_x, max_y - min_y) + 1
	end
end

core.register_craft_predict(function(itemstack, player, old_craft_grid, inv)
	if not player or not player:get_pos() then return end
	if inv and ui_get_required_craft_grid_size(old_craft_grid, inv:get_width("craft")) > 2
		and not mcl_crafting_table.has_crafting_table(player) then
		ui_return_fields(player, "craft")
		core.chat_send_player(player:get_player_name(), S("Crafting table out of range!"))
	end
end)

-------------------------------------------------------------------------
-- Sorter quick-equip (from deleted mcl_inventory/survival.lua):
-- moving a stack to the hidden sorter list either equips armor via
-- mcl_armor or shuttles hotbar<->inventory. Puts/takes are blocked so
-- only moves trigger it.
-------------------------------------------------------------------------
local function ui_find_empty_inv_slots(inv)
	local main, hotbar
	for i, stack in pairs(inv:get_list("main")) do
		if i > 9 and not main and stack:is_empty() then
			main = i
		elseif i <= 9 and not hotbar and stack:is_empty() then
			hotbar = i
		end
		if hotbar and main then break end
	end
	return main, hotbar
end

core.register_on_player_inventory_action(function(player, action, inv, info)
	if action == "move" and info.to_list == "sorter" then
		local stack = inv:get_stack(info.to_list, info.to_index)
		local empty_main, empty_hotbar = ui_find_empty_inv_slots(inv)
		if core.get_item_group(stack:get_name(), "armor") > 0 then
			local newstack = mcl_armor.equip(stack, player, true)
			if newstack and not newstack:is_empty() then
				if inv:get_stack(info.from_list, info.from_index):is_empty() then
					inv:set_stack(info.from_list, info.from_index, newstack)
				elseif inv:room_for_item(info.from_list, newstack) then
					inv:add_item(info.from_list, newstack)
				end
			end
		elseif info.from_list == "main" and info.from_index <= 9 and empty_main then
			inv:set_stack("main", empty_main, stack)
		elseif info.from_list == "main" and info.from_index > 9 and empty_hotbar then
			inv:set_stack("main", empty_hotbar, stack)
		else
			inv:set_stack(info.from_list, info.from_index, stack)
		end
		inv:set_stack("sorter", 1, ItemStack(""))
	end
end)

core.register_allow_player_inventory_action(function(_, action, inv, info)
	if info.to_list == "sorter" or info.from_list == "sorter" or info.listname == "sorter" then
		if action == "put" or action == "take" then return 0 end
		local stack = inv:get_stack(info.from_list, info.from_index)
		local empty_main, empty_hotbar = ui_find_empty_inv_slots(inv)
		if core.get_item_group(stack:get_name(), "armor") > 0 then
			return 1
		elseif (info.from_list == "main" and info.from_index <= 9 and empty_main)
			or (info.from_list == "main" and info.from_index > 9 and empty_hotbar) then
			return stack:get_count()
		end
		return 0
	end
end)
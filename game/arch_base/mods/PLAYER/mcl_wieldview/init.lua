core.register_entity("mcl_wieldview:wieldview", {
	initial_properties = {
		hp_max           = 1,
		visual           = "wielditem",
		physical         = false,
		is_visible       = false,
		pointable        = false,
		collide_with_objects = false,
		static_save = false,
		collisionbox = {-0.21, -0.21, -0.21, 0.21, 0.21, 0.21},
		selectionbox = {-0.21, -0.21, -0.21, 0.21, 0.21, 0.21},
		visual_size  = {x = 0.21, y = 0.21},
	}
})

-- 3d_armor_hover replaces the player mesh with a .glb that has no
-- "Wield_Item" bone (upstream README: wield visuals not implemented).
-- Attaching to a missing bone silently parks the entity at its spawn
-- position, so detect the hover model and attach to "Arm_Right" (a bone
-- name both models share) with per-item-type poses.
--
-- Pose values follow the two proven upstream references for Arm_Right
-- attaches, whose arm proportions match this .glb (~5-6 units long):
--   * MT-CTF/wield3d (stujones11, same author as 3d_armor) default:
--     pos (0, 5.5, 3), rot (-90, 225, 90)
--   * Mineclonia mcl_player.position_wielditem "Wield_Item" branches
--     (toollike / bow / crossbow / wield-image-less / generic).
local HOVER_MODEL = "3d_armor_hover_character.glb"
local HOVER_BONE = "Arm_Right"

-- Item-type poses in Arm_Right bone space. Order mirrors
-- mcl_player.position_wielditem so held tools/weapons sit in the fist
-- exactly like they do on the b3d model.
--
-- NOTE: yaw is the Wield_Item value + 180 and z is negated. The glb
-- Arm_Right bind carries a 180-degree X-flip the b3d Wield_Item bone
-- does not have: identical rotations render mirrored (blade backward)
-- and identical offsets land behind the hand. Verified in-game.
local function hover_pose_for(itemname, wielded_def)
	if wielded_def and wielded_def._mcl_toollike_wield then
		return vector.new(0, 4.7, -3.1), vector.new(-90, 45, 90)
	elseif core.get_item_group(itemname, "bow") > 0 then
		return vector.new(1, 4, 0), vector.new(90, 310, 115)
	elseif core.get_item_group(itemname, "crossbow") > 4 then
		return vector.new(0, 5.2, -1.2), vector.new(0, 0, 73)
	elseif core.get_item_group(itemname, "crossbow") > 0 then
		return vector.new(0, 5.2, -1.2), vector.new(0, 0, 45)
	elseif wielded_def and wielded_def.inventory_image == "" then
		return vector.new(0, 6, -2), vector.new(180, 135, 0)
	end
	return vector.new(0, 5.3, -2), vector.new(90, 180, 0)
end

local function wield_bone_for(player)
	local props = player:get_properties()
	if props and props.mesh == HOVER_MODEL then
		local stack = mcl_serverplayer.get_visual_wielditem(player)
		local pos, rot = hover_pose_for(stack:get_name(), stack:get_definition())
		return HOVER_BONE, pos, rot
	end
	return "Wield_Item", nil, nil
end

local wieldview_luaentites = {
	Main = {},
	Off = {},
}

local function remove_wieldview(player)
	for slot,_ in pairs(wieldview_luaentites) do
		if wieldview_luaentites[slot][player] then
			wieldview_luaentites[slot][player].object:remove()
		end
		wieldview_luaentites[slot][player] = nil
	end
end

local function update_wieldview_entity(player, slot, bone, position, rotation, get_item)
	local luaentity = wieldview_luaentites[slot][player]

	-- Re-attach when the target bone or pose changed (e.g. model swap
	-- b3d <-> glb, or switching between item types with different poses)
	local pose_key = bone .. "|" .. (position and position.x .. "," .. position.y .. "," .. position.z or "-")
		.. "|" .. (rotation and rotation.x .. "," .. rotation.y .. "," .. rotation.z or "-")
	if luaentity and luaentity._pose_key ~= pose_key then
		luaentity.object:remove()
		wieldview_luaentites[slot][player] = nil
		luaentity = nil
	end

	if luaentity and luaentity.object:get_yaw() then
		local item = get_item(player):get_name()

		if item == luaentity._item then return end
		if core.get_item_group(item, "shield") > 0 then
			luaentity.object:remove ()
			wieldview_luaentites[slot][player] = nil
			return
		end
		luaentity._item = item

		local def = get_item(player):get_definition()
		if def and def._mcl_wieldview_item then
			item = def._mcl_wieldview_item
		end

		local item_def = core.registered_items[item]
		luaentity.object:set_properties({
			glow = item_def and item_def.light_source or 0,
			wield_item = item,
			is_visible = item ~= ""
		})
	else
		-- If the player is running through an unloaded area,
		-- the wieldview entity will sometimes get unloaded.
		-- This code path is also used to initalize the wieldview.
		-- Creating entites from core.register_on_joinplayer
		-- is unreliable as of Minetest 5.6
		local obj_ref = core.add_entity(player:get_pos(), "mcl_wieldview:wieldview")
		if not obj_ref then return end
		obj_ref:set_attach(player, bone, position, rotation)
		obj_ref:set_armor_groups({ immortal = 1 })
		wieldview_luaentites[slot][player] = obj_ref:get_luaentity()
		wieldview_luaentites[slot][player]._bone = bone
		wieldview_luaentites[slot][player]._pose_key = pose_key
	end
end

core.register_on_leaveplayer(remove_wieldview)

mcl_player.register_globalstep(function(player)
	local bone, pos, rot = wield_bone_for(player)
	update_wieldview_entity(player, "Main", bone, pos, rot, mcl_serverplayer.get_visual_wielditem)
	update_wieldview_entity(player, "Off", "Arm_Left", vector.new(0, 4.5, 2), vector.new(120, 0, 0), mcl_offhand.get_offhand)
end)

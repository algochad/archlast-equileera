local S = core.get_translator("unified_inventory")
local ui = unified_inventory

-- Arch Base / Mineclonia: categories use mcl_* item names instead of default:*
unified_inventory.register_category('plants', {
	symbol = "mcl_flowers:tulip_red",
	label = S("Plant Life")
})
unified_inventory.register_category('building', {
	symbol = "mcl_core:brick_block",
	label = S("Building Materials")
})
unified_inventory.register_category('tools', {
	symbol = "mcl_tools:pick_diamond",
	label = S("Tools")
})
unified_inventory.register_category('minerals', {
	symbol = "mcl_raw_ores:raw_iron",
	label = S("Minerals and Metals")
})
unified_inventory.register_category('environment', {
	symbol = "mcl_core:dirt_with_grass",
	label = S("Environment and Worldgen")
})
unified_inventory.register_category('lighting', {
	symbol = "mcl_torches:torch",
	label = S("Lighting")
})

local function get_item_category(name)
	local def = core.registered_items[name]
	if not def then return nil end

	if core.get_item_group(name, "building_block") ~= 0 then
		return "building"
	end
	if core.get_item_group(name, "deco_block") ~= 0 then
		return "building"
	end
	if def._mcl_redstone or core.get_item_group(name, "redstone_wire") ~= 0 then
		return "minerals" -- redstone grouped with minerals in Mineclonia
	end
	if core.get_item_group(name, "transport") ~= 0 then
		return "tools"
	end
	if (core.get_item_group(name, "food") ~= 0 and core.get_item_group(name, "brewitem") == 0)
		or core.get_item_group(name, "eatable") ~= 0 then
		return "plants" -- food mostly plant-based; separate category not needed
	end
	if (def.groups.tool and def.groups.tool ~= 0)
		or (def.tool_capabilities and def.tool_capabilities.damage_groups == nil) then
		return "tools"
	end
	if (def.groups.weapon and def.groups.weapon ~= 0)
		or (def.groups.weapon_ranged and def.groups.weapon_ranged ~= 0)
		or (def.groups.ammo and def.groups.ammo ~= 0)
		or (def.groups.combat_item and def.groups.combat_item ~= 0)
		or ((
			(def.groups.armor_head and def.groups.armor_head ~= 0) or
			(def.groups.armor_torso and def.groups.armor_torso ~= 0) or
			(def.groups.armor_legs and def.groups.armor_legs ~= 0) or
			(def.groups.armor_feet and def.groups.armor_feet ~= 0) or
			(def.groups.horse_armor and def.groups.horse_armor ~= 0)) and
			def.groups.non_combat_armor ~= 1) then
		return "tools"
	end
	if core.get_item_group(name, "spawn_egg") ~= 0 then
		return "environment"
	end
	if core.get_item_group(name, "brewitem") ~= 0 then
		return "minerals"
	end
	if core.get_item_group(name, "craftitem") ~= 0 then
		return "minerals"
	end
	if core.get_item_group(name, "tree") ~= 0
		or core.get_item_group(name, "leaves") ~= 0
		or core.get_item_group(name, "flower") ~= 0
		or core.get_item_group(name, "sapling") ~= 0 then
		return "plants"
	end
	if core.get_item_group(name, "soil") ~= 0
		or core.get_item_group(name, "sand") ~= 0
		or core.get_item_group(name, "stone") ~= 0 then
		return "environment"
	end
	if def.light_source and def.light_source > 0 then
		return "lighting"
	end
	return nil
end

local function register_automatic_categorization()
	for name, def in pairs(core.registered_items) do
		if ui.is_itemdef_listable(def) then
			local cat = get_item_category(name)
			if cat then
				ui.add_category_items(cat, {name})
			end
		end
	end

	-- Add biome nodes to environment category
	for _, def in pairs(core.registered_biomes) do
		if def.node_top then
			ui.add_category_items('environment', {def.node_top})
		end
		if def.node_filler then
			ui.add_category_items('environment', {def.node_filler})
		end
		if def.node_stone then
			ui.add_category_items('environment', {def.node_stone})
		end
	end
end

ui.register_on_initialized(register_automatic_categorization)

-- Explicit mineral additions for Mineclonia ores/ingots
unified_inventory.add_category_items('minerals', {
	"mcl_core:coal_lump",
	"mcl_raw_ores:raw_iron",
	"mcl_raw_ores:raw_gold",
	"mcl_core:gold_ingot",
	"mcl_core:diamond",
	"mcl_core:emerald",
	"mcl_core:lapis",
	"mcl_redstone:redstone",
	"mcl_nether:quartz",
	"mcl_nether:netherite_scrap",
	"mcl_core:iron_ingot",
	"mcl_copper:copper_ingot",
	"mcl_nether:netherite_ingot",
})
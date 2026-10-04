-- Asuna Default Aliases shim
-- Maps minetest_game default:* node/item names to arch_base mcl_* equivalents
-- for vendored Asuna mods (geodes, bakedclay, too_many_stones, animalia, livingslimes).
-- Intentionally unaliased names (no arch_base equivalent; consumers are get_modpath("default")-guarded):
--   default:steel_ingot, default:mese_shard, default:dry_shrub, default:permafrost,
--   default:silver_sandstone, default:desert_sandstone, default:desert_stone,
--   default:desert_sand, default:desert_cobble

local core = minetest

if not core.get_modpath("mcl_core") then
	core.log("warning", "[asuna_default_aliases] mcl_core not found; skipping alias registration")
	return
end

-- Node/item aliases: default:<name> -> mcl_core:<name>
local mcl_core_aliases = {
	"stone",
	"dirt",
	"dirt_with_grass",
	"stick",
	"clay",
	"clay_lump",
	"cactus",
	"glass",
	"sand",
	"sandstone",
	"gravel",
	"silver_sand",
	"brick",
	"stonebrick",
}

for _, name in ipairs(mcl_core_aliases) do
	core.register_alias("default:" .. name, "mcl_core:" .. name)
end

-- Chest lives in mcl_chests, not mcl_core
if core.get_modpath("mcl_chests") then
	core.register_alias("default:chest", "mcl_chests:chest")
else
	core.log("warning", "[asuna_default_aliases] mcl_chests not found; default:chest alias skipped")
end

-- Sound helper globals expected by geodes and other Asuna mods
default = default or {}

if core.get_modpath("mcl_sounds") then
	default.node_sound_stone_defaults = function(t)
		return mcl_sounds.node_sound_stone_defaults(t)
	end
	default.node_sound_defaults = function(t)
		return mcl_sounds.node_sound_defaults(t)
	end
	default.node_sound_leaves_defaults = function(t)
		return mcl_sounds.node_sound_defaults(t)
	end
else
	core.log("warning", "[asuna_default_aliases] mcl_sounds not found; sound helpers not provided")
end
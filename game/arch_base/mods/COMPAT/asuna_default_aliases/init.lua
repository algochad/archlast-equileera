-- Asuna Default Aliases shim
-- Maps minetest_game default:* node/item names to arch_base mcl_* equivalents
-- for vendored Asuna mods (geodes, bakedclay, too_many_stones, animalia, livingslimes).
-- Also provides the `asuna` global that Asuna mods expect (content/features/biomes)
-- so load order between animalia/livingslimes doesn't matter.

-- Central asuna global - keep additive so any load order is safe
asuna = asuna or {}
asuna.content = asuna.content or {}
asuna.content.menagerie = asuna.content.menagerie or {}
if asuna.content.menagerie.animals == nil then asuna.content.menagerie.animals = true end
if asuna.content.menagerie.slimes == nil then asuna.content.menagerie.slimes = true end
asuna.features = asuna.features or {}
asuna.features.animals = asuna.features.animals or setmetatable({}, {__index = function() return {} end})
asuna.biomes = asuna.biomes or setmetatable({}, {__index = function() return {name = "unknown"} end})

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

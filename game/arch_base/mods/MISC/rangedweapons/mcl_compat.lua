-- mcl_compat.lua: Mineclonia compatibility shim for rangedweapons
-- Provides MTG API equivalents using Mineclonia mods
-- License: CC-BY-SA 4.0 (same as rangedweapons)

local S = core.get_translator(core.get_current_modname())

------------------------------------------------------------------------
-- default.node_sound_wood_defaults() shim via mcl_sounds
------------------------------------------------------------------------
if not default then
	default = {}
end

if not default.node_sound_wood_defaults then
	if core.global_exists("mcl_sounds") and mcl_sounds.node_sound_wood_defaults then
		default.node_sound_wood_defaults = mcl_sounds.node_sound_wood_defaults
	else
		-- Fallback: return empty sounds table so nodes still register
		default.node_sound_wood_defaults = function()
			return {}
		end
		core.log("warning", "[rangedweapons] mcl_sounds not available; wood sounds disabled")
	end
end

------------------------------------------------------------------------
-- tnt.register_tnt() and tnt.boom() shim via mcl_explosions
------------------------------------------------------------------------
if not tnt then
	tnt = {}
end

-- Store registered explosion definitions for potential future use
tnt._rw_registered_explosions = tnt._rw_registered_explosions or {}

if not tnt.register_tnt then
	tnt.register_tnt = function(def)
		if not def or not def.name then
			core.log("warning", "[rangedweapons] tnt.register_tnt called without name")
			return
		end
		tnt._rw_registered_explosions[def.name] = def
		core.log("info", "[rangedweapons] Registered explosion type: " .. def.name
			.. " (radius=" .. tostring(def.radius or "?") .. ")")
	end
end

if not tnt.boom then
	tnt.boom = function(pos, def)
		def = def or {}
		local radius = def.radius or 3
		if core.global_exists("mcl_explosions") and mcl_explosions.explode then
			mcl_explosions.explode(pos, radius, {}, nil)
		else
			core.log("warning", "[rangedweapons] mcl_explosions not available; explosion at "
				.. core.pos_to_string(pos) .. " suppressed")
		end
	end
end

------------------------------------------------------------------------
-- Itemstring mapping: MTG -> Mineclonia equivalents
-- Used by crafting recipes and node interaction checks
------------------------------------------------------------------------
rangedweapons_mcl_item_map = {
	-- Wood/materials
	["default:wood"]           = "mcl_core:wood",
	["default:cobble"]         = "mcl_core:cobble",
	["default:steel_ingot"]    = "mcl_core:iron_ingot",
	["default:copper_ingot"]   = "mcl_core:iron_ingot",
	["default:gold_ingot"]     = "mcl_core:gold_ingot",
	["default:mese_crystal"]   = "mcl_core:diamond",
	["default:mese_crystal_fragment"] = "mcl_core:diamond",
	["default:obsidian_shard"] = "mcl_core:obsidian_shard",
	["default:stick"]          = "mcl_core:stick",
	["default:paper"]          = "mcl_core:paper",
	["default:coal_lump"]      = "mcl_core:coal_lump",
	["default:gunpowder"]      = "mcl_mobitems:gunpowder",
	["default:diamond"]        = "mcl_core:diamond",
	["default:steelblock"]     = "mcl_core:ironblock",
	["default:goldblock"]      = "mcl_core:goldblock",
	["default:diamondblock"]   = "mcl_core:diamondblock",
	["default:mese"]           = "mcl_core:diamondblock",
	["default:tin_ingot"]      = "mcl_core:iron_ingot",
	["default:bronze_ingot"]   = "mcl_core:iron_ingot",

	-- Dyes
	["dye:black"]      = "mcl_dye:black",
	["dye:white"]      = "mcl_dye:white",
	["dye:red"]        = "mcl_dye:red",
	["dye:green"]      = "mcl_dye:green",
	["dye:blue"]       = "mcl_dye:blue",
	["dye:yellow"]     = "mcl_dye:yellow",
	["dye:orange"]     = "mcl_dye:orange",
	["dye:cyan"]       = "mcl_dye:cyan",
	["dye:dark_green"] = "mcl_dye:dark_green",
	["dye:brown"]      = "mcl_dye:brown",
	["dye:dark_grey"]  = "mcl_dye:dark_grey",
	["dye:grey"]       = "mcl_dye:grey",
	["dye:magenta"]    = "mcl_dye:magenta",
	["dye:pink"]       = "mcl_dye:pink",
	["dye:violet"]     = "mcl_dye:violet",

	-- TNT
	["tnt:tnt"]         = "mcl_tnt:tnt",
	["tnt:tnt_burning"] = "mcl_tnt:tnt",
	["tnt:gunpowder"]   = "mcl_mobitems:gunpowder",

	-- Glass/panes/doors
	["default:glass"]           = "mcl_core:glass",
	["xpanes:pane"]             = "mcl_panes:pane",
	["xpanes:pane_flat"]        = "mcl_panes:pane_flat",
	["vessels:glass_fragments"] = "mcl_core:glass",

	-- Farming / misc
	["farming:string"] = "mcl_mobitems:string",

	-- Moreores (map to closest MCL metals)
	["moreores:silver_ingot"] = "mcl_core:iron_ingot",
	["moreores:bronze_ingot"] = "mcl_core:iron_ingot",
}

--- Translate an MTG itemstring to its Mineclonia equivalent.
--- Returns original string if no mapping exists.
function rangedweapons_translate_item(itemstring)
	if not itemstring then return itemstring end
	-- Strip count suffix for lookup: "default:wood 5" -> "default:wood"
	local base = itemstring:match("^([^%s]+)")
	local mapped = rangedweapons_mcl_item_map[base]
	if mapped then
		local count = itemstring:match("%s+(.+)$")
		return count and (mapped .. " " .. count) or mapped
	end
	return itemstring
end

core.log("info", "[rangedweapons] Mineclonia compatibility shim loaded")


------------------------------------------------------------------------
-- Register craft aliases: MTG itemstring -> MCL equivalent
-- Aliases make MTG recipes resolve correctly without rewriting each recipe
------------------------------------------------------------------------
local function register_craft_aliases()
	for mtg_item, mcl_item in pairs(rangedweapons_mcl_item_map) do
		-- Only register if the MTG item doesn't already exist as a real item
		if not core.registered_items[mtg_item] then
			core.register_alias(mtg_item, mcl_item)
		end
	end
end

register_craft_aliases()
core.log("info", "[rangedweapons] Craft aliases registered for Mineclonia compatibility")
local S = core.get_translator("arch_slopes")

-- Stone slopes
naturalslopeslib.register_slope("mcl_core:stone", {
	description = S("Stone Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:cobble", {
	description = S("Cobblestone Slope"),
}, 10, {time = 3})

naturalslopeslib.register_slope("mcl_core:mossycobble", {
	description = S("Mossy Cobblestone Slope"),
}, 15, {time = 3})

naturalslopeslib.register_slope("mcl_core:sandstone", {
	description = S("Sandstone Slope"),
}, 120, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:redsandstone", {
	description = S("Red Sandstone Slope"),
}, 120, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:obsidian", {
	description = S("Obsidian Slope"),
}, 500, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:granite", {
	description = S("Granite Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:diorite", {
	description = S("Diorite Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_core:andesite", {
	description = S("Andesite Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

-- Soft / Non-Stone slopes
naturalslopeslib.register_slope("mcl_core:dirt", {
	description = S("Dirt Slope"),
}, 10, {place = 0.5, time = 0.75})

naturalslopeslib.register_slope("mcl_core:dirt_with_grass", {
	description = S("Grass Block Slope"),
}, 25)

naturalslopeslib.register_slope("mcl_core:dirt_with_grass_snow", {
	description = S("Snowy Grass Block Slope"),
}, 25)

naturalslopeslib.register_slope("mcl_core:coarse_dirt", {
	description = S("Coarse Dirt Slope"),
}, 6, {place = 0.5, time = 0.5})

naturalslopeslib.register_slope("mcl_core:podzol", {
	description = S("Podzol Slope"),
}, 15)

naturalslopeslib.register_slope("mcl_core:mycelium", {
	description = S("Mycelium Slope"),
}, 15)

naturalslopeslib.register_slope("mcl_core:sand", {
	description = S("Sand Slope"),
}, 5, {mapgen = 0, place = 0, time = 0})

naturalslopeslib.register_slope("mcl_core:redsand", {
	description = S("Red Sand Slope"),
}, 5, {mapgen = 0, place = 0, time = 0})

naturalslopeslib.register_slope("mcl_core:gravel", {
	description = S("Gravel Slope"),
}, 7, {stomp = 0.5, time = 2})

naturalslopeslib.register_slope("mcl_core:clay", {
	description = S("Clay Slope"),
}, 15)

naturalslopeslib.register_slope("mcl_core:snowblock", {
	description = S("Snow Block Slope"),
}, 4, {stomp = 0})

naturalslopeslib.register_slope("mcl_core:ice", {
	description = S("Ice Slope"),
}, 60, {mapgen = 0.25})

naturalslopeslib.register_slope("mcl_core:packed_ice", {
	description = S("Packed Ice Slope"),
}, 60, {mapgen = 0.25})

naturalslopeslib.register_slope("mcl_core:blue_ice", {
	description = S("Blue Ice Slope"),
}, 60, {mapgen = 0.25})

-- Mud and deepslate
naturalslopeslib.register_slope("mcl_mud:mud", {
	description = S("Mud Slope"),
}, 8, {place = 0.5, time = 0.5})

naturalslopeslib.register_slope("mcl_deepslate:deepslate", {
	description = S("Deepslate Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_deepslate:tuff", {
	description = S("Tuff Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

-- Nether
naturalslopeslib.register_slope("mcl_blackstone:blackstone", {
	description = S("Blackstone Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

naturalslopeslib.register_slope("mcl_blackstone:basalt", {
	description = S("Basalt Slope"),
}, 200, {mapgen = 0.33, place = 0.5})

-- Tree leaves (oak and birch confirmed registered; others generated dynamically)
naturalslopeslib.register_slope("mcl_trees:leaves_oak", {
	description = S("Oak Leaves Slope"),
}, 2, {stomp = 6})

naturalslopeslib.register_slope("mcl_trees:leaves_birch", {
	description = S("Birch Leaves Slope"),
}, 2, {stomp = 6})
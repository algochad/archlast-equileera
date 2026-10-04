# Arch Base merge notes

Base: Mineclonia main @ 85029767688df9c3ca95c9cff3b082c0a83f6704 (GPLv3)
Donor: VoxeLibre master @ 2373982f19f9b5d89cd2e3146ad7749876319e15 (GPLv3)
Shader: voxelibre_shader_preset_port master @ cf0cf6198ddd20b239ac9dbdb39e6facdd09e7b9 (MIT)

Shared-name mods (168 by dirname): Mineclonia version kept throughout; no donor variant taken.

Mineclonia-only: kept unconditionally incl. all of mods/COMPAT/.

## Adopted VoxeLibre-only mods (28 attempted, 18 kept, 10 removed)

Kept (18):

| mod | category | vl-init-sha12 |
|---|---|---|
| mcl_compressed_blocks | ITEMS | fedfcfa3bb95 |
| mcl_cozy | PLAYER | d4d3287670ed |
| mcl_fovapi | PLAYER | 3a2b6de57513 |
| mcl_item_id | HELP | 91cd4944f6f2 |
| mcl_luck | PLAYER | ad90a4ae17ed |
| mcl_music | PLAYER | cb2f2f28dbaa |
| mcl_oxidation | CORE | 208e91da6476 |
| mcl_particles | CORE | 50e093c077b0 |
| mcl_playerplus | PLAYER | 068fb3c36df8 |
| mcl_starting_inventory | ITEMS | 673e45f68804 |
| vl_cavesounds | PLAYER | 581dcfb203ed |
| vl_env_sounds | CORE | 5b95f7cada0a |
| vl_held_item | ENTITIES | 2c72e19eb513 |
| vl_legacy | CORE | b69c653d9ee7 |
| vl_trusted | CORE | 8639d4f16409 |
| vl_tuning | CORE | ea2fc83b4bd0 |
| vl_unittests | CORE | aea633636357 |
| vl_wieldlight | PLAYER | 32cd1ce3cf7e |

Removed after arch_base smoke/play (10, Mineclonia API divergence):

| mod | reason |
|---|---|
| vl_weaponry | `mcl_bows.arrow_entity` is table in Mineclonia vs copyable prototype in VL; `table.update(spear_entity,...)` nil-field crash |
| vl_projectile | dependency of vl_weaponry only; unused after weaponry removal |
| vl_deepslate_tools | hard `depends = ... vl_weaponry ...`; removed with weaponry |
| mcl_shepherd | `mcl_vars.tool_wield_scale` is table in Mineclonia, VL shepherd does arithmetic on it |
| vl_announcements | `depends = ... mcl_shepherd`; removed with shepherd |
| mcl_hamburger | `minetest.registered_entities["mobs_mc:villager"].follow` nil in Mineclonia mobs_mc |
| vl_hollow_logs | calls `mcl_stonecutter.register_recipe` which Mineclonia stonecutter no longer provides |
| bonemeal | VL compat shim for WorldEdit-Additions; references `mcl_flowers:tallgrass/dandelion/...` aliases unregistered in Mineclonia flower rewrite (log spam `Item does not exist`, fails smoke Log Check) |
| vl_deco | ships zero textures (all `vl_deco_*.png` live in VL global `textures/` dir, never copied per-mod); dummy-image spam on join |
| xpanes | Mineclonia `mcl_panes` already covers glass/iron panes; VL xpanes only added `gold_bar` + dupes, ships no textures (same global-dir problem) |

Arch Base patches (not upstream):

| file | change | reason |
|---|---|---|
| `mods/CORE/mcl_init/init.lua` | added `mcl_vars.hud_type_field` compat line | VL donor `mcl_playerplus` indexes it on join (`hud_add` `type` vs `hud_elem_type`); Mineclonia mcl_init lacks it — without it, every player join crashes with `table index is nil` |
| `mods/MAPGEN/mcl_villages/schemgen.lua` | loot validation deferred to `on_mods_loaded` | villages loads before item providers; immediate check logs false `Item does not exist` errors. Added-then-reverted `depends` edge (would cycle via `mcl_raids->mcl_villages`) in favor of deferred recheck |

Also: `README.md` copied from Mineclonia root (not in original layout) because `mods/MISC/mcl_commands/version.lua:47` requires `game.conf`-adjacent README with `Version:` line.
## Skipped VoxeLibre-only mods (5, Mineclonia equivalent found by NAME)

| vl mod | equivalent | match |
|---|---|---|
| vl_fireworks | mcl_fireworks | NAME |
| vl_hudbars | hudbars | NAME |
| vl_sus_stew | mcl_sus_stew | NAME |
| vl_tridents | mcl_tridents | NAME |
| walkover | mcl_walkover | NAME |

## Shader preset

4 files -> mods/arch_shader_preset/; mod.conf rewritten (name=arch_shader_preset, title=Arch Shader Preset, depends=[]); init.lua/README.md/LICENSE byte-identical.

## Config

settingtypes.txt: Mineclonia base + 86 VoxeLibre-only keys appended (deduped by key). minetest.conf: Mineclonia verbatim (only diff vs VL was comment wording + mcl_levelgen_enable_ersatz kept).

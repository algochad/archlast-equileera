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

## Bushy leaves

Upstream: https://codeberg.org/EmoryNB/bushy_leaves @ f2a608053404ca050ce430d0b8f2ed32236c2172 (master, AGPLv3).
8 files -> mods/ENVIRONMENT/bushy_leaves/ (init.lua, mod.conf, settingtypes.txt, README.md, LICENSE byte-identical; models/*.obj + models/license.txt byte-identical; 3 screenshots dropped, ~2MB).
Mesh override (`drawtype=mesh`, `waving=2`, via `register_on_mods_loaded`) applies to every registered node matching `*leaves*` (except `*with_leaves*`) or `*needles*`; covers arch_base `mcl_trees:leaves_*`, `mcl_core:acacialeaves`, azalea/mangrove variants. `fix-collision-box-2` branch deliberately NOT taken: it drops the mesh approach for nodeboxes and deletes the model files.

## 3D armor hover

Upstream: https://github.com/wks/3d_armor_hover @ 3f4876fa7a2e5cb1625c87b49c46f29a43176f0c (LGPLv2.1 code, CC-BY-SA-3.0 model/skins).
27 files -> mods/PLAYER/3d_armor_hover/ (7 lua + glb + 5 textures + 5 skin metas byte-identical; screenshots/images_source/models_source dropped, ~8.9MB).
Upstream minetest-mods/3d_armor NOT vendored: arch_base already ships the fuller Mineclonia stack (mcl_armor + trims + elytra, mcl_shields, mcl_wieldview entity-based) — player_api-based upstream would duplicate armor slots and conflict.
Arch Base compat patches (game_backend.lua mcl_player_backend only): mod.conf hard `depends = mcl_player, mcl_skins` for load order; sit/sit_mount/lay/spin_attack/fly routed through set_game_override so boats/carts/mounts/beds/cozy/elytra keep poses (mcl_playerplus still owns elytra physics); is_attached honors mcl_player.player_attached (cozy/beds conceptual attach); player_set_visibility blanks/restores skin slot (invisibility potions); player_set_armor re-fires registered_on_visual_change (mcl_meshhand hand toolcaps); hover .glb registered as mcl_player model for formspec previews.
Known limits (upstream-admitted): wielded bow/crossbow/shield poses, slim-arms variant, and CSM client-pose path not implemented; mcl_playerplus keeps its own eye-height tables so sneak/swim eye heights differ while hover is active.

## Shader preset

4 files -> mods/arch_shader_preset/; mod.conf rewritten (name=arch_shader_preset, title=Arch Shader Preset, depends=[]); init.lua/README.md/LICENSE byte-identical.

## Config

settingtypes.txt: Mineclonia base + 86 VoxeLibre-only keys appended (deduped by key). minetest.conf: Mineclonia verbatim (only diff vs VL was comment wording + mcl_levelgen_enable_ersatz kept).

## Asuna (leafstride + researcher)

Upstream collection: https://github.com/asuna-mt/asuna @ 0cb527a96cf744bb012be33a7759f84ff45d6be1 (MIT). Only two mods vendored; remainder rejected after audit (see rejection list below).

### leafstride

Submodule: https://github.com/asuna-mt/leafstride @ 5db4b4a60b6f91522e1a0b19709a436e37641f98 (asuna-v1.1.5, MIT).
5 files -> mods/ENVIRONMENT/leafstride/ (init.lua, mod.conf, settingtypes.txt, README.md, LICENSE byte-identical; zero deps, no patches).

### researcher

Submodule: https://github.com/asuna-mt/researcher @ 4ffa84488e1634887b23b392a7a0cf9c803613b3 (asuna-v1.1.5, MIT).
24 files -> mods/MISC/researcher/ (init.lua, mod.conf, settingtypes.txt, README.md, LICENSE, CREDITS.md, src/*.lua x8, models/research_table.obj, sounds/*.ogg x3, textures/*.png x10; .xcf/.git/screenshots dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `init.lua` | gate decoupled: loads unconditionally | upstream wrapped entire mod in `asuna.researcher_enabled` check against asuna core config; arch_base has no asuna core, mod would silently no-op |
| `mod.conf` | hard `depends = mcl_sounds, mcl_inventory, awards` | upstream had optional/soft deps on asuna-prefixed equivalents; arch_base uses Mineclonia names, load order must be guaranteed |

### Rejected Asuna mods

| mod | category | reason |
|---|---|---|
| findbiome | duplicate name | arch_base already ships mcl_findbiome / equivalent biome finder |
| awards | duplicate name | arch_base already ships awards mod (Mineclonia/VL lineage) |
| tt | duplicate name | arch_base already ships tt (tooltip) mod |
| show_wielded_item | duplicate name | arch_base already ships wielded-item HUD mod |
| stamina | default-dep | depends on minetest_game default player API; incompatible with mcl_player backend |
| soup | default-dep | references default food/hunger APIs absent in Mineclonia |
| flowerpot | default-dep | registers against default nodes; no mcl_flowers mapping |

## Asuna wave 3 (NEEDS-SHIM: geodes, bakedclay, too_many_stones, animalia, livingslimes + asuna_default_aliases shim)

Upstream collection: https://github.com/asuna-mt/asuna @ 0cb527a96cf744bb012be33a7759f84ff45d6be1 (MIT). Five mods vendored with a shared compat shim mod created locally.

### asuna_default_aliases (local shim)

Local mod at mods/COMPAT/asuna_default_aliases/ (no upstream). Zero depends. Registers `minetest.register_alias` mappings from default:* to mcl_core:* / mcl_chests:* for names confirmed present in arch_base. Also provides `default.node_sound_stone_defaults()` and `default.node_sound_defaults()` globals (guarded by `core.get_modpath("mcl_sounds")`) so geodes/bakedclay/too_many_stones can call them without hard-depending on mcl_sounds directly. Must load before geodes, bakedclay, too_many_stones.

Alias table (confirmed targets):

| default:* | arch_base target |
|---|---|
| stone | mcl_core:stone |
| dirt | mcl_core:dirt |
| dirt_with_grass | mcl_core:dirt_with_grass |
| stick | mcl_core:stick |
| clay | mcl_core:clay |
| clay_lump | mcl_core:clay_lump |
| cactus | mcl_core:cactus |
| chest | mcl_chests:chest |
| glass | mcl_core:glass |
| sand | mcl_core:sand |
| sandstone | mcl_core:sandstone |
| gravel | mcl_core:gravel |
| silver_sand | mcl_core:silver_sand |
| brick | mcl_core:brick |
| stonebrick | mcl_core:stonebrick |
| desert_sand | mcl_core:sand |
| desert_stone | mcl_core:stone |
| desert_sandstone | mcl_core:sandstone |

Unaliased default:* names (intentionally skipped — no safe arch_base equivalent; get_modpath("default")-guarded blocks in too_many_stones/bakedclay no-op safely):

- default:steel_ingot — no mcl_core steel ingot (Mineclonia uses mcl_core:iron_ingot but name mismatch would break crafts expecting "steel")
- default:mese_shard — no mese in Mineclonia
- default:dry_shrub — no dry shrub node in arch_base
- default:permafrost — no permafrost in Mineclonia
- default:silver_sandstone — no silver sandstone variant
- default:desert_sandstone — aliased to mcl_core:sandstone above (sandstone variant); listed here only if distinct node needed

### geodes

Submodule: https://github.com/asuna-mt/geodes @ c97407f6082dbd09f71a4db78c5b6c7b1fc0f417 (asuna-v1.1.5, LGPLv3 code + CC-BY-SA-3.0 textures).
Files -> mods/MISC/geodes/ (.git/.xcf/screenshots/blockbench-json dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `mod.conf` | `depends = default` -> `depends = asuna_default_aliases, mcl_sounds` | upstream hard-depends on minetest_game default; arch_base uses shim + mcl_sounds for sound defs |
| `init.lua` | `default.node_sound_stone_defaults()` resolves via global shim | no code change needed; shim provides the function |

### bakedclay

Submodule: https://github.com/asuna-mt/bakedclay @ a227f767015a5b31cd91086375b03e4d367682b1 (asuna-v1.1.5, MIT).
Files -> mods/ITEMS/bakedclay/ (.git/.xcf/screenshots/blockbench-json dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `mod.conf` | `depends = default` -> `depends = asuna_default_aliases, mcl_sounds, mcl_dye` | upstream hard-depends on default; arch_base uses shim + Mineclonia dye/sounds |
| `init.lua:162` | `default:clay` -> `mcl_core:clay` | direct node ref in craft registration |
| `init.lua:167` | `default:cactus` -> `mcl_core:cactus` | direct node ref in craft registration |
| `init.lua:168` | `default:dry_shrub` craft line REMOVED | no dry_shrub in arch_base; craft would fail registration |
| `init.lua:188` | `default:clay_brick` -> `mcl_core:brick` | direct node ref in craft registration |
| `lucky_block.lua:30,48` | `default:chest` -> `mcl_chests:chest` | loot table node refs |

### too_many_stones

Submodule: https://github.com/asuna-mt/too_many_stones @ 4f06463d7715850b77845a14285ed67e49294422 (asuna-v1.1.5, LGPLv2.1).
Files -> mods/MISC/too_many_stones/ (.git/.xcf/screenshots/blockbench-json dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `mod.conf` | optional_depends adds `asuna_default_aliases` | upstream has no explicit default dep; shim ensures aliases available if loaded |
| `crafting.lua ~2660` | NO PATCH — `get_modpath("default")` guard | entire default:-prefixed crafting block skipped when default absent (safe no-op) |
| `mapgen.lua` | NO PATCH — default: refs inside src tables guarded | mapgen ore/decoration definitions reference default: nodes only when default present; wherein="mapgen_stone" resolves via arch_base alias |

### animalia

Submodule: https://github.com/asuna-mt/animalia @ f4549e4d6f3fcab077353a16886caa6c70d48753 (asuna-v1.1.5, MIT).
Files -> mods/ENTITIES/animalia/ (.git/.xcf/screenshots/blockbench-json dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `mod.conf` | optional_depends adds `asuna_default_aliases`; hard `depends = creatura` kept | upstream depends on creatura (present in arch_base); shim optional for default: node refs |
| `init.lua` (top) | asuna global shim injected | `asuna = asuna or {content={menagerie={animals=true}}, features={animals=setmetatable({},{__index=function() return {} end})}, biomes=setmetatable({},{__index=function() return {name="unknown"} end})}` — makes asuna.features.animals[x] return {} (no biome restriction, spawns everywhere), asuna.content.menagerie.animals=true, asuna.biomes returns fallback |

### livingslimes

Submodule: https://github.com/asuna-mt/livingslimes @ 6e62b7ce70e314be7fac5636d7ec6314d51a6c62 (asuna-v1.1.5, GPLv3 code + CC-BY-SA-4.0 media).
Files -> mods/ENTITIES/livingslimes/ (.git/.xcf/screenshots/blockbench-json dropped).
Arch Base compat patches:

| file | change | reason |
|---|---|---|
| `mod.conf` | optional_depends adds `asuna_default_aliases, mcl_fire`; hard `depends = creatura` kept | upstream depends on creatura; mcl_fire optional for fire slime variants; shim optional |
| `init.lua` (top) | asuna gate shim injected | `asuna = asuna or {content={menagerie={slimes=true}}}` — gate at ~line 58 `if not asuna.content.menagerie.slimes` evaluates false, slimes enabled |

## Heart bar animations

Upstream: https://github.com/fennelfox/mcl_heart_animations @ 5cfbb0227b30a15d504ce05c6c90a6d5b8ca50a2 (2023-10-07, MIT code + CC-BY-SA-4.0 media).
3 files -> mods/HUD/mcl_heart_animations/ (init.lua reimplemented, mod.conf rewritten, README.md + LICENSE.txt byte-identical; upstream `textures/health2` flash pair dropped — flash uses the engine `^[brighten` modifier instead).
Reimplemented rather than vendored byte-identical: upstream draws 10 duplicate per-heart statbars at hardcoded offsets (-258/-110, default zigzag slot 0 only), hides the hudbars `health` bar every globalstep (fights mcl_potions poison/regen icons, mcl_powder_snow frozen hearts), leaks per-player tables on leave, and fires `minetest.after` flash callbacks for offline players. The port animates the existing hudbars statbar in place: `^[brighten` flash 3x on damage / 2x on heal (0.15s period), y-jitter shake while HP <= 4. Live offset read via `player:hud_get` so custom `hudbars_sorting` / `hudbars_start_statbar_offset_*` settings keep working; no-op while the health bar is hidden or unregistered (damage disabled).

-- 3D Armor Hovering Animations
-- Copyright (C) 2026  Kunshan Wang
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, see <https://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------
-- Model backends.  It tries to bridge with different games and set models.

local devtest_backend = {
    name = "devtest",
    initialize = function(self)
        core.register_globalstep(function()
            armor_hover.global_step()
        end)
    end,
    on_joinplayer = function(self, player)
        armor_hover.model:reset_player_model(player)
    end,
    on_leaveplayer = function(self, player)
    end,
    is_attached = function(self, player)
        return player:get_attach()
    end,
}

local player_api_backend = {
    name = "player_api",
    initialize = function(self)
        -- Hack: Override player_api.globalstep.
        -- player_api.globalstep will set animation.  If we register another global_step and change
        -- the animation to a different value, the game engine will perceive that the animation is
        -- constantly changing.  If that happens, the animation frame will be constantly reset to the
        -- starting frame, preventing the animation from playing.
        -- Instead, we disable player_api.globalstep and let it run our global_step.
        local player_api_global_step = player_api.globalstep

        player_api.globalstep = function()
            armor_hover.global_step()
        end

        local old_player_api_set_animation = player_api.set_animation

        player_api.set_animation = function(player, anim_name, speed, loop)
            -- The player_api may call set_animation before we are initialized.
            -- Just skip it.
            if not armor_hover.is_joinplayer_called(player) then return end

            -- We try our best to mimic MTG's standard animations.
            -- For MTG, we just enumerate animations in player_api/init.lua
            -- Those animations will only be played when the player is attached.
            -- This will handle the case of, e.g., driving boat, riding horse, sleeping, etc.
            -- But we restart using our own animations once the player is detached.
            if anim_name == "stand" then
                armor_hover.model:set_game_override(player, "stand", false)
            elseif anim_name == "lay" then
                armor_hover.model:set_game_override(player, "lay", false)
            elseif anim_name == "walk" then
                armor_hover.model:set_game_override(player, "walk", false)
            elseif anim_name == "mine" then
                armor_hover.model:set_game_override(player, "stand", true)
            elseif anim_name == "walkmine" then
                armor_hover.model:set_game_override(player, "walk", true)
            elseif anim_name == "sit" then
                armor_hover.model:set_game_override(player, "sit", false)
            end
        end
    end,
    on_joinplayer = function(self, player)
        armor_hover.model:reset_player_model(player)
    end,
    on_leaveplayer = function(self, player)
    end,
    is_attached = function(self, player)
        -- The player has a `get_attach()` method,
        -- but `player_api` also has a `player_attached` table that "conceptually" attaches the player.
        -- They work independently.  Mods often set both, but not always.
        return player:get_attach() or player_api.player_attached[player:get_player_name()]
    end,
}

local br_player_model_backend = {
    name = "br_player_model",
    initialize = function(self)
        -- Hack: We can't override `br_player_model.on_step`.
        -- The br_player_model mod registers its *existing value* with register_globalstep,
        -- so replacing the field br_player_model["on_step"] won't work.
        -- We can, however, override br_player_model.do_move_checks to make it a no-op.
        local old_do_move_checks = br_player_model.do_move_checks

        br_player_model.do_move_checks = function(player_name)
            -- Set it to false to skip the rest part of br_player_model.on_step
            br_player_model.pl[player_name].changed_this_step = false
        end

        -- Disable br_player_model.do_animations, too.
        -- We don't need it, and it can accidentally set eye offset on playerjoin.
        br_player_model.do_animations = function() end

        -- We need to register our own global step.
        core.register_globalstep(function()
            armor_hover.global_step()
        end)
    end,
    on_joinplayer = function(self, player)
        armor_hover.model:reset_player_model(player)
    end,
    on_leaveplayer = function(self, player)
    end,
    is_attached = function(self, player)
        return player:get_attach()
    end,
}

local mcl_player_backend = {
    name = "mcl_player",
    initialize = function(self)
        -- We need to override individual functions in the `mcl_player` module.

        -- Override eye heights.
        -- When flying, the sneak key is used for descending, not sneaking.
        -- We simply remove the eye height change.
        mcl_player.player_props_sneaking.eye_height = mcl_player.player_props_normal.eye_height
        mcl_player.player_props_swimming.eye_height = mcl_player.player_props_normal.eye_height

        local old_mcl_player_player_set_model = mcl_player.player_set_model
        mcl_player.player_set_model = function(player, model_name)
            -- We make MCL believe we have changed the model name
            -- so that other parts of MCL can query the current model name.
            -- But we don't actually set the player properties
            -- so that `3d_armor_hover` still decides the actual model.
            mcl_player.players[player].model = model_name
        end

        mcl_player.player_set_visibility = function(player, visible)
            -- mcl_potions.make_invisible is the sole caller: record the flag
            -- and blank texture slot 1 exactly like update_player_textures does.
            mcl_player.players[player].visible = visible
            local state = armor_hover.model:get_state(player)
            if not state then return end
            state.textures[1] = visible and state.skin_texture_10 or armor_hover.model.blank_texture
            armor_hover.model:reapply_player_textures(player)
        end
        mcl_player.player_set_skin = function(player, texture)
            -- mcl_skins calls this function in its on_joinplayer
            -- which is executed before our on_joinplayer.
            -- We ignore this invocation, and re-call update_player_skin
            -- in our on_joinplayer.
            if not armor_hover.is_joinplayer_called(player) then return end
            armor_hover.model:get_state(player).skin_texture_10 = texture
            armor_hover.model:set_skin_10(player, texture)
        end
        mcl_player.player_set_armor = function(player, texture)
            armor_hover.model:set_armor(player, texture)
            -- mcl_armor.update_player is the sole caller; fire the visual-change
            -- callbacks update_player_textures would have fired so mcl_meshhand
            -- (hand toolcaps) and inventory previews stay in sync.
            core.after(0.1, function()
                if player:is_player() then
                    for _, func in ipairs(mcl_player.registered_on_visual_change) do
                        func(player)
                    end
                end
            end)
        end
        mcl_player.player_set_animation = function(player, anim_name, speed)
            -- Player animation is controlled by our global step, except when
            -- attached (boat/cart/mount/bed/cozy sit-lay): route those poses
            -- through the game override so riders don't render standing.
            -- Elytra ("fly") is also a game behavior: mcl_playerplus owns the
            -- velocity/physics, so yield the pose to it via the game override
            -- rather than hanging in the hover track mid-glide.
            if not armor_hover.is_joinplayer_called(player) then return end
            if anim_name == "sit" then
                armor_hover.model:set_game_override(player, "sit", false)
            elseif anim_name == "sit_mount" then
                armor_hover.model:set_game_override(player, "sit", false)
            elseif anim_name == "lay" then
                armor_hover.model:set_game_override(player, "lay", false)
            elseif anim_name == "stand" then
                armor_hover.model:set_game_override(player, nil, false)
            elseif anim_name == "spin_attack" then
                armor_hover.model:set_game_override(player, "stand", false)
            elseif anim_name == "fly" then
                armor_hover.model:set_game_override(player, "fly_fast", false)
            end
        end

        -- We need to register our own global step.
		core.register_globalstep(function(dtime)
			armor_hover.global_step(dtime)
		end)
    end,
    on_joinplayer = function(self, player)
        armor_hover.model:reset_player_model(player)
        if mcl_skins then
            mcl_skins.update_player_skin(player)
        end
    end,
    on_leaveplayer = function(self, player)
    end,
    is_attached = function(self, player)
        -- mcl_cozy/mcl_beds attach conceptually via mcl_player.player_attached
        -- without ObjectRef:set_attach; honor both like player_api_backend does.
        return player:get_attach() or
            (mcl_player.player_attached and mcl_player.player_attached[player:get_player_name()])
    end,
}

local tutorial_backend = {
    name = "tutorial",
    initialize = function(self)
        -- Override their functions to set model/texture/animation because we handle them all.
        -- Unlike MTG, there is no need to let the game set animation because the player is never attached.
        default.player_set_model = function() end
        default.player_set_textures = function() end
        default.player_set_animation = function() end

        core.register_globalstep(function()
            armor_hover.global_step()
        end)
    end,
    on_joinplayer = function(self, player)
        armor_hover.model:reset_player_model(player)
    end,
    on_leaveplayer = function(self, player)
    end,
    is_attached = function(self, player)
        return player:get_attach()
    end,
}

if armor_hover.is_devtest then
    armor_hover.game_backend = devtest_backend
elseif armor_hover.is_player_api then
    armor_hover.game_backend = player_api_backend
elseif armor_hover.is_br_player_model then
    armor_hover.game_backend = br_player_model_backend
elseif armor_hover.is_mcl_player then
    armor_hover.game_backend = mcl_player_backend
    -- Arch Base compat: register the hover .glb as a first-class mcl_player
    -- model (deferred to initialize() so mcl_player is fully loaded) so
    -- formspec previews (get_player_formspec_model) and model queries keep
    -- working; the player_set_model override still keeps the live ObjectRef
    -- on the hover mesh.
    local old_mcl_initialize = mcl_player_backend.initialize
    mcl_player_backend.initialize = function(self)
        mcl_player.player_register_model("3d_armor_hover_character.glb", {
            animation_speed = 30,
            textures = { "blank.png", "blank.png", "blank.png" },
            animations = {
                stand = { x = 0, y = 79 },
                lay = { x = 162, y = 166 },
                walk = { x = 168, y = 187 },
                mine = { x = 189, y = 198 },
                walk_mine = { x = 200, y = 219 },
                sit = { x = 81, y = 160 },
                sneak_stand = { x = 222, y = 302 },
                sneak_walk = { x = 304, y = 323 },
                sneak_walk_mine = { x = 325, y = 344 },
                sneak_mine = { x = 346, y = 365 },
                swim_walk = { x = 368, y = 387 },
                swim_walk_mine = { x = 389, y = 408 },
                swim_stand = { x = 434, y = 434 },
                swim_mine = { x = 411, y = 430 },
                run_walk = { x = 440, y = 459 },
                run_walk_mine = { x = 461, y = 480 },
                sit_mount = { x = 484, y = 484 },
                die = { x = 498, y = 498 },
                fly = { x = 502, y = 581 },
                spin_attack = { x = 502, y = 502 },
            },
        })
        return old_mcl_initialize(self)
    end
elseif armor_hover.is_tutorial then
    armor_hover.game_backend = tutorial_backend
else
    error("We currently need one of the following mods: player_api, br_player_model, mcl_player")
end

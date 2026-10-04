-- bushy_leaves – Luanti mod to render leaves bushy
--
-- Copyright © 2022 Ælla Chiana Moskopp (erle)
-- Copyright © 2024 Mikita Wiśniewski (rudzik8)
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- Dieses Programm hat das Ziel, die Medienkompetenz der Leser zu
-- steigern. Gelegentlich packe ich sogar einen handfesten Buffer
-- Overflow oder eine Format String Vulnerability zwischen die anderen
-- Codezeilen und schreibe das auch nicht dran.

local mesh_type = core.settings:get("bushy_leaves_mesh") or "full"
local mesh_name = "bushy_leaves_" .. mesh_type .. "_model.obj"

local get_mesh = function(node_name)
	local mesh
	if (
		(string.find(node_name, "leaves") and not
		(string.find(node_name, "with_leaves")) ) or
		string.find(node_name, "needles")
	) then
		mesh = mesh_name
	end
	return mesh
end

core.register_on_mods_loaded(function()
	for node_name in pairs(core.registered_nodes) do
		local mesh = get_mesh(node_name)
		if mesh ~= nil then
			core.override_item(node_name, {
				drawtype = "mesh",
				mesh = mesh,
				paramtype = "light",
				waving = 2,
			})
		end
	end
end)

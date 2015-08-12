--[[

# Usecases

* Waterfalls, flowing going down 2+ levels
* Standing water
* Oceans

]]

environment = {
	_nodes = {}
}

function environment.register_node(name)
	local def = minetest.registered_nodes[name]
	if not def then
		error("environment.register_node(\"" .. name .. "\") : no such node!")
	elseif not def.sounds then
		error("environment.register_node(\"" .. name .. "\") : no sound table!")
	end
	def.sounds.name = name
	environment._nodes[minetest.get_content_id(name)] = def.sounds

	print("Environment : added " .. name .. " to watch list")
end

function environment.register_node_with_sounds(name, spec)
	-- Get definition
	local def = minetest.registered_nodes[name]
	if not def then
		error("environment.register_node_with_sounds(" .. name .. ", {}) : no such node!")
	end

	-- Add sounds
	if def.sounds then
		for key, value in pairs(def.sounds) do
			if not spec[key] then
				spec[key] = value
			end
		end
	end
	minetest.override_item(name, {
		sounds = spec
	})

	-- Register it
	return environment.register_node(name)
end

minetest.register_node("environment:test",{
	tiles = {"default_stone.png"},
	sounds = {
		presence = {name="small_waterfall"}
	}
})
environment.register_node("environment:test")

--[[environment.register_node_with_sounds("default:water_source", {
	presence = {name="small_waterfall"}
})]]

local SCAN_RANGE = 32
local MAX_SOURCES = 16
function environment.scan_around_player(name)
	-- Small Optimisations
	local watch_nodes = environment._nodes

	-- Get player
	local player = minetest.get_player_by_name(name)
	print("Starting scan...")

	-- Get range
	local pos = player:getpos()
	pos = vector.round(pos)
	local px, py, pz = pos.x, pos.y, pos.z
	local minp = {
		x = pos.x - SCAN_RANGE,
		y = pos.y - SCAN_RANGE,
		z = pos.z - SCAN_RANGE
	}
	local maxp = {
		x = pos.x + SCAN_RANGE,
		y = pos.y + SCAN_RANGE,
		z = pos.z + SCAN_RANGE
	}

	-- Set up voxel manip
	local vm = minetest.get_voxel_manip()
	minp, maxp = vm:read_from_map(minp, maxp)
	local a = VoxelArea:new{
			MinEdge = minp,
			MaxEdge = maxp
	}
	local data = vm:get_data()

	-- Loop through
	local count = 0
	local radius = 1
	local c2 = 0

	(function()
		local function handle_source(def, x, y, z)
			print("Adding source to (" .. x .. ", " .. y .. ", " .. z .. ")")
			minetest.sound_play(def.presence, {
				pos = {x=x, y=y, z=z},
				gain = def.presence.gain,
				max_hear_distance = SCAN_RANGE
			})
		end

		-- Check center
		--[[local vi = a:index(px, py, pz)
		local def = watch_nodes[data[vi] ]
		if def then
			handle_source(def, px, py, pz)
			count = count + 1
		end
		c2 = c2 + 1]]

		print("Scanning from " .. minetest.pos_to_string(pos) ..  " with range " .. SCAN_RANGE)

		while radius < SCAN_RANGE do
			print(" - radius " .. radius)

			-- Front and back faces
			for x = -radius, radius do
				for y = -radius, radius do
					local vi = a:index(px + x, py + y, pz + radius)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px + x, py + y, pz + radius)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 1
							return
						end
					end

					local vi = a:index(px + x, py + y, pz - radius)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px + x, py + y, pz - radius)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 2
							return
						end
					end
					c2 = c2 + 1
				end
			end

			-- Left and right
			for z = -radius, radius do
				for y = -radius, radius do
					local vi = a:index(px + radius, py + y, pz + z)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px + radius, py + y, pz + z)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 1
							return
						end
					end

					local vi = a:index(px - radius, py + y, pz + z)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px - radius, py + y, pz + z)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 2
							return
						end
					end

					c2 = c2 + 2
				end
			end

			-- Top and bottom
			for x = -radius, radius do
				for z = -radius, radius do
					local vi = a:index(px + x, py + radius, pz + z)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px + x, py + radius, pz + z)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 1
							return
						end
					end

					local vi = a:index(px + x, py - radius, pz + z)
					local def = watch_nodes[data[vi]]
					if def then
						handle_source(def, px + x, py - radius, pz + z)
						count = count + 1
						if count >= MAX_SOURCES then
							c2 = c2 + 2
							return
						end
					end

					c2 = c2 + 2
				end
			end

			radius = radius + 1
		end
	end)()

	print("End of scan. Found " .. count .. " sources out of " .. c2 .. " nodes.")

	local err = radius * radius * radius - c2
	if err > 0 then
		print("Error! Missing " .. err .. " nodes!")
	end
end

minetest.register_chatcommand("e", {
	func = environment.scan_around_player
})

--[[

# Usecases

* Waterfalls, flowing going down 2+ levels
* Standing water
* Oceans

]]

local areas = AreaStore()
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

--[[minetest.register_node("environment:test", {
	tiles = {"default_stone.png"},
	sounds = {
		presence = {name="small_waterfall"}
	}
})
environment.register_node("environment:test")]]

environment.register_node_with_sounds("default:water_source", {
	presence = {name="small_waterfall"}
})

local SCAN_RANGE = 32
local MAX_SOURCES = 16
function environment.expand_fill(cid, px, py, pz, max_radius)
	print("Scanning from " .. minetest.pos_to_string({
		x=px, y=py, z=pz
	}) ..  " looking for ID " .. cid .. " with max_radius " .. max_radius)

	-- Initiate areas
	local watch_nodes = environment._nodes
	local minp = {
		x = px - max_radius,
		y = py - max_radius,
		z = pz - max_radius
	}
	local maxp = {
		x = px + max_radius,
		y = py + max_radius,
		z = pz + max_radius
	}
	local ax, bx = px, px
	local ay, by = py, py
	local az, bz = pz, pz

	-- Set up voxel manip
	local vm = minetest.get_voxel_manip()
	minp, maxp = vm:read_from_map(minp, maxp)
	local a = VoxelArea:new{MinEdge = minp, MaxEdge = maxp}
	local data = vm:get_data()

	-- Expand cuboid
	local c2 = 0, 0
	local function expand()
		local top_fine = true
		local bottom_fine = true

		-- Front and back faces
		local front_fine = true
		local back_fine = true
		for x = ax, bx do
			for y = ay, by do
				if front_fine then
					local vi = a:index(x, y, az - 1)
					c2 = c2 + 1
					if data[vi] ~= cid then
						front_fine = false
					end
				end

				if back_fine then
					local vi = a:index(x, y, bz + 1)
					c2 = c2 + 1
					if data[vi] ~= cid then
						back_fine = false
					end
				end
			end
		end
		if front_fine then
			az = az - 1
			--print("Expanded one.z to " .. az)
		end
		if back_fine then
			bz = bz + 1
			--print("Expanded two.z to " .. bz)
		end

		-- Left and right faces
		local left_fine = true
		local right_fine = true
		for z = az, bz do
			for y = ay, by do
				if left_fine then
					local vi = a:index(ax - 1, y, z)
					c2 = c2 + 1
					if data[vi] ~= cid then
						left_fine = false
					end
				end

				if right_fine then
					local vi = a:index(bx + 1, y, z)
					c2 = c2 + 1
					if data[vi] ~= cid then
						right_fine = false
					end
				end
			end
		end
		if left_fine then
			ax = ax - 1
			--print("Expanded one.x to " .. ax)
		end
		if right_fine then
			bx = bx + 1
			--print("Expanded two.x to " .. bx)
		end

		-- Top and bottom faces
		local top_fine = true
		local bottom_fine = true
		for x = az, bz do
			for z = ay, by do
				if top_fine then
					local vi = a:index(x, ay - 1, z)
					c2 = c2 + 1
					if data[vi] ~= cid then
						top_fine = false
					end
				end

				if bottom_fine then
					local vi = a:index(x, by + 1, z)
					c2 = c2 + 1
					if data[vi] ~= cid then
						bottom_fine = false
					end
				end
			end
		end
		if top_fine then
			ay = ay - 1
			--print("Expanded one.y to " .. ay)
		end
		if bottom_fine then
			by = by + 1
			--print("Expanded two.y to " .. by)
		end

		return front_fine or back_fine or left_fine or right_fine
	end

	for i = 1, max_radius do
		--print("- iteration " .. i)
		if not expand() then
			break
		end
	end

	local a = {x=ax, y=ay, z=az}
	local b = {x=bx, y=by, z=bz}
	print(minetest.pos_to_string(a) .. " to " .. minetest.pos_to_string(b))
	print("Checked " .. c2 .. " nodes.")

	-- Insert into AreaStore
	areas:insert_area(a, b, cid)
end

function environment.scan_around_player(name)
	local watch_nodes = environment._nodes
	local player = minetest.get_player_by_name(name)
	local pos = player:getpos()
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

	local arealist = areas:get_areas_in_area(minp, maxp, true, true, true)
	for i, area in pairs(arealist) do
		local source = {
			x = (area.min.x + area.max.x) / 2,
			y = (area.min.y + area.max.y) / 2,
			z = (area.min.z + area.max.z) / 2
		}
		local def = watch_nodes[math.floor(tonumber(area.data))]

		print("Adding source to " .. minetest.pos_to_string(source))
		local handle = minetest.sound_play(def.presence, {
			pos = source,
			gain = def.presence.gain,
			max_hear_distance = SCAN_RANGE
		})

		if i > 16 then
			print("Bigger than 16!")
			break
		end
	end
end

minetest.register_chatcommand("e", {
	func = function(name)
		environment.expand_fill(minetest.get_content_id("default:water_source"), 0, 0, 0, 20)
	end
})

minetest.register_chatcommand("s", {
	func = environment.scan_around_player
})

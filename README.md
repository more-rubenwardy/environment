# Environment

Adds environmental sounds to Minetest

Created by rubenwardy.

License: LGPL 2.1 or later.

# Work in Progress

This project is a Work in Progress

* environment.expand_fill(cid, px, py, pz, max_radius)
	* Combines multiple nodes of the same type into a cubic AreaStore entry.
	* Good for large surfaces of water.
	* TODO:
		* Check for collisions with existing stores.
* environment.scan_around_player(name)
	* Scans for sound sources and plays them.
	* TODO:
		* don't just play sounds for the center of an area,
			play from edge if outside.
		* water sounds should come from surface.
* TODO:
	* run environment.expand_fill on mapgen somehow.

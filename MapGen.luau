--[[

		=========================================
			12x12 TILE-BASED MAP GENERATOR BY
		=========================================
	      ___                                           
	     /__/\         _____          ___         ___   
	     \  \:\       /  /::\        /  /\       /__/|  
	      \  \:\     /  /:/\:\      /  /:/      |  |:|  
	  _____\__\:\   /  /:/~/::\    /  /:/       |  |:|  
	 /__/::::::::\ /__/:/ /:/\:|  /  /::\     __|__|:|  
	 \  \:\~~\~~\/ \  \:\/:/~/:/ /__/:/\:\   /__/::::\  
	  \  \:\  ~~~   \  \::/ /:/  \__\/  \:\     ~\~~\:\ 
	   \  \:\        \  \:\/:/        \  \:\      \  \:\
	    \  \:\        \  \::/          \__\/       \__\/
	     \__\/         \__\/                            
--]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local StoneSword = ReplicatedStorage:WaitForChild("Stone Sword") -- For potential RPG system

-- ==============================
-- CONFIG
-- ==============================
local TILE_SIZE = 12
local MAX_TILES = 96000
local MAX_ITERATIONS = 6000
local PADDING = 12

-- ==============================
-- TILE TEMPLATES
-- ==============================

local TileTemplates = ServerStorage:WaitForChild("TileTemplatesMesh")

local TILE_TYPES = {
	Floor = {
		template = TileTemplates:WaitForChild("FloorTile"),
		weight = 50,
		walkable = true,
	},
	Chest = {
		template = TileTemplates:WaitForChild("ChestTile"),
		weight = 0,
		walkable = true,
	},
	Trap = {
		template = TileTemplates:WaitForChild("TrapTile"),
		weight = 10,
		walkable = false,
	},

	-- FILLER TILES (NOT RANDOMLY GENERATED)
	Grass = {
		template = TileTemplates:WaitForChild("GrassTile"),
		weight = 0,
		walkable = false,
	},

	Tree = {
		template = TileTemplates:WaitForChild("TreeTile"),
		weight = 0,
		walkable = false,
	},

	Rock = {
		template = TileTemplates:WaitForChild("RockTile"),
		weight = 0,
		walkable = false,
	},
	Boulder = {
		template = TileTemplates:WaitForChild("BoulderTile"),
		weight = 0,
		walkable = false,
	},
	Cluster = {
		template = TileTemplates:WaitForChild("ClusterTile"),
		weight = 0,
		walkable = false,
	},
	Cluster2 = {
		template = TileTemplates:WaitForChild("Cluster2Tile"),
		weight = 0,
		walkable = false,
	},
	Cluster3 = {
		template = TileTemplates:WaitForChild("Cluster3Tile"),
		weight = 0,
		walkable = false,
	},
	Pond = {
		template = TileTemplates:WaitForChild("PondTile"),
		weight = 0,
		walkable = false,
	}
	
}


local STRUCTURES = {
	VillageHouse = {
		template = TileTemplates:WaitForChild("VillageHouse"),
		sizeX = 4, -- 48 studs
		sizeY = 3, -- 36 studs
		walkable = false,
		weight = 2,
	},
	SmallVillage = {
		template = TileTemplates:WaitForChild("SmallVillage"),
		sizeX = 10, -- 120 studs
		sizeY = 11, -- 132 studs
		walkable = false,
		weight = 6,
	},
	SmallPond = {
		template = TileTemplates:WaitForChild("PondTile"),
		sizeX = 2, -- 24 studs
		sizeY = 2, -- 24 studs
		walkable = false,
		weight = 3,
	},
}

-- ==============================
-- INTERNAL STATE
-- ==============================

local tiles = {}        -- ["x,y"] = tile
local frontier = {}
local tileCount = 0

-- HELPERS
local function key(x, y)
	return x .. "," .. y
end

local directions = {
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
}


-- ==============================
-- STRUCTURE HELPERS
-- ==============================

local function isAdjacentToWalkable(x, y, sizeX, sizeY, radius)
	for dx = -radius, sizeX + radius - 1 do
		for dy = -radius, sizeY + radius - 1 do
			local t = tiles[key(x + dx, y + dy)]
			if t and t:GetAttribute("Walkable") then
				return true
			end
		end
	end
	return false
end

local function canPlaceStructure(x, y, sizeX, sizeY)
	for dx = 0, sizeX - 1 do
		for dy = 0, sizeY - 1 do
			if tiles[key(x + dx, y + dy)] then
				return false
			end
		end
	end
	return true
end

local function placeStructure(x, y, structure)
	local model = structure.template:Clone()
	model.Name = "Structure"
	model.Parent = workspace

	local rotationSteps = math.random(0, 3)
	local rotation = CFrame.Angles(0, math.rad(90 * rotationSteps), 0)

	-- swap footprint if rotated
	local sizeX, sizeY = structure.sizeX, structure.sizeY
	if rotationSteps % 2 == 1 then
		sizeX, sizeY = sizeY, sizeX
	end

	local worldX = (x + sizeX / 2 - 0.5) * TILE_SIZE
	local worldZ = (y + sizeY / 2 - 0.5) * TILE_SIZE

	model:PivotTo(CFrame.new(worldX, 0, worldZ) * rotation)

	-- reserve grid cells
	for dx = 0, sizeX - 1 do
		for dy = 0, sizeY - 1 do
			local k = key(x + dx, y + dy)
			tiles[k] = model
		end
	end
end

-- ==============================
-- WEIGHTED TILE PICK (WALKABLE PATH ONLY)
-- ==============================

local function pickTileType(x, y)
	local distance = math.abs(x) + math.abs(y)

	if distance <= 1 then
		return "Floor", TILE_TYPES.Floor
	end

	local totalWeight = 0
	for _, data in pairs(TILE_TYPES) do
		totalWeight += data.weight
	end

	local roll = math.random(totalWeight)
	local running = 0

	for name, data in pairs(TILE_TYPES) do
		if data.weight > 0 then
			running += data.weight
			if roll <= running then
				return name, data
			end
		end
	end
end

-- ==============================
-- PLACE TILE
-- ==============================

local function placeTile(x, y)
	local tileTypeName, tileData = pickTileType(x, y)
	local tile = tileData.template:Clone()

	tile.Name = "Tile"
	tile.Parent = workspace
	tile:PivotTo(CFrame.new(x * TILE_SIZE, 0, y * TILE_SIZE))

	tile:SetAttribute("GridX", x)
	tile:SetAttribute("GridY", y)
	tile:SetAttribute("TileType", tileTypeName)
	tile:SetAttribute("Walkable", tileData.walkable)

	tiles[key(x, y)] = tile
	table.insert(frontier, { x = x, y = y })
	tileCount += 1

end

-- ==============================
-- SPAWN TILE
-- ==============================
do
	local tile = TILE_TYPES.Floor.template:Clone()
	tile.Name = "Tile"
	tile.Parent = workspace
	tile:PivotTo(CFrame.new(0, 0, 0))

	tile:SetAttribute("GridX", 0)
	tile:SetAttribute("GridY", 0)
	tile:SetAttribute("TileType", "Floor")
	tile:SetAttribute("Walkable", true)

	tiles[key(0, 0)] = tile
end
-- ==============================
-- START CHEST TILE
-- ==============================

do
	local x, y = 0, 1
	local tile = TILE_TYPES.Chest.template:Clone()
	tile.Name = "Tile"
	tile.Parent = workspace
	tile:PivotTo(CFrame.new(x * TILE_SIZE, 0, y * TILE_SIZE))

	tile:SetAttribute("GridX", x)
	tile:SetAttribute("GridY", y)
	tile:SetAttribute("TileType", "Chest")
	tile:SetAttribute("Walkable", true)

	tiles[key(x, y)] = tile
	table.insert(frontier, { x = x, y = y })
	tileCount += 1
end

-- ==============================
-- MAZE GENERATION
-- ==============================

local iterations = 0

while #frontier > 0 and tileCount < MAX_TILES do
	iterations += 1
	if iterations > MAX_ITERATIONS then break end

	local cell = frontier[#frontier]

	for i = #directions, 2, -1 do
		local j = math.random(i)
		directions[i], directions[j] = directions[j], directions[i]
	end

	local expanded = false
	for _, dir in ipairs(directions) do
		local nx, ny = cell.x + dir[1], cell.y + dir[2]
		if not tiles[key(nx, ny)] then
			placeTile(nx, ny)
			expanded = true
			break
		end
	end

	if not expanded then
		table.remove(frontier)
	end
end

-- ==============================
-- GAP FILL (UNREACHABLE TILES)
-- ==============================

-- Bounds
local minX, maxX, minY, maxY = 0, 0, 0, 0
local PADDING = 3
for _, tile in pairs(tiles) do
	local x, y = tile:GetAttribute("GridX"), tile:GetAttribute("GridY")
	minX = math.min(minX, x)
	maxX = math.max(maxX, x)
	minY = math.min(minY, y)
	maxY = math.max(maxY, y)
end

minX -= PADDING
maxX += PADDING
minY -= PADDING
maxY += PADDING

-- ==============================
-- Flood fill reachable
-- ==============================

local reachable = {}
local queue = { { x = 0, y = 0 } }
reachable["0,0"] = true

while #queue > 0 do
	local cell = table.remove(queue, 1)
	for _, dir in ipairs(directions) do
		local nx, ny = cell.x + dir[1], cell.y + dir[2]
		local k = key(nx, ny)
		if tiles[k] and not reachable[k] and tiles[k]:GetAttribute("Walkable") then
			reachable[k] = true
			table.insert(queue, { x = nx, y = ny })
		end
	end
end

-- ==============================
-- STRUCTURE PLACEMENT
-- ==============================


-- ==============================
-- Large structures FIRST
-- ==============================

for x = minX, maxX do
	for y = minY, maxY do
		if not tiles[key(x, y)] and not reachable[key(x, y)] then
			if math.random() < 0.004 then
				if canPlaceStructure(x, y, STRUCTURES.SmallVillage.sizeX, STRUCTURES.SmallVillage.sizeY) then
					placeStructure(x, y, STRUCTURES.SmallVillage)
				end
			end
		end
	end
end

-- ==============================
-- Smaller structures AFTER
-- ==============================

for x = minX, maxX do
	for y = minY, maxY do
		if not tiles[key(x, y)] and not reachable[key(x, y)] then
			if math.random() < 0.002 then
				if canPlaceStructure(x, y, STRUCTURES.VillageHouse.sizeX, STRUCTURES.VillageHouse.sizeY) then
					placeStructure(x, y, STRUCTURES.VillageHouse)
				end
			end
		end
	end
end

-- ==============================
-- POND STRUCTURES
-- ==============================

for x = minX, maxX do
	for y = minY, maxY do
		if not tiles[key(x, y)] and not reachable[key(x, y)] then

			if math.random() < 0.001 then -- spawn chance
				if canPlaceStructure(x, y,
					STRUCTURES.SmallPond.sizeX,
					STRUCTURES.SmallPond.sizeY) then

					placeStructure(x, y, STRUCTURES.SmallPond)
				end
			end
		end
	end
end
-- ==============================
-- FILLER PICK
-- ==============================

local FILLERS = {
	{ data = TILE_TYPES.Grass, weight = 50 },
	{ data = TILE_TYPES.Tree, weight = 25 },
	{ data = TILE_TYPES.Cluster, weight = 20 },
	{ data = TILE_TYPES.Cluster2, weight = 10 },
	{ data = TILE_TYPES.Cluster3, weight = 15 },
	{ data = TILE_TYPES.Rock, weight = 5 },
	{ data = TILE_TYPES.Boulder, weight = 3 },
}
-- ==============================
-- PLACING FILLER
-- ==============================

for x = minX, maxX do
	for y = minY, maxY do
		if not tiles[key(x, y)]
			and not reachable[key(x, y)]
			and isAdjacentToWalkable(x, y, STRUCTURES.SmallVillage.sizeX, STRUCTURES.SmallVillage.sizeY, 2) then

			if math.random() < 0.002 then
				if canPlaceStructure(x, y,
					STRUCTURES.SmallVillage.sizeX,
					STRUCTURES.SmallVillage.sizeY) then

					placeStructure(x, y, STRUCTURES.SmallVillage)
				end
			end
		end
	end
end



-- ==============================
-- FINAL RECTANGULAR MAP BOUNDS
-- ==============================

local FINAL_PADDING = 6

local finalMinX, finalMaxX = math.huge, -math.huge
local finalMinY, finalMaxY = math.huge, -math.huge

for _, tile in pairs(tiles) do
	local gx = tile:GetAttribute("GridX")
	local gy = tile:GetAttribute("GridY")

	if gx and gy then
		finalMinX = math.min(finalMinX, gx)
		finalMaxX = math.max(finalMaxX, gx)
		finalMinY = math.min(finalMinY, gy)
		finalMaxY = math.max(finalMaxY, gy)
	end
end

finalMinX -= FINAL_PADDING
finalMaxX += FINAL_PADDING
finalMinY -= FINAL_PADDING
finalMaxY += FINAL_PADDING

local function pickFiller()
	local totalWeight = 0
	for _, f in ipairs(FILLERS) do
		totalWeight += f.weight
	end

	local roll = math.random(totalWeight)
	local running = 0

	for _, f in ipairs(FILLERS) do
		running += f.weight
		if roll <= running then
			return f.data
		end
	end
end

-- ==============================
-- FINAL RECTANGULAR FILL
-- ==============================

for x = finalMinX, finalMaxX do
	for y = finalMinY, finalMaxY do
		local k = key(x, y)

		if not tiles[k] then
			local filler = pickFiller()
			local tile = filler.template:Clone()

			local rotationSteps = math.random(0, 3)
			local rotation = CFrame.Angles(0, math.rad(90 * rotationSteps), 0)

			tile.Name = "Tile"
			tile.Parent = workspace
			tile:PivotTo(CFrame.new(x * TILE_SIZE, 0, y * TILE_SIZE) * rotation)

			tile:SetAttribute("GridX", x)
			tile:SetAttribute("GridY", y)
			tile:SetAttribute("TileType", "FinalFill")
			tile:SetAttribute("Walkable", false)

			tiles[k] = tile
		end
	end
end

print("MAP GEN COMPLETE:", tileCount, "walkable tiles")

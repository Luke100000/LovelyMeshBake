require("run")
local fastLove = require("libs/fastLove/fastLove")(512)
local lovelyMeshBake = require("lovelyMeshBake")

fastLove.image:setFilter("nearest")

love.graphics.setBackgroundColor(0.1, 0.4, 0.5)
love.window.setMode(1200, 800)
love.window.setVSync(0)

local textures = { }
for _, v in ipairs(love.filesystem.getDirectoryItems("textures")) do
	textures[v:sub(1, -5)] = love.graphics.newImage("textures/" .. v)
end

--use a custom shader to make use of our special var
local shader = love.graphics.newShader("shader.glsl")

--create the mesh format, we use an additional float to store the bevel
local meshFormat = {
	{ "VertexPosition", "float", 2, "vertex", { "x", "y" } },
	{ "VertexTexCoord", "float", 2, "uv", { "u", "v" } },
	{ "VertexColor", "byte", 4, "color", { "r", "g", "b", "a" } },
	{ "Edge", "float", 1, "edge", { "edge" } },
}

--create the renderer
local renderer = lovelyMeshBake(fastLove.image, meshFormat)

--load the models. They can be quite bulky, therefore they are put in individual files
local models = { }
models.simple = require("models/simple")(renderer)
models.edges = require("models/edges")(renderer)

--quads for the tiled textures
local quads = {
	{
		love.graphics.newQuad(0, 0, 1, 1, 2, 2),
		love.graphics.newQuad(0, 1, 1, 1, 2, 2),
	}, {
		love.graphics.newQuad(1, 0, 1, 1, 2, 2),
		love.graphics.newQuad(1, 1, 1, 1, 2, 2),
	}
}

--block descriptions
local blocks = {
	{ name = "chest", shadow = false, tiled = false },
	{ name = "dirt_stone", shadow = true, tiled = true },
	{ name = "grass", shadow = true, tiled = true },
	{ name = "sawmill", shadow = false, tiled = false },
	{ name = "stone", shadow = true, tiled = true },
}

--set the world size, where 100 uses a example world
local zoom = 100

--the world, 0 is used for air
local world
if zoom == 100 then
	world = {
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 3, 0, 1, 0, 0, 0, 0, 0, 0, 0, 3, 3 },
		{ 2, 3, 3, 0, 0, 0, 0, 3, 3, 3, 2, 2 },
		{ 5, 2, 2, 3, 0, 4, 3, 2, 2, 2, 5, 5 },
		{ 5, 5, 5, 2, 3, 3, 2, 5, 5, 5, 5, 5 },
		{ 5, 5, 5, 5, 2, 2, 5, 5, 5, 5, 5, 5 },
		{ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	}
else
	local h = 800 / zoom
	local function noise(x, y)
		return love.math.noise(x / 10, y / 10) - y / h < 0
	end
	world = { }
	for y = 1, h do
		world[y] = { }
		for x = 1, 1200 / zoom do
			world[y][x] = noise(x, y) and 5 or noise(x, y + 1) and 2 or noise(x, y + 2) and 3 or 0
		end
	end
end

--helper function to check if a block "connects"
local function hasShadow(x, y)
	local block = world[y] and world[y][x]
	return block and block > 0 and blocks[block].shadow
end

--the block indices in the render mesh, used to delete blocks without re-rendering the entire world/chunk
local indices = { }

--re-renders a single block
local function renderBlock(x, y)
	if not world[y] or not world[y][x] then
		return
	end
	
	--remove old block
	if indices[y][x] then
		renderer:remove(indices[y][x])
	end
	
	local block = world[y][x]
	if block > 0 then
		local b = blocks[block]
		
		local et = hasShadow(x, y - 1)
		local el = hasShadow(x - 1, y)
		local er = hasShadow(x + 1, y)
		local eb = hasShadow(x, y + 1)
		
		if b.shadow then
			local variables = {
				(et and el and hasShadow(x - 1, y - 1)) and 0 or 1,
				et and 0 or 1,
				(et and er and hasShadow(x + 1, y - 1)) and 0 or 1,
				el and 0 or 1,
				er and 0 or 1,
				(eb and el and hasShadow(x - 1, y + 1)) and 0 or 1,
				eb and 0 or 1,
				(eb and er and hasShadow(x + 1, y + 1)) and 0 or 1,
				quad = fastLove:getQuad(textures[b.name], b.tiled and quads[x % 2 + 1][y % 2 + 1])
			}
			
			indices[y][x] = renderer:add(models.edges, variables, x - 1, y - 1)
		else
			local quad = fastLove:getQuad(textures[b.name], b.tiled and quads[x % 2 + 1][y % 2 + 1])
			indices[y][x] = renderer:add(models.simple, { quad = quad }, x - 1, y - 1)
		end
	else
		indices[y][x] = false
	end
end

--render the world
for y, col in ipairs(world) do
	indices[y] = { }
	for x, _ in ipairs(col) do
		renderBlock(x, y)
	end
end

local function setBlock(bx, by, b)
	if world[by][bx] ~= b or true then
		world[by][bx] = b
		
		for x = -1, 1 do
			for y = -1, 1 do
				renderBlock(bx + x, by + y)
			end
		end
	end
end

function love.draw()
	--draw the world
	love.graphics.setShader(shader)
	renderer:draw(0, 0, 0, zoom)
	
	--some stats
	love.graphics.print(string.format("%d FPS\nCapacity: %d, %d\nIntegrity: %.3f, %.3f", love.timer.getFPS(), renderer.vertexCapacity, renderer.indexCapacity, renderer:getVertexIntegrity(), renderer:getIndexIntegrity()), 5, 5)
	
	--build
	local bx, by = love.mouse.getPosition()
	bx = math.ceil(bx / zoom)
	by = math.ceil(by / zoom)
	if world[by] and world[by][bx] then
		if love.mouse.isDown(1) then
			setBlock(bx, by, 0)
		elseif love.mouse.isDown(2) then
			setBlock(bx, by, 5)
		end
	end
end
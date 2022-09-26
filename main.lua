local fastLove = require("libs/fastLove/fastLove")(512)
local lovelyMeshBake = require("lovelyMeshBake")

fastLove.image:setFilter("nearest")
love.graphics.setBackgroundColor(0.1, 0.4, 0.5)

local textures = { }
for _, v in ipairs(love.filesystem.getDirectoryItems("textures")) do
	textures[v:sub(1, -5)] = love.graphics.newImage("textures/" .. v)
end

--create the mesh format, we use an additional float to store the bevel
local meshFormat = {
	{ "VertexPosition", "float", 2, "vertex", { "x", "y" } },
	{ "VertexTexCoord", "float", 2, "uv", { "u", "v" } },
	{ "VertexColor", "byte", 4, "color", { "r", "g", "b", "a" } },
	{ "Edge", "float", 1, "edge", { "edge" } },
}

--create the renderer
local renderer = lovelyMeshBake(fastLove.image, meshFormat)

--create our models
local models = { }
models.simple = renderer:newModel()
						:vertex(0, 0):uv(0, 0):color(255, 255, 255, 255):next()
						:vertex(1, 0):uv(1, 0):color(255, 255, 255, 255):next()
						:vertex(1, 1):uv(1, 1):color(255, 255, 255, 255):next()
						:vertex(0, 1):uv(0, 1):color(255, 255, 255, 255):next()
						:face()
						:build()

--load the models. They can be quite bulky, therefore they are put in individual files
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

--the world, 0 is used for air
local world = {
	{ 0, 0, 0, 0, 0, 0, 0, 0 },
	{ 3, 0, 1, 0, 0, 0, 0, 0 },
	{ 2, 3, 3, 0, 0, 0, 0, 3 },
	{ 5, 2, 2, 3, 0, 4, 3, 2 },
	{ 5, 5, 5, 2, 3, 3, 2, 5 },
	{ 5, 5, 5, 5, 2, 2, 5, 5 },
}

local function hasShadow(x, y)
	local block = world[y] and world[y][x]
	return block and block > 0 and blocks[block].shadow
end

--the block indices in the render mesh, used to delete blocks without re-rendering the entire world/chunk
local indices = { }

--render the world
for y, col in ipairs(world) do
	indices[y] = { }
	for x, block in ipairs(col) do
		if block > 0 then
			local b = blocks[block]
			
			local et = hasShadow(x, y - 1)
			local el = hasShadow(x - 1, y)
			local er = hasShadow(x + 1, y)
			local eb = hasShadow(x, y + 1)
			
			if b.shadow then
				local edges = {
					(et and el and hasShadow(x - 1, y - 1)) and 0 or 1,
					et and 0 or 1,
					(et and er and hasShadow(x + 1, y - 1)) and 0 or 1,
					el and 0 or 1,
					er and 0 or 1,
					(eb and el and hasShadow(x - 1, y + 1)) and 0 or 1,
					eb and 0 or 1,
					(eb and er and hasShadow(x + 1, y + 1)) and 0 or 1,
				}
				
				local quad = fastLove:getQuad(fastLove:getSprite(textures[b.name]), b.tiled and quads[x % 2 + 1][y % 2 + 1])
				indices[y][x] = { renderer:add(models.edges, quad, edges, x - 1, y - 1) }
			else
				local quad = fastLove:getQuad(fastLove:getSprite(textures[b.name]), b.tiled and quads[x % 2 + 1][y % 2 + 1])
				indices[y][x] = { renderer:add(models.simple, quad, false, x - 1, y - 1) }
			end
		else
			indices[y][x] = false
		end
	end
end

--use a custom shader to make use of our special var
local shader = love.graphics.newShader("shader.glsl")

function love.draw()
	love.graphics.setShader(shader)
	renderer:draw(0, 0, 0, 100)
end
local fastLove = require("libs/fastLove/fastLove")(512)
local lovelyMeshBake = require("lovelyMeshBake")

fastLove.image:setFilter("nearest")
love.graphics.setBackgroundColor(0.1, 0.4, 0.5)

local textures = { }
for _, v in ipairs(love.filesystem.getDirectoryItems("textures")) do
	textures[v:sub(1, -5)] = love.graphics.newImage("textures/" .. v)
end

local renderer = lovelyMeshBake(fastLove.image)

local model = renderer:newModel()
					  :vertex(0, 0):uv(0, 0):color(255, 255, 255, 255):next()
					  :vertex(1, 0):uv(1, 0):color(255, 255, 255, 255):next()
					  :vertex(1, 1):uv(1, 1):color(255, 255, 255, 255):next()
					  :vertex(0, 1):uv(0, 1):color(255, 255, 255, 255):next()
					  :face()
					  :build()

local blocks = {
	{ name = "chest", shadow = false, tiled = false },
	{ name = "dirt_stone", shadow = true, tiled = true },
	{ name = "grass", shadow = true, tiled = true },
	{ name = "sawmill", shadow = false, tiled = false },
	{ name = "stone", shadow = true, tiled = true },
}

local world = {
	{ 0, 0, 0, 0, 0, 0, 0, 0 },
	{ 3, 0, 1, 0, 0, 0, 0, 0 },
	{ 2, 3, 3, 0, 0, 0, 0, 3 },
	{ 5, 2, 2, 3, 0, 4, 3, 2 },
	{ 5, 5, 5, 2, 3, 3, 2, 5 },
	{ 5, 5, 5, 5, 2, 2, 5, 5 },
}

local quads = {
	{
		love.graphics.newQuad(0, 0, 1, 1, 2, 2),
		love.graphics.newQuad(0, 1, 1, 1, 2, 2),
	}, {
		love.graphics.newQuad(1, 0, 1, 1, 2, 2),
		love.graphics.newQuad(1, 1, 1, 1, 2, 2),
	}
}

for y, col in ipairs(world) do
	for x, block in ipairs(col) do
		if block > 0 then
			local b = blocks[block]
			local quad = fastLove:getQuad(fastLove:getSprite(textures[b.name]), b.tiled and quads[x % 2 + 1][y % 2 + 1])
			renderer:add(model, quad, x - 1, y - 1)
		end
	end
end

function love.draw()
	renderer:draw(0, 0, 0, 100)
end
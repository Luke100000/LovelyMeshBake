local builder = require((...) .. "/builder")
local spacer = require((...) .. "/spacer")

local mat4 = _G.mat4 or require("libs/luaMatrices/mat4")

local ffi = _G.ffi or require("ffi")

local meta = { }

function meta:newModel()
	return builder(self)
end

function meta:add(model, quad, x, y, r, sx, sy, ox, oy, kx, ky)
	--place vertices
	local vertexOffset = false
	while not vertexOffset do
		vertexOffset = self.vertexSpace:get(model.vertexCount)
		if not vertexOffset then
			self:resizeVertex()
		end
	end
	ffi.copy(self.vertices + (vertexOffset - 1), model.vertices, ffi.sizeof(self.vertexIdentifier) * model.vertexCount)
	
	--set exceptions
	local t = self.transform:transform(x, y, r, sx, sy, ox, oy, kx, ky)
	for i = 0, model.vertexCount - 1 do
		self.vertices[i + vertexOffset - 1].x = t[1] * model.vertices[i].x + t[2] * model.vertices[i].y + t[4]
		self.vertices[i + vertexOffset - 1].y = t[5] * model.vertices[i].x + t[6] * model.vertices[i].y + t[8]
		
		self.vertices[i + vertexOffset - 1].u = model.vertices[i].u * quad[3] + quad[1]
		self.vertices[i + vertexOffset - 1].v = model.vertices[i].v * quad[4] + quad[2]
	end
	
	--place indices
	local indexOffset = false
	while not indexOffset do
		indexOffset = self.indexSpace:get(model.vertexMapLength)
		if not indexOffset then
			self:resizeIndices()
		end
	end
	self.size = math.max(self.size, indexOffset + model.vertexMapLength - 1)
	for i = 0, model.vertexMapLength - 1 do
		self.indices[i + indexOffset - 1] = model.indices[i] + (vertexOffset - 1)
	end
	
	self.dirty = true
end

function meta:translate(x, y)
	self.transform = self.transform:translate(x, y)
end

function meta:scale(x, y)
	self.transform = self.transform:scale(x, y)
end

function meta:rotate(rot)
	self.transform = self.transform:rotateZ(-rot)
end

function meta:origin()
	self.transform = mat4.getIdentity()
end

function meta:push()
	table.insert(self.stack, self.transform)
end

function meta:pop()
	self.transform = table.remove(self.stack)
end

function meta:draw(...)
	if self.size > 0 then
		if self.dirty then
			self.mesh:setVertices(self.byteData)
			self.mesh:setVertexMap(self.vertexMapByteData, "uint32")
			self.dirty = false
		end
		self.mesh:setDrawRange(1, self.size)
		love.graphics.draw(self.mesh, ...)
	end
end

function meta:resizeVertex()
	self.vertexSpace:increase(self.vertexCapacity)
	self.vertexCapacity = self.vertexCapacity * 2
	
	local oldByteData = self.byteData
	local oldVertex = self.vertices
	
	--create
	self.byteData = love.data.newByteData(ffi.sizeof(self.vertexIdentifier) * self.vertexCapacity * 4)
	self.vertices = ffi.cast(self.vertexIdentifier .. "*", self.byteData:getFFIPointer())
	
	--copy old part
	if oldByteData then
		ffi.copy(self.vertices, oldVertex, ffi.sizeof(self.vertexIdentifier) * self.vertexCapacity * 4 / 2)
	end
	
	--new mesh
	self.mesh = love.graphics.newMesh(self.meshFormat, self.byteData, "triangles", "static")
	
	--set atlas
	self.mesh:setTexture(self.image)
end

function meta:resizeIndices()
	self.indexSpace:increase(self.indexCapacity)
	self.indexCapacity = self.indexCapacity * 2
	
	local oldVertexMapByteData = self.vertexMapByteData
	local oldIndices = self.indices
	
	--create
	self.vertexMapByteData = love.data.newByteData(ffi.sizeof("uint32_t") * self.indexCapacity * 6)
	self.indices = ffi.cast("uint32_t*", self.vertexMapByteData:getFFIPointer())
	
	--copy old part
	if oldVertexMapByteData then
		ffi.copy(self.indices, oldIndices, ffi.sizeof("uint32_t") * self.indexCapacity * 6 / 2)
	end
end

meta.__index = meta

local defaultMeshFormat = {
	{ "VertexPosition", "float", 2, "vertex", { "x", "y" } },
	{ "VertexTexCoord", "float", 2, "uv", { "u", "v" } },
	{ "VertexColor", "byte", 4, "color", { "r", "g", "b", "a" } },
}

local function constructor(image, meshFormat)
	local r = setmetatable({}, meta)
	
	r.image = image
	
	r.meshFormat = meshFormat or defaultMeshFormat
	r.vertexIdentifier = "vertex_" .. tostring(r.meshFormat):sub(8)
	
	--build C struct
	local format = { }
	for _, f in ipairs(r.meshFormat) do
		table.insert(format, f[2]:gsub("byte", "unsigned char") .. " " .. table.concat(f[5], ", ") .. ";")
	end
	local code = "typedef struct {" .. table.concat(format, " ") .. "} " .. r.vertexIdentifier .. "";
	ffi.cdef(code)
	
	--current transform
	r.transform = mat4.getIdentity()
	
	--the data space manager
	r.vertexSpace = spacer(1)
	r.indexSpace = spacer(1)
	
	--maximum used index
	r.size = 0
	
	r.vertexCapacity = 1
	r.indexCapacity = 1
	
	r:resizeVertex()
	r:resizeIndices()
	
	return r
end

return constructor
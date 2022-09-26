local builder = require((...) .. "/builder")
local cache = require((...) .. "/cache")

local mat4 = _G.mat4 or require("libs/luaMatrices/mat4")

local ffi = _G.ffi or require("ffi")

local meta = { }

function meta:newModel()
	return builder(self)
end

function meta:add(model, quad, variables, x, y, r, sx, sy, ox, oy, kx, ky)
	--defragment
	if self:getVertexIntegrity() < self.minIntegrity or self:getIndexIntegrity() < self.minIntegrity then
		self:defragment()
	end
	
	--resize
	while self.vertexIndex + model.vertexCount > self.vertexCapacity do
		self:resizeVertex()
	end
	while self.indexIndex + model.vertexMapLength > self.indexCapacity do
		self:resizeIndices()
	end
	
	--try to use cache
	local vertexIndex = self.vertexCache:pop(model.vertexCount)
	if not vertexIndex then
		vertexIndex = self.vertexIndex
		self.vertexIndex = self.vertexIndex + model.vertexCount
	end
	
	local indexIndex = self.indexCache:pop(model.vertexMapLength)
	if not indexIndex then
		indexIndex = self.indexIndex
		self.indexIndex = self.indexIndex + model.vertexMapLength
	end
	
	--place vertices
	ffi.copy(self.vertices + vertexIndex, model.vertices, ffi.sizeof(self.vertexIdentifier) * model.vertexCount)
	
	--set exceptions
	local t = self.transform:transform(x, y, r, sx, sy, ox, oy, kx, ky)
	for i = 0, model.vertexCount - 1 do
		self.vertices[i + vertexIndex].x = t[1] * model.vertices[i].x + t[2] * model.vertices[i].y + t[4]
		self.vertices[i + vertexIndex].y = t[5] * model.vertices[i].x + t[6] * model.vertices[i].y + t[8]
		
		self.vertices[i + vertexIndex].u = model.vertices[i].u * quad[3] + quad[1]
		self.vertices[i + vertexIndex].v = model.vertices[i].v * quad[4] + quad[2]
	end
	
	--set variables
	if variables then
		for i, value in ipairs(variables) do
			for _, vertex in ipairs(model.variablesList[i]) do
				self.vertices[vertex[1] + vertexIndex][vertex[2]] = value
			end
		end
	end
	
	--place indices
	for i = 0, model.vertexMapLength - 1 do
		self.indices[i + indexIndex] = model.indices[i] + vertexIndex
	end
	
	self.lastChunkId = self.lastChunkId + 1
	self.chunks[self.lastChunkId] = {
		vertexIndex, model.vertexCount,
		indexIndex, model.vertexMapLength
	}
	
	self.vertexTotal = self.vertexTotal + model.vertexCount
	self.indexTotal = self.indexTotal + model.vertexMapLength
	
	self.dirty = true
	
	return self.lastChunkId
end

function meta:remove(id)
	local chunk = self.chunks[id]
	self.chunks[id] = nil
	
	--clear indices
	for i = chunk[3], chunk[3] + chunk[4] - 1 do
		self.indices[i] = 0
	end
	
	self.vertexTotal = self.vertexTotal - chunk[2]
	self.indexTotal = self.indexTotal - chunk[4]
	
	self.vertexCache:push(chunk[2], chunk[1])
	self.indexCache:push(chunk[4], chunk[3])
	
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
	if self.indexIndex > 0 then
		if self.dirty then
			self.mesh:setVertices(self.byteData, 1, self.vertexIndex)
			self.mesh:setVertexMap(self.vertexMapByteData, "uint32")
			self.dirty = false
		end
		self.mesh:setDrawRange(1, self.indexIndex)
		love.graphics.draw(self.mesh, ...)
	end
end

function meta:getVertexIntegrity()
	return self.vertexTotal / self.vertexIndex
end

function meta:getIndexIntegrity()
	return self.indexTotal / self.indexIndex
end

function meta:defragment()
	local oldByteData = self.byteData
	local oldVertices = self.vertices
	local oldVertexMapByteData = self.vertexMapByteData
	local oldIndices = self.indices
	
	--create
	self.byteData = love.data.newByteData(ffi.sizeof(self.vertexIdentifier) * self.vertexCapacity)
	self.vertices = ffi.cast(self.vertexIdentifier .. "*", self.byteData:getFFIPointer())
	self.vertexMapByteData = love.data.newByteData(ffi.sizeof("uint32_t") * self.indexCapacity)
	self.indices = ffi.cast("uint32_t*", self.vertexMapByteData:getFFIPointer())
	
	--copy old part
	self.vertexIndex = 0
	self.indexIndex = 0
	if oldByteData and oldVertexMapByteData then
		for id, chunk in pairs(self.chunks) do
			ffi.copy(self.vertices + self.vertexIndex, oldVertices + chunk[1], ffi.sizeof(self.vertexIdentifier) * chunk[2])
			
			--move indices
			for i = 0, chunk[4] - 1 do
				self.indices[self.indexIndex + i] = oldIndices[i + chunk[3]] - chunk[1] + self.vertexIndex
			end
			
			self.chunks[id] = { self.vertexIndex, chunk[2], self.indexIndex, chunk[4] }
			self.vertexIndex = self.vertexIndex + chunk[2]
			self.indexIndex = self.indexIndex + chunk[4]
		end
	end
	
	self.vertexTotal = self.vertexIndex
	self.indexTotal = self.indexIndex
	
	self.vertexCache = cache()
	self.indexCache = cache()
end

function meta:resizeVertex()
	self.vertexCapacity = self.vertexCapacity * 2
	
	local oldByteData = self.byteData
	local oldVertices = self.vertices
	
	--create
	self.byteData = love.data.newByteData(ffi.sizeof(self.vertexIdentifier) * self.vertexCapacity)
	self.vertices = ffi.cast(self.vertexIdentifier .. "*", self.byteData:getFFIPointer())
	
	--copy old part
	if oldByteData then
		ffi.copy(self.vertices, oldVertices, ffi.sizeof(self.vertexIdentifier) * self.vertexCapacity / 2)
	end
	
	--new mesh
	self.mesh = love.graphics.newMesh(self.meshFormat, self.byteData, "triangles", "static")
	
	--set atlas
	self.mesh:setTexture(self.image)
	
	self.vertexCache = cache()
end

function meta:resizeIndices()
	self.indexCapacity = self.indexCapacity * 2
	
	local oldVertexMapByteData = self.vertexMapByteData
	local oldIndices = self.indices
	
	--create
	self.vertexMapByteData = love.data.newByteData(ffi.sizeof("uint32_t") * self.indexCapacity)
	self.indices = ffi.cast("uint32_t*", self.vertexMapByteData:getFFIPointer())
	
	--copy old part
	if oldVertexMapByteData then
		ffi.copy(self.indices, oldIndices, ffi.sizeof("uint32_t") * self.indexCapacity / 2)
	end
	
	self.indexCache = cache()
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
	
	r.minIntegrity = 0.9
	
	r.vertexIndex = 0
	r.indexIndex = 0
	
	r.vertexCapacity = 1
	r.indexCapacity = 1
	
	r.vertexTotal = 0
	r.indexTotal = 0
	
	r.lastChunkId = 0
	r.chunks = { }
	r.vertexCache = cache()
	r.indexCache = cache()
	
	if image then
		r:resizeVertex()
		r:resizeIndices()
	end
	
	return r
end

return constructor
local builder = { }

local ffi = _G.ffi or require("ffi")

--new builder
local function constructor(renderer)
	local b = setmetatable({ }, builder)
	
	b.renderer = renderer
	
	--current model, face and vertex
	b.model = { }
	b.currentFace = { }
	b.currentVertex = { }
	b.vertexCount = 0
	
	--create some lookup tables
	b.vertexSize = 0
	b.lookup = { }
	b.formatLookup = { }
	b.toIndex = { }
	b.toKey = { }
	for _, f in ipairs(renderer.meshFormat) do
		b.lookup[f[4]] = f[5]
		b.formatLookup[f[4]] = f[2]
		for i = 1, f[3] do
			b.vertexSize = b.vertexSize + 1
			b.toIndex[f[5][i]] = b.vertexSize
			b.toKey[b.vertexSize] = f[5][i]
		end
	end
	
	--empty default vertex
	b.empty = { __index = { } }
	for i = 1, b.vertexSize do
		b.empty.__index[i] = 0
	end
	
	--start first vertex
	b:nextVertex()
	
	return b
end

--set any additional data
function builder:nextVertex()
	self.currentVertex = setmetatable({}, self.empty)
end

--next vertex
function builder:next()
	self.vertexCount = self.vertexCount + 1
	table.insert(self.currentFace, self.currentVertex)
	self:nextVertex()
	return self
end

--next face
function builder:face()
	table.insert(self.model, self.currentFace)
	self:nextVertex()
	self.currentFace = { }
	return self
end

--done, build model
function builder:build()
	self.byteData = love.data.newByteData(ffi.sizeof(self.renderer.vertexIdentifier) * self.vertexCount)
	self.vertices = ffi.cast(self.renderer.vertexIdentifier .. "*", self.byteData:getFFIPointer())
	
	local v = 0
	local indices = { }
	for _, face in ipairs(self.model) do
		--fan style
		for index = 1, #face - 2 do
			table.insert(indices, v)
			table.insert(indices, v + index)
			table.insert(indices, v + index + 1)
		end
		
		for _, vertex in ipairs(face) do
			local vert = self.vertices[v]
			for index, value in ipairs(vertex) do
				vert[self.toKey[index]] = value
			end
			v = v + 1
		end
	end
	
	--copy vertex map
	self.vertexMapLength = #indices
	self.vertexMapByteData = love.data.newByteData(ffi.sizeof(self.renderer.vertexIdentifier) * self.vertexMapLength)
	self.indices = ffi.cast("uint32_t*", self.vertexMapByteData:getFFIPointer())
	for i, value in ipairs(indices) do
		self.indices[i - 1] = value
	end
	
	return self
end

function builder:__index(key)
	if self.lookup[key] then
		return function(self, ...)
			local arg = { ... }
			for i = 1, #self.lookup[key] do
				local var = self.lookup[key][i]
				self.currentVertex[self.toIndex[var]] = arg[i]
			end
			return self
		end
	end
	
	return builder[key]
end

return constructor
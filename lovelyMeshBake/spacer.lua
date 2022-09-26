--[[
Space arranging library. It arranges spaces. Not that fast tbh but it works.

local space = require("spacer")(initialSize)

--resize (only larger!)
space:increase(newSize)

--returns the index or false
space:get(size)

--frees a space, does not check if it is indeed used
space:free(index, size)
--]]

local spacer = { }

function spacer:getSize()
	return self.head[3] + self.head[4] - 1
end

function spacer:getIntegrity()
	local node = self.head
	local sum = 0
	while node do
		if node[2] then
			sum = sum + node[4]
		end
		node = node[1]
	end
	return sum / self:getSize()
end

function spacer:increase(size)
	self.head = {
		self.head, --previous
		false, --occupied
		self:getSize() + 1, --index
		size, --size
	}
	self:merge(self.head)
end

function spacer:get(size)
	local node = self.head
	local lastNode = node
	
	self.steps = 0
	while node do
		self.steps = self.steps + 1
		
		--find free and large enough segment
		if not node[2] and node[4] >= size then
			if node[4] == size then
				--fits perfectly!
				node[2] = true
				local i = node[3]
				self:merge(lastNode)
				return i
			else
				--split that node
				local newNode = {
					node[1], --previous
					true, --occupied
					node[3], --index
					size, --size
				}
				
				local i = node[3]
				
				--and crop the existing node
				node[1] = newNode
				node[3] = node[3] + size
				node[4] = node[4] - size
				
				--merge
				self:merge(node)
				return i
			end
		else
			lastNode = node
			node = node[1]
		end
	end
end

function spacer:free(index, size)
	--find the node in question
	local node = self.head
	local right = node
	self.steps = 0
	while node[3] > index do
		self.steps = self.steps + 1
		right = node
		node = node[1]
	end
	
	--split part left
	if node[3] < index then
		local newNode = {
			node[1], --previous
			node[2], --occupied
			node[3], --index
			index - node[3], --size
		}
		node[1] = newNode
		node[3] = node[3] + newNode[4]
		node[4] = node[4] - newNode[4]
	end
	
	--split part right
	if node[4] > size then
		local newNode = {
			node[1], --previous
			node[2], --occupied
			node[3], --index
			size, --size
		}
		node[1] = newNode
		node[3] = node[3] + size
		node[4] = node[4] - size
		
		right = node
		node = newNode
	end
	
	--free that node
	node[2] = false
	
	--and merge
	self:merge(right)
end

--merge two nodes if their occupy flag is the same
function spacer:merge(node)
	for _ = 1, 2 do
		if node[1] and node[2] == node[1][2] then
			--expand
			node[3] = node[1][3]
			node[4] = node[1][4] + node[4]
			
			--unlink the left node
			node[1] = node[1][1]
		else
			node = node[1]
			if not node then
				break
			end
		end
	end
end

spacer.__index = spacer

function spacer:__tostring()
	local v = { }
	local node = self.head
	while node do
		table.insert(v, 1, string.rep(node[2] and "⬜" or "⬛", node[4]))
		node = node[1]
	end
	return table.concat(v, "")
end

function spacer:print()
	print(self)
	local v = { }
	local node = self.head
	while node do
		table.insert(v, 1, "[" .. node[3] .. " - " .. (node[3] + node[4] - 1) .. " (" .. (node[2] and "full" or "free") .. ")]")
		node = node[1]
	end
	print(table.concat(v, " "))
	print()
end

local function constructor(size)
	--a single linked list is used to store segments
	return setmetatable({
		head = {
			false, --previous
			false, --occupied
			1, --index
			size --size
		},
		steps = 0
	}, spacer)
end

return constructor
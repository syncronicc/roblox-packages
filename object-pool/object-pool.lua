--!strict
--------------------------------------------------------------------------------
-- ObjectPool.luau
-- A typed, free-list object pool for BasePart instances.
--
-- MIT License · Copyright (c) 2026 @kts
--------------------------------------------------------------------------------
local FAR_POSITION=Vector3.new(0,-10000,0)
local schedule=task.spawn
local insert=table.insert
local remove=table.remove
local find=table.find

local INVALID_OBJECT_TYPE=`[ObjectPool]: Presented object template is not a BasePart!`
local INVALID_OBJECT_RETURN=`[ObjectPool]: Returned object does not belong to this pool!`
local INVALID_SIZE=`[ObjectPool]: SizeLimit must be a positive integer!`
local ObjectInUse="ObjectPool: IN USE"

-- >> TYPES << ---------------------------------------------------------------
export type ObjectPool={
	Instance:BasePart,
	SizeLimit:number,
	Size:number,
	_pool:{BasePart},
	_free:{BasePart},
	_destroyed:boolean,
	_RecalculateSize:(self:ObjectPool)->(),
	_PushObject:(self:ObjectPool,Object:BasePart)->(),
	CreateObject:(self:ObjectPool)->BasePart,
}

-- >> CONSTRUCTOR << ---------------------------------------------------------------
local service={}
service.__index=service

function service._RecalculateSize(self:ObjectPool)
	local total=0 do
		for _ in self._pool do
			total+=1
		end
	end

	if total>self.SizeLimit then
		for i=total,self.SizeLimit+1,-1 do
			if self._pool[i] then
				self._pool[i]:Destroy()
				self._pool[i]=nil
			end
		end
	end

	self.Size=#self._pool
end

function service._PushObject(self:ObjectPool,object:BasePart)
	object.Position=FAR_POSITION
end

function service.new(object:BasePart,max_limit:number)
	assert(typeof(object)=='Instance'and object:IsA('BasePart'),INVALID_OBJECT_TYPE)
	assert(typeof(max_limit)=='number'and max_limit>0 and max_limit==math.floor(max_limit),INVALID_SIZE)

	local self=setmetatable({} :: ObjectPool,service)
	self._pool={}
	self._free={}
	self._destroyed=false

	self.Instance=object
	self.SizeLimit=max_limit
	self.Size=0

	schedule(function()
		for _=1,self.SizeLimit do
			local clone=object:Clone()
			clone.Parent=object.Parent or workspace
			clone.Position=FAR_POSITION
			
			insert(self._pool,clone)
			insert(self._free,clone)
			
			self.Size+=1
		end
	end)

	return self
end

-- >> METHODS << ---------------------------------------------------------------
function service.CreateObject(self:ObjectPool):BasePart
	assert(not self._destroyed,`[ObjectPool]: Cannot call CreateObject on a destroyed pool!`)
	
	local object=self.Instance
	local new=object:Clone()
	new.Parent=object.Parent
	new.Position=FAR_POSITION

	insert(self._pool,new)
	insert(self._free,new)
	self.Size+=1
	return new
end

function service.ReturnObject(self:ObjectPool,object:BasePart)
	assert(not self._destroyed,`[ObjectPool]: Cannot call ReturnObject on a destroyed pool!`)
	assert(find(self._pool,object)~=nil,INVALID_OBJECT_RETURN)

	if self.Size>self.SizeLimit then
		local idx=find(self._pool,object)
		if idx then
			remove(self._pool,idx)
		end
		object:Destroy()
		self.Size-=1
	else
		self:_PushObject(object)
		object:SetAttribute(ObjectInUse,nil)
		insert(self._free,object)
	end
end

function service.GetObject(self:ObjectPool):BasePart
	assert(not self._destroyed,`[ObjectPool]: Cannot call GetObject on a destroyed pool!`)

	if #self._free==0 then
		return self:CreateObject()
	end

	local object=remove(self._free) :: BasePart
	object:SetAttribute(ObjectInUse,true)
	return object
end

function service.GetSize(self:ObjectPool):number
	assert(not self._destroyed,`[ObjectPool]: Cannot call GetSize on a destroyed pool!`)
	self:_RecalculateSize()
	return self.Size
end

function service.Cleanup(self:ObjectPool)
	assert(not self._destroyed,`[ObjectPool]: Pool is already destroyed!`)

	for _,object in self._pool do
		if object and object.Parent then
			object:Destroy()
		end
	end

	self._pool={}
	self._free={}
	self.Size=0
	self._destroyed=true
end

return service

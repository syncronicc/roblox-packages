--!strict
--------------------------------------------------------------------------------
-- DataService.luau
-- A reuseable data controller
--
-- MIT License · Copyright (c) 2026 @kts
--------------------------------------------------------------------------------

local DataStoreService=game:GetService('DataStoreService')
local Players=game:GetService('Players')

local FAILED_TO_FETCH_PROFILE="[DataService]: Failed to fetch %s's profile!"

-- >> TYPES << -----------------------------------------------------------------
export type Profile={[string]: any}
export type DataService={
	ProfileCache: {[Player]: Profile},
	Data: DataStore,
	Template: Profile,
	LoadProfile: (self: DataService, player: Player, key: string) -> Profile?,
	SaveProfile: (self: DataService, player: Player, key: string) -> (),
	GetProfile: (self: DataService, player: Player) -> Profile?,
	GetAllProfiles: (self: DataService) -> {[Player]: Profile},
}

local function DeepCopy(t: Profile): Profile
	local copy: Profile={}
	for k, v in t do
		copy[k]=type(v)=="table" and DeepCopy(v :: Profile) or v
	end
	return copy
end

local function DeepMerge(old: Profile, new: Profile): Profile
	for k, v in new do
		if type(v)=="table" and type(old[k])=="table" then
			DeepMerge(old[k] :: Profile, v :: Profile)
		else
			old[k]=v
		end
	end
	return old
end

local function Reconcile(data: Profile, template: Profile): Profile
	for k, v in template do
		if data[k]==nil then
			data[k]=type(v)=="table" and DeepCopy(v :: Profile) or v
		elseif type(v)=="table" and type(data[k])=="table" then
			Reconcile(data[k] :: Profile, v :: Profile)
		end
	end
	return data
end

-- >> CONSTRUCTOR << -----------------------------------------------------------
local service={}
service.__index=service

function service.new(name: string, template: Profile?): DataService
	local self=setmetatable({}, service)

	self.ProfileCache={} :: {[Player]: Profile}
	self.Data=DataStoreService:GetDataStore(name) :: DataStore
	self.Template=(template or {Cash=50}) :: Profile

	game:BindToClose(function()
		local remaining=0
		for _, player in Players:GetPlayers() do
			remaining+=1
			task.spawn(function()
				self:SaveProfile(player, tostring(player.UserId))
				remaining-=1
			end)
		end
		while remaining>0 do task.wait() end
	end)

	return self::any
end

-- >> METHODS << ---------------------------------------------------------------
function service:LoadProfile(player: Player, key: string): Profile?
	if not self.Data then return nil end

	local success, result=pcall(function(): Profile?
		return self.Data:GetAsync(key)
	end)

	if not success then
		warn(FAILED_TO_FETCH_PROFILE:format(player.Name))
		return nil
	end

	local data=result :: Profile?

	if data==nil then
		data=DeepCopy(self.Template)
	else
		data=Reconcile(data, self.Template)
	end

	if not self.ProfileCache[player] then
		self.ProfileCache[player]=data :: Profile
	end

	return self.ProfileCache[player]
end

function service:SaveProfile(player: Player, key: string): ()
	if not self.Data then return end

	local success, err=pcall(function()
		self.Data:UpdateAsync(key, function(old: Profile?): Profile?
			local new=self:GetProfile(player)
			if not new then return old end
			if not old then return new end
			return DeepMerge(old, new)
		end)
	end)

	if not success then
		warn(`[DataService]: Failed to save {player.Name}'s data: {tostring(err)}`)
	end
end

-- >> MISC << ------------------------------------------------------------------
function service:GetProfile(player: Player): Profile?
	return self.ProfileCache[player]
end

function service:GetAllProfiles(): {[Player]: Profile}
	return self.ProfileCache
end

return service

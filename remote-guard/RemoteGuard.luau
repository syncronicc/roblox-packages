--!strict
--------------------------------------------------------------------------------
-- RemoteGuard.luau
-- A reuseable remote event/remote function guard.
--
-- MIT License · Copyright (c) 2026 @kts
--------------------------------------------------------------------------------

local RunService=game:GetService('RunService')
local Players=game:GetService('Players')

local INVALID_NUMBER_PROVIDED=`[RemoteGuard]: You have provided a invalid number!`

export type Connection={
	Connected:boolean,
	Disconnect:(self:Connection)->(),
}

export type Signal<T...> ={
	Connect:(self:Signal<T...>,fn:(T...)->())->Connection,
	Fire:(self:Signal<T...>,T...)->(),
	DisconnectAll:(self:Signal<T...>)->(),
}

local insert=table.insert
local clear=table.clear

-- >> SIGNAL CLASS << -----------------------------------------------------------------

local signal={}
signal.__index=signal

function signal.new<T...>():Signal<T...>
	return setmetatable({_connections={}::{(...any)->()}},signal) :: any
end

function signal.Connect(self:any,fn:(...any)->()):Connection
	insert(self._connections,fn)
	local conn={
		Connected=true,
		Disconnect=function(c:Connection)
			c.Connected=false
			for i,v in self._connections do
				if v==fn then
					table.remove(self._connections,i)
					break
				end
			end
		end,
	}
	return conn
end

function signal.Fire(self:any,...:any)
	local copy=table.clone(self._connections)
	for _,callback in copy do
		callback(...)
	end
end

function signal.DisconnectAll(self:any)
	clear(self._connections)
end

-- >> CONSTRUCTOR << -----------------------------------------------------------------

local service={}
service.__index=service

function service.new(remote:RemoteEvent|RemoteFunction)
	local self=setmetatable({},service)
	self._Remote=remote
	self._Options={
		Cooldown=0;

		NeedsCharacter=false;
		IsInDistance=false;
		IsAlive=false;
		Terminate=function(player:Player)
			return true
		end,
	}
	self.Cache={}

	Players.PlayerAdded:Connect(function(player)
		self.Cache[player]=0
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Cache[player]=nil
	end)

	for _,player in Players:GetPlayers()do
		self.Cache[player]=0
	end

	return self
end

-- >> METHODS << -----------------------------------------------------------------

function service.SetCooldown(self,number)
	assert(typeof(number)=='number')

	self._Options.Cooldown=number

	return self
end

function service.SetAliveRequirement(self,r)
	self._Options.IsAlive=r or false
	return self
end
function service.SetCharacterRequirement(self,r)
	self._Options.NeedsCharacter=r or false
	return self
end
function service.SetDistanceRequirement(self,r)
	self._Options.IsInDistance=r or false
	return self
end
function service.TerminateCallback(self,callback)
	self._Options.Terminate=callback
	return self
end

-- >> MISC << -----------------------------------------------------------------

function service:_Validate(player:Player,...)
	if self._Options.Cooldown > 0 then
		local last=self.Cache[player] or 0
		if os.time()-last<self._Options.Cooldown then
			return false
		end
		self.Cache[player]=os.time()
	end

	if self._Options.NeedsCharacter then
		if not player.Character then
			self._Options.Terminate(player)
			return false
		end
	end

	local Character=player.Character
	if not Character then return false end

	if typeof(self._Options.IsInDistance)=='table'then
		if(Character.PrimaryPart.Position-self._Options.IsInDistance.Position).Magnitude>self._Options.IsInDistance.Range then
			self._Options.Terminate(player)
			return false
		end
	end
	if self._Options.IsAlive then
		local Humanoid=Character:FindFirstChildOfClass('Humanoid')

		if Humanoid and Humanoid.Health<=0 then
			self._Options.Terminate(player)
			return false
		end
	end

	return true
end

function service:Connect(fn: (player: Player, ...any) -> ())
	assert(RunService:IsServer(), `[RemoteGuard]: Connect must be called from the server!`)
	local remote=self._Remote

	if remote:IsA('RemoteEvent') then
		remote.OnServerEvent:Connect(function(player, ...)
			if not self:_Validate(player, ...) then return end
			fn(player, ...)
		end)
	elseif remote:IsA('RemoteFunction') then
		remote.OnServerInvoke=function(player, ...)
			if not self:_Validate(player, ...) then return end
			return fn(player, ...)
		end
	end
end


return service

--!strict

--------------------------------------------------------------------------------
-- PlayerBinder.luau
-- A very useful module that helps the 
--
-- MIT License · Copyright (c) 2026 @kts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
--------------------------------------------------------------------------------

local Players=game:GetService('Players')

local clear=table.clear
local insert=table.insert

export type Connection={
	Connected:boolean,
	Disconnect:(self:Connection)->(),
}

export type Signal<T...> ={
	Connect:(self:Signal<T...>,fn:(T...)->())->Connection,
	Fire:(self:Signal<T...>,T...)->(),
	DisconnectAll:(self:Signal<T...>)->(),
}

export type ServiceObject={
	added:Signal<Player>,
	removing:Signal<Player>,
	_map:{[Player]:boolean},
	_connections:{RBXScriptConnection},
	GetPlayer:(self:ServiceObject,player:Player)->boolean?,
	GetAllPlayers:(self:ServiceObject)->{Player},
	ObserveAdded:(self:ServiceObject,fn:(player:Player)->())->Connection,
	Cleanup:(self:ServiceObject)->(),
}

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

local service={}
service.__index=service

function service.new():ServiceObject
	local self=setmetatable({},service)

	self.added=signal.new()
	self.removing=signal.new()
	self._map={}::{[Player]:boolean}
	self._connections={}::{RBXScriptConnection}

	insert(self._connections,Players.PlayerAdded:Connect(function(player:Player)
		if self._map[player] then return end
		self._map[player]=true
		self.added:Fire(player)
	end))

	insert(self._connections,Players.PlayerRemoving:Connect(function(player:Player)
		if not self._map[player] then return end
		self.removing:Fire(player)
		self._map[player]=nil
	end))

	for _,player in Players:GetPlayers() do
		if self._map[player] then continue end
		self._map[player]=true
		self.added:Fire(player)
	end

	return self :: any
end

function service.GetPlayer(self:ServiceObject,player:Player):boolean?
	return self._map[player]
end

function service.GetAllPlayers(self:ServiceObject):{Player}
	local result={}::{Player}
	for player in self._map do
		insert(result,player)
	end
	return result
end

function service.ObserveAdded(self:ServiceObject,fn:(player:Player)->()):Connection
	for player in self._map do
		fn(player)
	end
	return self.added:Connect(fn)
end

function service.Cleanup(self:ServiceObject)
	for _,conn in self._connections do
		conn:Disconnect()
	end
	clear(self._connections)
	self.added:DisconnectAll()
	self.removing:DisconnectAll()
	clear(self._map)
end

return service

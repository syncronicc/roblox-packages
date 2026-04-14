--!strict
--------------------------------------------------------------------------------
-- NetService.luau
-- A simple remote event wrapper for server-client communication.
--
-- MIT License Copyright (c) 2026 @kts
--------------------------------------------------------------------------------
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local insert = table.insert
local remove = table.remove
local clear = table.clear
local find = table.find

-->> Types

type Callback<T...> = (T...) -> ()

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type SignalData<T...> = {
	_connections: { Callback<T...> },
}

export type Signal<T...> = SignalData<T...> & {
	Connect: (self: Signal<T...>, fn: Callback<T...>) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type RemoteGuard = {
	Connect: (self: RemoteGuard, fn: (...any) -> ()) -> any,
}

type ServiceData = {
	Connections: { RBXScriptConnection },
	_remote: RemoteEvent,
	_guard: RemoteGuard?,
}

export type Service = ServiceData & {
	Guard: (self: Service, remoteGuard: RemoteGuard) -> Service,
	Connect: (self: Service, fn: (...any) -> ()) -> Service,
	Once: (self: Service, fn: (...any) -> ()) -> Service,
	Cleanup: (self: Service) -> (),
}

-->> Signal Class

local signal = {}
signal.__index = signal

function signal.new<T...>(): Signal<T...>
	local self: SignalData<T...> = {
		_connections = {},
	}

	return setmetatable(self, signal) :: any
end

function signal.Connect<T...>(self: Signal<T...>, fn: Callback<T...>): Connection
	insert(self._connections, fn)

	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function(conn: Connection)
			conn.Connected = false

			for index, callback in self._connections do
				if callback == fn then
					remove(self._connections, index)
					break
				end
			end
		end,
	}

	return connection
end

function signal.Fire<T...>(self: Signal<T...>, ...: T...)
	local callbacks = table.clone(self._connections)

	for _, callback in callbacks do
		callback(...)
	end
end

function signal.DisconnectAll<T...>(self: Signal<T...>)
	clear(self._connections)
end

-->> Constructor

local service = {}
service.__index = service

-->> Methods

function service.on(remote: RemoteEvent): Service
	local self: ServiceData = {
		Connections = {},
		_remote = remote,
		_guard = nil,
	}

	return setmetatable(self, service) :: any
end

function service.fire(remote: RemoteEvent, player: Player, ...: any)
	if RunService:IsClient() then
		remote:FireServer(...)
	elseif RunService:IsServer() then
		remote:FireClient(player, ...)
	end
end

function service.fire_all(remote: RemoteEvent, ...: any)
	if RunService:IsServer() then
		remote:FireAllClients(...)
	end
end

function service.fire_except(remote: RemoteEvent, exceptions: { number }, ...: any)
	if RunService:IsServer() then
		for _, player in Players:GetPlayers() do
			if find(exceptions, player.UserId) then
				continue
			end

			remote:FireClient(player, ...)
		end
	end
end

-->> Meta-Methods

function service:Guard(remoteGuard: RemoteGuard): Service
	self._guard = remoteGuard
	return self
end

function service:Connect(fn: (...any) -> ()): Service
	if RunService:IsServer() then
		if self._guard ~= nil then
			self._guard:Connect(function(...)
				fn(...)
			end)
		else
			insert(self.Connections, self._remote.OnServerEvent:Connect(function(...)
				fn(...)
			end))
		end
	else
		insert(self.Connections, self._remote.OnClientEvent:Connect(function(...)
			fn(...)
		end))
	end

	return self
end

function service:Once(fn: (...any) -> ()): Service
	local fired = false

	if RunService:IsServer() then
		if self._guard ~= nil then
			self._guard:Connect(function(...)
				if fired then
					return
				end

				fired = true
				fn(...)
			end)
		else
			local connection: RBXScriptConnection
			connection = self._remote.OnServerEvent:Connect(function(...)
				connection:Disconnect()
				fn(...)
			end)
			insert(self.Connections, connection)
		end
	else
		local connection: RBXScriptConnection
		connection = self._remote.OnClientEvent:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		insert(self.Connections, connection)
	end

	return self
end

-->> Misc

function service:Cleanup()
	for _, connection in self.Connections do
		connection:Disconnect()
	end

	clear(self.Connections)
end

return service

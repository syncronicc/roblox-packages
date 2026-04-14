--!strict
--------------------------------------------------------------------------------
-- TimerService.luau
-- MIT License · Copyright (c) 2026 @kts
--------------------------------------------------------------------------------

-->> Types

--- A handle returned by `Signal:Connect`. Call `Disconnect` to unsubscribe.
export type Connection={
	Connected:boolean,
	Disconnect:(self:Connection)->(),
}

--- Typed signal. `T...` is the tuple passed to every listener on `Fire`.
export type Signal<T...> ={
	Connect:(self:Signal<T...>,fn:(T...)->())->Connection,
	Fire:(self:Signal<T...>,T...)->(),
	DisconnectAll:(self:Signal<T...>)->(),
}

--- The public shape of a `TimerService` instance.
export type TimerService={
	_running:boolean,
	_paused:boolean,
	_time:number,
	_scale:number,
	_thread:thread?,
	Signals:{
		--- Fires every `scale` seconds with the elapsed time so far.
		Tick:Signal<number>,
		--- Fires when `Pause()` is called.
		Paused:Signal<()>,
		--- Fires when `Stop()` is called manually.
		Stopped:Signal<()>,
		--- Fires when `Resume()` is called.
		Resumed:Signal<()>,
		--- Fires during `Cleanup()` before all signals are disconnected.
		Cleanup:Signal<()>,
		--- Fires when the timer reaches the requested duration naturally.
		Finished:Signal<()>,
	},
	Start:(self:TimerService,seconds:number)->TimerService,
	SetTimeScale:(self:TimerService,n:number)->TimerService,
	Pause:(self:TimerService)->TimerService,
	Resume:(self:TimerService)->TimerService,
	Stop:(self:TimerService)->TimerService,
	Cleanup:(self:TimerService)->(),
}

-->> Locals

local insert=table.insert
local clear=table.clear

-->> Signal

local Signal={}
Signal.__index=Signal

function Signal.new<T...>():Signal<T...>
	return setmetatable({_connections={}::{(...any)->()}},Signal)::any
end

function Signal.Connect(self:any,fn:(...any)->()): Connection
	insert(self._connections,fn)
	local conn:Connection={
		Connected=true,
		Disconnect=function(c:Connection)
			if not c.Connected then return end
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

function Signal.Fire(self:any,...:any)
	local copy=table.clone(self._connections)
	for _,callback in copy do
		callback(...)
	end
end

function Signal.DisconnectAll(self:any)
	clear(self._connections)
end

-->> Constructor

local service={}
service.__index=service

--- Creates a new `TimerService` instance.
--- ```lua
--- local timer = TimerService.new()
--- ```
function service.new():TimerService
	local self=setmetatable({},service) do
		self._running=false
		self._paused=false
		self._time=0
		self._scale=1
		self._thread=nil::thread?
		self.Signals={
			Tick=Signal.new()::Signal<number>,
			Paused=Signal.new()::Signal<()>,
			Stopped=Signal.new()::Signal<()>,
			Resumed=Signal.new()::Signal<()>,
			Cleanup=Signal.new()::Signal<()>,
			Finished=Signal.new()::Signal<()>,
		}
	end
	return self::any
end

-->> Methods

--- Starts the timer for `seconds` duration.
--- If a previous run is active it is cancelled first, so `Start` also acts as a restart.
--- `Signals.Tick` fires every `_scale` seconds; `Signals.Finished` fires when the duration elapses naturally.
--- @param seconds number Total duration to count up to (in real seconds).
--- @return TimerService Returns `self` for chaining.
function service:Start(seconds:number):TimerService
	if self._running then
		self._running=false
		if self._thread then
			task.cancel(self._thread)
			self._thread=nil
		end
	end

	self._running=true
	self._paused=false

	self._thread=task.spawn(function()
		self._time=0

		local accumulator=0

		while self._running do
			while self._running and self._paused do
				task.wait()
			end
			if not self._running then break end

			local dt=task.wait()
			accumulator+=dt

			while accumulator>=self._scale do
				accumulator-=self._scale

				self.Signals.Tick:Fire(self._time)
				self._time+=self._scale

				if self._time>=seconds then
					self._running=false
					break
				end
			end
		end

		if self._time>=seconds then
			self.Signals.Finished:Fire()
		end

		self._thread=nil
	end)

	return self
end

--- Sets how many real seconds equal one tick. Defaults to `1`. Must be > 0.
--- @param n number Seconds per tick.
--- @return TimerService
function service:SetTimeScale(n:number):TimerService
	assert(n>0,"TimerService: scale must be greater than 0")
	self._scale=n
	return self
end

--- Pauses the timer. Fires `Signals.Paused`.
--- @return TimerService
function service:Pause():TimerService
	if not self._running or self._paused then return self end
	self._paused=true
	self.Signals.Paused:Fire()
	return self
end

--- Resumes a paused timer. Fires `Signals.Resumed`.
--- @return TimerService
function service:Resume():TimerService
	if not self._paused then return self end
	self._paused=false
	self.Signals.Resumed:Fire()
	return self
end

--- Stops the timer immediately. Fires `Signals.Stopped`.
--- Unlike `Cleanup`, signals are preserved and the instance can be reused.
--- @return TimerService
function service:Stop():TimerService
	if not self._running then return self end

	self._running=false
	self._paused=false

	if self._thread then
		task.cancel(self._thread)
		self._thread=nil
	end

	self.Signals.Stopped:Fire()
	return self
end

--- Stops the timer, fires `Signals.Cleanup`, then disconnects all signal listeners.
--- After this call the instance should be discarded.
function service:Cleanup()
	self._running=false
	self._paused=false

	if self._thread then
		task.cancel(self._thread)
		self._thread=nil
	end

	self.Signals.Cleanup:Fire()

	for _,sig in self.Signals::{[string]:any} do
		sig:DisconnectAll()
	end
end

return service
--!strict

--------------------------------------------------------------------------------
-- AnimationService.luau
-- A reuseable animation controller
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

-- >> CONSTRUCTOR << ---------------------------------------------------------------

type GroupContents={number}

type Group={
	__index: Group,
	_contents: GroupContents,
	_default_speed: number,
	_current_speed: number,
	playing: boolean,
	paused: boolean,
	add: (self: Group, id: number) -> (),
	remove: (self: Group, id: number) -> (),
	get_state: (self: Group) -> (boolean, boolean),
}

type TrackMap={[number]: AnimationTrack}
type GroupMap={[string]: Group}

type Service={
	__index: Service,
	_groups: GroupMap,
	_tracks: TrackMap,
	Instance: Animator,

	new: (animator: Animator) -> Service,

	create_group:    (self: Service, name: string) -> Group,
	play_group:      (self: Service, name: string) -> (),
	pause_group:     (self: Service, name: string) -> (),
	resume_group:    (self: Service, name: string) -> (),
	set_group_speed: (self: Service, name: string, speed: number, _mock: boolean?) -> (),
	destroy_group:   (self: Service, name: string) -> (),

	play:         (self: Service, id: number, speed: number?, events: {[string]: () -> ()}?) -> (),
	adjust_speed: (self: Service, id: number, speed: number, mock: boolean?) -> (),
	pause:        (self: Service, id: number) -> (),
	resume:       (self: Service, id: number) -> (),
	stop:         (self: Service, id: number) -> (),

	is_playing:  (self: Service, id: number, exclude_pause: boolean?) -> boolean,
	get_time:    (self: Service, id: number) -> number,
	get_lenght:  (self: Service, id: number) -> number,
	get_speed:   (self: Service, id: number) -> number,
	get_weight:  (self: Service, id: number) -> number,

	destroy: (self: Service) -> (),
}

-- body

local service={} :: Service
service.__index=service

-- variables

local freeze=table.freeze
local insert=table.insert
local remove=table.remove
local find=table.find

local safe=pcall

-- setup

function service.new(animator: Animator): Service
	local self=setmetatable({},service) :: Service
	self._groups={} :: GroupMap
	self._tracks={} :: TrackMap

	self.Instance=animator :: Animator

	return self
end

-- >> GROUPS << ---------------------------------------------------------------

local function validate_number(n: unknown): ()
	assert(typeof(n)=='number',`[AnimationService]: Given group id is not a number!`)
	assert((n :: number)>0,`[AnimationService]: Given id is not positive!`)
end

local function validate_name(name: string, groups: GroupMap, is_creating: boolean?): ()
	if is_creating then
		assert(typeof(name)=='string',`[AnimationService] create_group: expected string, got {typeof(name)}`)
		assert(not groups[name],`[AnimationService] create_group: group "{name}" already exists`)
	else
		assert(groups[name],`[AnimationService]: group "{name}" does not exist`)
	end
end

local function validate_group(groups: GroupMap, name: string): ()
	assert(groups[name],`[AnimationService]: group "{name}" does not exist`)
end

local function is_sanitized(id: string | number): boolean
	return typeof(id)=='string' and (id :: string):find('^rbxassetid://')~=nil
end

local function sanitize_id(id: number): string
	validate_number(id)
	return `rbxassetid://{id}`
end

local function unsanitize_id(asset_id: string): number?
	return tonumber(asset_id:gsub('rbxassetid://',''))
end

function service.create_group(self: Service, name: string): Group
	validate_name(name,self._groups,true)

	local group={} :: Group
	group.__index=group
	group._contents={} :: GroupContents
	group._default_speed=1
	group._current_speed=1

	group.playing=false
	group.paused=false

	function group:add(id: number): ()
		validate_number(id)
		insert(group._contents,id)
	end

	function group:remove(id: number): ()
		validate_number(id)
		remove(group._contents,find(group._contents,id))
	end

	function group:get_state(): (boolean, boolean)
		return group.playing,group.paused
	end

	self._groups[name]=setmetatable({},group) :: Group
	return self._groups[name]
end

function service.play_group(self: Service, name: string): ()
	validate_name(name,self._groups)

	local group: Group=self._groups[name] do

		local animator: Animator=self.Instance

		for _,id: number in group._contents do
			self:play(id,group._default_speed)
		end
	end
end

function service.pause_group(self: Service, name: string): ()
	validate_name(name,self._groups)
	self:set_group_speed(name,0,true)
end

function service.resume_group(self: Service, name: string): ()
	validate_name(name,self._groups)
	self:set_group_speed(name,self._groups[name]._default_speed,true)
end

function service.set_group_speed(self: Service, name: string, speed: number, _mock: boolean?): ()
	validate_name(name,self._groups)

	local group: Group=self._groups[name] do
		for _,id: number in group._contents do
			local track: AnimationTrack=self._tracks[id] do
				if not track then
					continue
				end
				self:adjust_speed(id,speed,_mock)
			end
		end
	end

	if _mock then
		group._current_speed=speed
		return
	end

	group._default_speed=speed
	group._current_speed=speed
end

function service.destroy_group(self: Service, name: string): ()
	validate_name(name,self._groups)

	local group: Group=self._groups[name] do
		for id: number,track: AnimationTrack in self._tracks do
			if find(group._contents,id) then
				self:stop(id)
			end
		end
	end

	self._groups[name]=nil :: any
end

-- >> PLAYBACK << ---------------------------------------------------------------

function service.play(self: Service, id: number, speed: number?, events: {[string]: () -> ()}?): ()
	validate_number(id)
	
	if self._tracks[id] then
		self:stop(id)
	end

	local animator: Animator=self.Instance
	local animation: Animation=Instance.new('Animation')
	animation.AnimationId=sanitize_id(id)

	speed=speed or 1

	local track: AnimationTrack=animator:LoadAnimation(animation) do
		track:Play()
		track:AdjustSpeed(speed::number)

		track:SetAttribute('default_speed',speed)
		track:SetAttribute('current_speed',speed)
	end

	self._tracks[id]=track
end

function service.adjust_speed(self: Service, id: number, speed: number, mock: boolean?): ()
	validate_number(id)

	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return
		end

		track:AdjustSpeed(speed)

		if mock then
			track:SetAttribute('current_speed',speed)
			return
		end

		track:SetAttribute('current_speed',speed)
		track:SetAttribute('default_speed',speed)
	end
end

function service.pause(self: Service, id: number): ()
	validate_number(id) do
		self:adjust_speed(id,0,true)
	end
end

function service.resume(self: Service, id: number): ()
	validate_number(id) do
		self:adjust_speed(id,self._tracks[id]:GetAttribute('default_speed') :: number)
	end
end

function service.stop(self: Service, id: number): ()
	validate_number(id) do
		local track: AnimationTrack=self._tracks[id] do
			if not track then
				return
			end

			safe(function(): ()
				track:Stop()
			end)

			self._tracks[id]=nil::any
		end
	end
end

-- >> Queries << ---------------------------------------------------------------

function service.is_playing(self: Service, id: number, exclude_pause: boolean?): boolean
	validate_number(id)

	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return false
		end

		return (exclude_pause and track.Speed~=0 and true) or not exclude_pause and true
	end
end

function service.get_time(self: Service, id: number): number
	validate_number(id)

	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return 0
		end
		return track.TimePosition
	end
end

function service.get_lenght(self: Service, id: number): number
	validate_number(id)

	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return 0
		end
		return track.Length
	end
end

function service.get_speed(self: Service, id: number): number
	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return 0
		end
		return track.Speed
	end
end

function service.get_weight(self: Service, id: number): number
	local track: AnimationTrack=self._tracks[id] do
		if not track then
			return 0
		end
		return track.WeightCurrent
	end
end

-- >> Misc << ---------------------------------------------------------------

function service.destroy(self: Service): ()
	for name: string,_: Group in self._groups do
		self:destroy_group(name)
	end

	local ids:{number}={}
	for id: number in self._tracks do
		insert(ids,id)
	end
	for _,id: number in ids do
		self:stop(id)
	end
end

return table.freeze(service)
--!strict
--------------------------------------------------------------------------------
-- AudioService.luau
-- A simple, flexible audio controller for Roblox games.
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
local RobloxSoundService=game:GetService('SoundService')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')

type TrackList={Sound}
type PlayOptions={
	SFX: Sound,
	Looped: boolean?,
	Volume: number?,
	delay: number?,
	Target: any?,
}

type Service={
	__index: Service,
	_tracks: TrackList,

	new: () -> Service,

	play:       (self: Service, options: PlayOptions, use_service: boolean?) -> Sound?,
	play_once:  (self: Service, options: PlayOptions) -> (),
	pause:      (self: Service, sfx: Sound) -> (),
	resume:     (self: Service, sfx: Sound) -> (),
	stop:       (self: Service, sfx: Sound) -> (),
	stop_all:   (self: Service) -> (),

	is_playing:       (self: Service, sfx: Sound) -> boolean,
	is_paused:        (self: Service, sfx: Sound) -> boolean,
	get_active_tracks:(self: Service) -> TrackList,
}

local service={} :: Service
service.__index=service

local freeze=table.freeze
local insert=table.insert
local remove=table.remove
local clear=table.clear
local clone=table.clone
local find=table.find

local function validate_sfx(sfx: unknown): ()
	assert(typeof(sfx)=='Instance' and (sfx :: Instance):IsA('Sound'),`[AudioService]: expected Sound, got {typeof(sfx)}`)
end

local function validate_options(options: unknown): ()
	assert(typeof(options)=='table',`[AudioService]: options must be a table, got {typeof(options)}`)
	validate_sfx((options :: PlayOptions).SFX)
end

function service.new(): Service
	local self=setmetatable({},service) :: Service
	self._tracks={} :: TrackList
	return self
end

-- >> PLAYBACK << ---------------------------------------------------------------

function service.play(self: Service, options: PlayOptions, use_service: boolean?): Sound?
	validate_options(options)

	if use_service then
		RobloxSoundService:PlayLocalSound(options.SFX)
		print('Playing!')
		return nil
	end

	local tracks: TrackList=self._tracks
	local new: Sound=options.SFX:Clone()
	new.Parent=RunService:IsClient() and options.Target or workspace
	new.Looped=options.Looped or false
	new.Volume=options.Volume or .5

	new:Play()
	insert(tracks,new)
	
	if options.Looped then
		new.Ended:Once(function()
			if options.delay~=nil then
				task.wait(options.delay)
			end
			
			new:Destroy()
			remove(tracks,find(tracks,new))
		end)
	end; return new
end

function service.play_once(self: Service, options: PlayOptions): ()
	validate_options(options)

	local new: Sound=options.SFX:Clone()
	new.Parent=RunService:IsClient() and options.Target or workspace
	new.Looped=false
	new.Volume=options.Volume or .5

	new:Play()
	new.Ended:Connect(function()
		if options.delay~=nil then
			task.wait(options.delay)
		end
		new:Destroy()
	end)
end

function service.pause(self: Service, sfx: Sound): ()
	validate_sfx(sfx)
	sfx:Pause()
end

function service.resume(self: Service, sfx: Sound): ()
	validate_sfx(sfx)
	sfx:Resume()
end

function service.stop(self: Service, sfx: Sound): ()
	validate_sfx(sfx)
	
	sfx:Destroy()
	remove(self._tracks,find(self._tracks,sfx))
end

function service.stop_all(self: Service): ()
	for _,track: Sound in self._tracks do
		track:Destroy()
	end
	clear(self._tracks)
end

-- >> QUERIES << ---------------------------------------------------------------

function service.is_playing(self: Service, sfx: Sound): boolean
	validate_sfx(sfx)
	return sfx.IsPlaying
end

function service.is_paused(self: Service, sfx: Sound): boolean
	validate_sfx(sfx)
	return not sfx.IsPlaying and sfx.TimePosition>0
end

function service.get_active_tracks(self: Service): TrackList
	return clone(self._tracks)
end

return freeze(service)

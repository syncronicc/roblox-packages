--!strict
--------------------------------------------------------------------------------
-- StateMachine.luau
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

-- >> TYPES << ---------------------------------------------------------------
export type StateObject={
	Startup:(self:StateObject)->(),
	Entered:(self:StateObject)->(),
	Exited:(self:StateObject)->(),
}
export type StateMap=	{[string]:StateObject}
export type TransitionRule=	(...any)->boolean
export type Transition={
	from:string;
	destination:string;
	condition:TransitionRule;
}
export type TransitionMap=	{[string]:Transition}
export type StateMachineObject={
	CurrentState:string;
	States:StateMap;
	_transitions:TransitionMap;
	ChangeState:(self:StateMachineObject,state:string)->();
	GetState:(self:StateMachineObject)->string;
	AddTransition:(self:StateMachineObject,id:string?,base_state:string,next_state:string,rule:TransitionRule)->();
	RemoveTransition:(self:StateMachineObject,id:string)->();
	Update:(self:StateMachineObject,...any)->boolean?;
	LoadDirectory:(directory:Folder)->StateMap;
}

-- >> CONSTRUCTOR << ---------------------------------------------------------------
local HttpService=game:GetService('HttpService')
local StateMachine={}
StateMachine.__index=StateMachine

local INVALID_DIRECTORY=`[StateMachine]: The given directory is not a folder!`
local INVALID_METHODS=`[StateMachine]: The required state module has no %s method!`

local freeze=table.freeze
local safe=pcall

function StateMachine.new(states:StateMap,default:string):StateMachineObject
	local self=setmetatable({},StateMachine)do
		self.CurrentState=default
		self.States=states
		self._transitions={}

		for _,state in states do
			local ok,err=safe(function()
				state:Startup()
			end)
			if not ok then
				warn(`[StateMachine]: Startup failed — {err}`)
			end
		end

		if states[default]then
			states[default]:Entered()
		end

	end; return self :: StateMachineObject
end

-- >> METHODS << ---------------------------------------------------------------
function StateMachine.ChangeState(self:StateMachineObject,state:string)
	if self.States[self.CurrentState]then
		self.States[self.CurrentState]:Exited()
	end

	if not self.States[state]then
		return
	end

	self.CurrentState=state
	self.States[state]:Entered()
end

function StateMachine.GetState(self:StateMachineObject):string
	return self.CurrentState
end

-- >> TRANSITIONS << ---------------------------------------------------------------

function StateMachine.AddTransition(self:StateMachineObject,id:string?,base_state:string,next_state:string,rule:TransitionRule)
	self._transitions[id or HttpService:GenerateGUID(false)]={
		from=base_state;
		destination=next_state;
		condition=rule;
	}
end

function StateMachine.RemoveTransition(self:StateMachineObject,id:string)
	if id then
		self._transitions[id]=nil
	end
end

function StateMachine.Update(self:StateMachineObject,...:any):boolean?
	for _,tr in self._transitions do
		if self.CurrentState==tr.from and tr.condition(...)then
			self:ChangeState(tr.destination)
			return true
		end
	end
	return nil
end

-- >> MISC << ---------------------------------------------------------------
function StateMachine.LoadDirectory(directory:Folder):StateMap
	assert(directory~=nil and typeof(directory)=='Instance'and directory:IsA('Folder'),INVALID_DIRECTORY)

	local required:StateMap={}

	for _,module in directory:GetChildren()do
		if not module:IsA('ModuleScript')then
			continue
		end
		
		local rq_module=require(module)do
			if typeof(rq_module['Entered'])~='function'then
				warn(INVALID_METHODS:format(":Entered"))
				continue
			end
			if typeof(rq_module['Exited'])~='function'then
				warn(INVALID_METHODS:format(":Exited"))
				continue
			end
			if typeof(rq_module['Startup'])~='function'then
				warn(INVALID_METHODS:format(":Startup"))
				continue
			end
		end; 
		
		required[module.Name]=rq_module :: StateObject
	end; return required
end

return freeze(StateMachine)

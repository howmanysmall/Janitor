-- Janitor
-- Original by Validark
-- Modifications by pobammer
-- roblox-ts support by OverHash and Validark
-- LinkToInstance fixed by Elttob.

local GetPromiseLibrary = require(script.GetPromiseLibrary)
local Symbol = require(script.Symbol)
local FoundPromiseLibrary, Promise = GetPromiseLibrary()

local IndicesReference = Symbol("IndicesReference")
local LinkToInstanceIndex = Symbol("LinkToInstanceIndex")

local METHOD_NOT_FOUND_ERROR = "Object %s doesn't have method %s, are you sure you want to add it? Traceback: %s"
local NOT_A_PROMISE = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %s (%s))"

--[=[
	Janitor is a light-weight, flexible object for cleaning up connections, instances, or anything. This implementation covers all use cases,
	as it doesn't force you to rely on naive typechecking to guess how an instance should be cleaned up.
	Instead, the developer may specify any behavior for any object.

	@class Janitor
	@__index {}
]=]
local Janitor = {}
Janitor.ClassName = "Janitor"
Janitor.__index = {}

Janitor.__index.CurrentlyCleaning = true
Janitor.__index[IndicesReference] = nil

local TypeDefaults = {
	["function"] = true;
	RBXScriptConnection = "Disconnect";
}

--[=[
	Determines if the passed object is a Janitor. This checks the metatable directly.

	@param Object any The object you are checking.
	@return boolean -- `true` iff `Object` is a Janitor.
]=]
function Janitor.Is(Object: any): boolean
	return type(Object) == "table" and getmetatable(Object) == Janitor
end

type StringOrTrue = string | boolean

--[=[
	Adds an `Object` to Janitor for later cleanup, where `MethodName` is the key of the method within `Object` which should be called at cleanup time.
	If the `MethodName` is `true` the `Object` itself will be called instead. If passed an index it will occupy a namespace which can be `Remove()`d or overwritten.
	Returns the `Object`.

	:::info
	Objects not given an explicit `MethodName` will be passed into the `typeof` function for a very naive typecheck. RBXConnections will be assigned to "Disconnect", functions will be assigned to `true`, and everything else will default to "Destroy". Not recommended, but hey, you do you.
	:::

	```Lua
	local Obliterator = Janitor.new()

	-- Queue the Part to be Destroyed at Cleanup time
	Obliterator:Add(workspace.Part, "Destroy")

	-- Queue function to be called with `true` MethodName
	Obliterator:Add(print, true)

	-- This implementation allows you to specify behavior for any object
	Obliterator:Add(Tween.new(0.5, 0, print), "Stop")

	-- By passing an Index, the Object will occupy a namespace
	-- If "CurrentTween" already exists, it will call :Remove("CurrentTween") before writing
	Obliterator:Add(Tween.new(0.5, 0, print), "Stop", "CurrentTween")
	```

	@param Object T -- The object you want to clean up.
	@param MethodName? string|true -- The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
	@param Index? any -- The index that can be used to clean up the object manually.
	@return T -- The object that was passed as the first argument.
]=]
function Janitor.__index:Add(Object: any, MethodName: StringOrTrue?, Index: any?): any
	if Index then
		self:Remove(Index)

		local This = self[IndicesReference]
		if not This then
			This = {}
			self[IndicesReference] = This
		end

		This[Index] = Object
	end

	MethodName = MethodName or TypeDefaults[typeof(Object)] or "Destroy"
	if type(Object) ~= "function" and not Object[MethodName] then
		warn(string.format(METHOD_NOT_FOUND_ERROR, tostring(Object), tostring(MethodName), debug.traceback(nil :: any, 2)))
	end

	self[Object] = MethodName
	return Object
end

-- My version of Promise has PascalCase, but I converted it to use lowerCamelCase for this release since obviously that's important to do.

--[=[
	Adds a [Promise](https://github.com/evaera/roblox-lua-promise) to the Janitor. If the Janitor is cleaned up and the Promise is not completed, the Promise will be cancelled.

	```Lua
	local Obliterator = Janitor.new()
	Obliterator:AddPromise(Promise.delay(3)):andThenCall(print, "Finished!"):catch(warn)
	task.wait(1)
	Obliterator:Cleanup() -- The above Promise should warn.
	```

	@param PromiseObject Promise -- The promise you want to add to the Janitor.
	@return Promise
]=]
function Janitor.__index:AddPromise(PromiseObject)
	if FoundPromiseLibrary then
		if not Promise.is(PromiseObject) then
			error(string.format(NOT_A_PROMISE, typeof(PromiseObject), tostring(PromiseObject)))
		end

		if PromiseObject:getStatus() == Promise.Status.Started then
			local Id = newproxy(false)
			local NewPromise = self:Add(Promise.resolve(PromiseObject), "cancel", Id)
			NewPromise:finallyCall(self.Remove, self, Id)
			return NewPromise
		else
			return PromiseObject
		end
	else
		return PromiseObject
	end
end

--[=[
	Cleans up whatever `Object` was set to this namespace by the 3rd parameter of [[Janitor.Add]].

	```lua
	local Obliterator = Janitor.new()
	Obliterator:Add(workspace.Baseplate, "Destroy", "Baseplate")
	Obliterator:Remove("Baseplate")
	```

	@param Index any -- The index you want to remove.
	@return Janitor
]=]
function Janitor.__index:Remove(Index: any): Janitor
	local This = self[IndicesReference]

	if This then
		local Object = This[Index]

		if Object then
			local MethodName = self[Object]

			if MethodName then
				if MethodName == true then
					Object()
				else
					local ObjectMethod = Object[MethodName]
					if ObjectMethod then
						ObjectMethod(Object)
					end
				end

				self[Object] = nil
			end

			This[Index] = nil
		end
	end

	return self
end

--[=[
	Gets whatever object is stored with the given index, if it exists. This was added since Maid allows getting the task using `__index`.

	```lua
	local Obliterator = Janitor.new()
	Obliterator:Add(workspace.Baseplate, "Destroy", "Baseplate")
	print(Obliterator:Get("Baseplate"))
	```

	@param Index any -- The index that the object is stored under.
	@return any? -- This will return the object if it is found, but it won't return anything if it doesn't exist.
]=]
function Janitor.__index:Get(Index: any): any?
	local This = self[IndicesReference]
	if This then
		return This[Index]
	else
		return nil
	end
end

--[=[
	Calls each Object's `MethodName` (or calls the Object if `MethodName == true`) and removes them from the Janitor. Also clears the namespace.
	This function is also called when you call a Janitor Object (so it can be used as a destructor callback).

	```lua
	Obliterator:Cleanup()
	Obliterator()
	```
]=]
function Janitor.__index:Cleanup()
	if not self.CurrentlyCleaning then
		self.CurrentlyCleaning = nil
		for Object, MethodName in pairs(self) do
			if Object == IndicesReference then
				continue
			end

			if MethodName == true then
				Object()
			else
				local ObjectMethod = Object[MethodName]
				if ObjectMethod then
					ObjectMethod(Object)
				end
			end

			self[Object] = nil
		end

		local This = self[IndicesReference]
		if This then
			table.clear(This)
			self[IndicesReference] = {}
		end

		self.CurrentlyCleaning = false
	end
end

--[=[
	Calls [[Janitor.Cleanup]] and renders the Janitor unusable.

	:::warning
	Running this will make any attempts to call a function of Janitor error.
	:::
]=]
function Janitor.__index:Destroy()
	self:Cleanup()
	table.clear(self)
	setmetatable(self, nil)
end

Janitor.__call = Janitor.__index.Cleanup

--- Makes the Janitor clean up when the instance is destroyed
-- @param Instance Instance The Instance the Janitor will wait for to be Destroyed
-- @returns Disconnectable table to stop Janitor from being cleaned up upon Instance Destroy (automatically cleaned up by Janitor, btw)
-- @author Corecii
local Disconnect = {}
Disconnect.Connected = true
Disconnect.__index = Disconnect

function Disconnect:Disconnect()
	if self.Connected then
		self.Connected = false
		self.Connection:Disconnect()
	end
end

function Disconnect._new(RBXScriptConnection: RBXScriptConnection)
	return setmetatable({
		Connection = RBXScriptConnection;
	}, Disconnect)
end

function Disconnect:__tostring()
	return "Disconnect<" .. tostring(self.Connected) .. ">"
end

type RbxScriptConnection = typeof(Disconnect._new(game:GetPropertyChangedSignal("ClassName"):Connect(function() end)))

--[=[
	"Links" this Janitor to an Instance, such that the Janitor will `Cleanup` when the Instance is `Destroyed()` and garbage collected.
	A Janitor may only be linked to one instance at a time, unless `AllowMultiple` is true. When called with a truthy `AllowMultiple` parameter,
	the Janitor will "link" the Instance without overwriting any previous links, and will also not be overwritable.
	When called with a falsy `AllowMultiple` parameter, the Janitor will overwrite the previous link which was also called with a falsy `AllowMultiple` parameter, if applicable.

	```lua
	local Obliterator = Janitor.new()

	Obliterator:Add(function()
		print("Cleaning up!")
	end, true)

	do
		local Folder = Instance.new("Folder")
		Obliterator:LinkToInstance(Folder)
		Folder:Destroy()
	end

	-- Cleaning up!
	```

	@param Object Instance -- The instance you want to link the Janitor to.
	@param AllowMultiple boolean? -- Whether or not to allow multiple links on the same Janitor.
	@return RbxScriptConnection -- A pseudo RBXScriptConnection that can be disconnected to prevent the cleanup of LinkToInstance.
]=]
function Janitor.__index:LinkToInstance(Object: Instance, AllowMultiple: boolean?): RbxScriptConnection
	local Connection
	local IndexToUse = AllowMultiple and newproxy(false) or LinkToInstanceIndex
	local IsNilParented = Object.Parent == nil
	local ManualDisconnect = setmetatable({}, Disconnect)

	local function ChangedFunction(_DoNotUse, NewParent)
		if ManualDisconnect.Connected then
			_DoNotUse = nil
			IsNilParented = NewParent == nil

			if IsNilParented then
				task.defer(function()
					if not ManualDisconnect.Connected then
						return
					elseif not Connection.Connected then
						self:Cleanup()
					else
						while IsNilParented and Connection.Connected and ManualDisconnect.Connected do
							task.wait(0)
						end

						if ManualDisconnect.Connected and IsNilParented then
							self:Cleanup()
						end
					end
				end)
			end
		end
	end

	Connection = Object.AncestryChanged:Connect(ChangedFunction)
	ManualDisconnect.Connection = Connection

	if IsNilParented then
		ChangedFunction(nil, Object.Parent)
	end

	Object = nil :: any
	return self:Add(ManualDisconnect, "Disconnect", IndexToUse)
end

--[=[
	Links several instances to a new Janitor, which is then returned.

	@param ...Instance -- All the Instances you want linked.
	@return Janitor -- A new Janitor that can be used to manually disconnect all LinkToInstances.
]=]
function Janitor.__index:LinkToInstances(...: Instance): Janitor
	local ManualCleanup = Janitor.new()
	for _, Object in ipairs({...}) do
		ManualCleanup:Add(self:LinkToInstance(Object, true), "Disconnect")
	end

	return ManualCleanup
end

--[=[
	Instantiates a new Janitor object.

	@return Janitor
]=]
function Janitor.new()
	return setmetatable({
		CurrentlyCleaning = false;
		[IndicesReference] = nil;
	}, Janitor)
end

export type Janitor = typeof(Janitor.new())
return Janitor

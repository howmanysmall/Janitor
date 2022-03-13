--[=[
	A wrapper for an `RBXScriptConnection`. Makes the Janitor clean up when the instance is destroyed. This was created by Corecii.

	@class RbxScriptConnection
]=]
local RbxScriptConnection = {}
RbxScriptConnection.Connected = true
RbxScriptConnection.__index = RbxScriptConnection

--[=[
	@prop Connected boolean
	@within RbxScriptConnection

	Whether or not this connection is still connected.
]=]

--[=[
	Disconnects the Signal.
]=]
function RbxScriptConnection:Disconnect()
	if self.Connected then
		self.Connected = false
		self.Connection:Disconnect()
	end
end

function RbxScriptConnection._new(RBXScriptConnection: RBXScriptConnection)
	return setmetatable({
		Connection = RBXScriptConnection;
	}, RbxScriptConnection)
end

function RbxScriptConnection:__tostring()
	return "RbxScriptConnection<" .. tostring(self.Connected) .. ">"
end

export type RbxScriptConnection = typeof(RbxScriptConnection._new(game:GetPropertyChangedSignal("ClassName"):Connect(function() end)))
return RbxScriptConnection

--!native

-- duster
-- fast and lightweight maid impl ( thats also better than janitor )

type Types = "table" | "function" | "thread" | "Instance" | "RBXScriptConnection"

type TableCleanupMethod = <V>(self: (V & {})) -> ()

export type Cleanable =
	| { Disconnect: TableCleanupMethod }
	| { disconnect: TableCleanupMethod }
	| { Cleanup: TableCleanupMethod }
	| { destroy: TableCleanupMethod }
	| { Destroy: TableCleanupMethod }
	| { cleanup: TableCleanupMethod }
	| { Cleanup: TableCleanupMethod }
	| { clear: TableCleanupMethod }
	| { Clear: TableCleanupMethod }
	| RBXScriptConnection
	| Instance 
	| () -> ()
	| thread

local DISCONNECT = (function()
	local conn = script.Changed:Connect(function() end)
	local disconnect = conn.Disconnect
	disconnect(conn)
	return disconnect
end)()
local TYPEOF = typeof :: <V>(value: V) -> Types
local DESTROY = game.Destroy
local REMOVE = table.remove
local INSERT = table.insert
local CANCEL = task.cancel
local CLEAR = table.clear
local FIND = table.find

local duster = {}

-- have to keep the generic, as otherwise typechecker WILL kick and scream
function duster.clearval<V>(duster: { Cleanable }, value: V & Cleanable)
	local index = FIND(duster, (value :: any))

	if index then
		local type = TYPEOF(value)

		if type == "function" then
			(value :: any)()
		elseif type == "thread" then
			CANCEL((value :: any))
		elseif type == "table" then
			local disconnect1 = (value :: any).Disconnect
	
			if disconnect1 then
				disconnect1(value)
				return
			end

			local disconnect = (value :: any).disconnect
	
			if disconnect then
				disconnect(value)
				return
			end

			local destroy = (value :: any).destroy
	
			if destroy then
				destroy(value)
				return
			end
			local clear = (value :: any).clear
	
			if clear then
				clear(value)
				return
			end
			local clean = (value :: any).cleanup
	
			if clean then
				clean(value)
				return
			end
			local destroy2 = (value :: any).Destroy
	
			if destroy2 then
				destroy2(value)
				return
			end
			local clear2 = (value :: any).Clear

			if clear2 then
				clear2(value)
				return
			end
			local clean2 = (value :: any).Cleanup
	
			if clean2 then
				clean2(value)
			end
		elseif type == "Instance" then
			DESTROY((value :: any))
		elseif type == "RBXScriptConnection" then
			DISCONNECT((value :: any))
		end
		REMOVE(duster, index)
	end
end

function duster.cleari(duster: { Cleanable }, index: number)
	local value = duster[index]

	if value then
		local type = TYPEOF(value)

		if type == "function" then
			(value :: any)()
		elseif type == "thread" then
			CANCEL((value :: any))
		elseif type == "table" then
			local disconnect1 = (value :: any).Disconnect
	
			if disconnect1 then
				disconnect1(value)
				return
			end

			local disconnect = (value :: any).disconnect
	
			if disconnect then
				disconnect(value)
				return
			end

			local destroy = (value :: any).destroy
	
			if destroy then
				destroy(value)
				return
			end
			local clear = (value :: any).clear
	
			if clear then
				clear(value)
				return
			end
			local clean = (value :: any).cleanup
	
			if clean then
				clean(value)
				return
			end
			local destroy2 = (value :: any).Destroy
	
			if destroy2 then
				destroy2(value)
				return
			end
			local clear2 = (value :: any).Clear

			if clear2 then
				clear2(value)
				return
			end
			local clean2 = (value :: any).Cleanup
	
			if clean2 then
				clean2(value)
			end
		elseif type == "Instance" then
			DESTROY((value :: any))
		elseif type == "RBXScriptConnection" then
			DISCONNECT((value :: any))
		end
		REMOVE(duster, index)
	end
end

function duster.clear(duster: { Cleanable })
	for _, value in duster do
		local type = TYPEOF(value)

		if type == "function" then
			(value :: any)()
		elseif type == "thread" then
			CANCEL((value :: any))
		elseif type == "table" then
			local disconnect1 = (value :: any).Disconnect
	
			if disconnect1 then
				disconnect1(value)
				continue
			end

			local disconnect = (value :: any).disconnect
	
			if disconnect then
				disconnect(value)
				continue
			end

			local destroy = (value :: any).destroy
	
			if destroy then
				destroy(value)
				continue
			end
			local clear = (value :: any).clear
	
			if clear then
				clear(value)
				continue
			end
			local clean = (value :: any).cleanup
	
			if clean then
				clean(value)
				continue
			end
			local destroy2 = (value :: any).Destroy
	
			if destroy2 then
				destroy2(value)
				continue
			end
			local clear2 = (value :: any).Clear

			if clear2 then
				clear2(value)
				continue
			end
			local clean2 = (value :: any).Cleanup
	
			if clean2 then
				clean2(value)
			end
		elseif type == "Instance" then
			DESTROY((value :: any))
		elseif type == "RBXScriptConnection" then
			DISCONNECT((value :: any))
		end
	end
	CLEAR(duster)
end

function duster.insert<V>(
	duster: { Cleanable }, 
	value: V & Cleanable, 
	cleaner: (((self: V) -> ()) | () -> ())?
): V
	if cleaner then
		INSERT(duster, function()
			(cleaner :: any)(value)
		end)
	else
		INSERT(duster, value :: any)
	end
	return value
end

return table.freeze(duster)
--!strict
--!optimize 2

--[=[
	@name Scythe

	@desc A data-oriented cleanup library for Luau.

	Unlike Janitor/Maid/Trove, Scythe has no objects, no metatables and no
	per-instance allocation cost. A scope is just an integer handle into
	module-level Structure-of-Arrays storage:

	    scopeItems : { {unknown} }  -- payloads, one array per scope
	    scopeTags  : { buffer }     -- u8 disposal tag per item
	    scopeLens  : buffer         -- u32 live item count per scope
	    scopeCaps  : buffer         -- u32 tag-buffer capacity per scope
	    freeStack  : buffer         -- u32 recycled handle stack

	The disposal method is resolved ONCE at `add` time and stored as a u8
	tag, so the `clean` hot loop is a branch on an integer read straight
	out of a buffer - no `typeof`, no method sniffing, no pcall overhead.

	Cleanup order is LIFO (reverse insertion), matching resource
	acquisition semantics.

	@usage
	    local Scythe = require(path.to.Scythe)

	    local scope = Scythe.scope()
	    Scythe.add(scope, workspace.Part)                  -- :Destroy()
	    Scythe.add(scope, humanoid.Died:Connect(onDied))   -- :Disconnect()
	    Scythe.add(scope, task.spawn(loop))                -- task.cancel()
	    Scythe.add(scope, function() print("bye") end)     -- called

	    Scythe.clean(scope)   -- dispose everything, scope stays usable
	    Scythe.destroy(scope) -- dispose everything, recycle the handle

	@notes
	  * Disposal is NOT wrapped in pcall. A cleanup callback that throws
	    aborts the remainder of that clean - keep callbacks total.
	  * Handles are pooled. Using a handle after `destroy` is undefined
	    behaviour (it may alias a newer scope). Treat `destroy` as final.

	@version 1.0.0
	@author checcerr | fridayqx
	@license MPL-2.0
]=]

--[=[
	An opaque integer handle to a cleanup scope.

	Obtained from `Scythe.scope()`, released with `Scythe.destroy()`.
	It is a plain number - cheap to store, pass, and compare - but you
	should never do arithmetic on it or fabricate one yourself.
]=]
export type Scope = number

-- Disposal tags (u8). Resolved once at add-time, branched on at clean-time.
const TAG_CONNECTION = 1 -- RBXScriptConnection      -> :Disconnect()
const TAG_INSTANCE = 2 -- Instance                   -> :Destroy()
const TAG_FUNCTION = 3 -- function                   -> value()
const TAG_THREAD = 4 -- thread                       -> task.cancel()
const TAG_DESTROY = 5 -- table with :Destroy()       -> :Destroy()
const TAG_DISCONNECT = 6 -- table with :Disconnect() -> :Disconnect()

const INITIAL_SCOPES = 64 -- starting scope capacity (module-wide)
const INITIAL_ITEMS = 8 -- starting item capacity per scope

-- ============================== SoA storage ==============================

local scopeItems = table.create(INITIAL_SCOPES) :: { { unknown } }
local scopeTags = table.create(INITIAL_SCOPES) :: { buffer }
local scopeLens: buffer = buffer.create(INITIAL_SCOPES * 4)
local scopeCaps: buffer = buffer.create(INITIAL_SCOPES * 4)
local scopeCap = INITIAL_SCOPES
local scopeCount = 0

local freeStack: buffer = buffer.create(INITIAL_SCOPES * 4)
local freeCap = INITIAL_SCOPES
local freeLen = 0

-- Reallocate a u32 buffer to a larger element count, preserving contents.
local function growU32(b: buffer, oldCount: number, newCount: number): buffer
	local grown = buffer.create(newCount * 4)
	buffer.copy(grown, 0, b, 0, oldCount * 4)
	return grown
end

-- Dispose a single value by its precomputed tag. Small enough for the
-- compiler to inline at -O2; shared by `clean` and `remove`.
local function dispose(tag: number, value: any): ()
	if tag == TAG_CONNECTION then
		value:Disconnect()
	elseif tag == TAG_INSTANCE then
		value:Destroy()
	elseif tag == TAG_FUNCTION then
		value()
	elseif tag == TAG_THREAD then
		if coroutine.status(value) ~= "dead" then
			task.cancel(value)
		end
	elseif tag == TAG_DESTROY then
		-- selene: allow(if_same_then_else)
		value:Destroy()
	else -- TAG_DISCONNECT
		-- selene: allow(if_same_then_else)
		value:Disconnect()
	end
end

local Scythe = {}

-- ================================= API ==================================

--[=[
	Acquires a cleanup scope and returns its handle.

	Handles are pooled: destroyed scopes are recycled with their item
	arrays kept warm (capacity preserved), so `scope()` in steady state
	allocates nothing at all.

	```lua
	local scope = Scythe.scope()
	```

	@return Scope -- an opaque integer handle
]=]
function Scythe.scope(): Scope
	-- Fast path!
	if freeLen > 0 then
		freeLen -= 1
		return buffer.readu32(freeStack, freeLen * 4)
	end

	-- Slow path :(
	if scopeCount >= scopeCap then
		local newCap = scopeCap * 2
		scopeLens = growU32(scopeLens, scopeCap, newCap)
		scopeCaps = growU32(scopeCaps, scopeCap, newCap)
		scopeCap = newCap
	end

	local id = scopeCount
	scopeCount += 1

	scopeItems[id + 1] = table.create(INITIAL_ITEMS)
	scopeTags[id + 1] = buffer.create(INITIAL_ITEMS)
	buffer.writeu32(scopeLens, id * 4, 0)
	buffer.writeu32(scopeCaps, id * 4, INITIAL_ITEMS)

	return id
end

--[=[
	Adds a value to a scope and returns it unchanged, so calls can be
	inlined into expressions:

	```lua
	local part = Scythe.add(scope, Instance.new("Part"))
	local conn = Scythe.add(scope, signal:Connect(handler))
	local co   = Scythe.add(scope, task.spawn(loop))
	Scythe.add(scope, function() print("cleanup!") end)
	```

	The disposal method is resolved here, exactly once:

	| Value                       | On clean            |
	|-----------------------------|---------------------|
	| `RBXScriptConnection`       | `:Disconnect()`     |
	| `Instance`                  | `:Destroy()`        |
	| `function`                  | called              |
	| `thread`                    | `task.cancel()`     |
	| table with `Destroy`        | `:Destroy()`        |
	| table with `Disconnect`     | `:Disconnect()`     |

	Errors if the value fits none of the rows above - a silently
	un-cleanable value is a leak, and Scythe refuses to leak.

	@param scope Scope -- handle from `Scythe.scope()`
	@param value T -- the resource to track
	@return T -- `value`, passed through
]=]
@native
function Scythe.add<T>(scope: Scope, value: T): T
	local tag: number
	local kind = typeof(value)
	if kind == "RBXScriptConnection" then
		tag = TAG_CONNECTION
	elseif kind == "Instance" then
		tag = TAG_INSTANCE
	elseif kind == "function" then
		tag = TAG_FUNCTION
	elseif kind == "thread" then
		tag = TAG_THREAD
	elseif kind == "table" then
		local t = value :: any
		if t.Destroy ~= nil then
			tag = TAG_DESTROY
		elseif t.Disconnect ~= nil then
			tag = TAG_DISCONNECT
		else
			error("Scythe.add: table has no Destroy/Disconnect method", 2)
		end
	else
		error(`Scythe.add: cannot clean a value of type '{kind}'`, 2)
	end

	local slot = scope + 1
	local items = scopeItems[slot]
	local tags = scopeTags[slot]
	local len = buffer.readu32(scopeLens, scope * 4)

	local cap = buffer.readu32(scopeCaps, scope * 4)
	if len >= cap then
		local newCap = cap * 2
		local grown = buffer.create(newCap)
		buffer.copy(grown, 0, tags, 0, cap)
		scopeTags[slot] = grown
		tags = grown
		buffer.writeu32(scopeCaps, scope * 4, newCap)
	end

	items[len + 1] = value
	buffer.writeu8(tags, len, tag)
	buffer.writeu32(scopeLens, scope * 4, len + 1)

	return value
end

--[=[
	Removes ONE tracked value from a scope without disposing it, using
	swap-removal (O(1) - order of remaining items may change, which is
	fine because disposal order only matters relative to live items you
	still control).

	Use this when ownership of a resource is transferred elsewhere:

	```lua
	local conn = Scythe.add(scope, signal:Connect(fn))
	-- ... later, someone else takes over the connection:
	Scythe.remove(scope, conn)
	```

	@param scope Scope -- handle from `Scythe.scope()`
	@param value unknown -- the exact value previously passed to `add`
	@return boolean -- true if found and removed, false otherwise
]=]
function Scythe.remove(scope: Scope, value: unknown): boolean
	local slot = scope + 1
	local items = scopeItems[slot]
	local tags = scopeTags[slot]
	local len = buffer.readu32(scopeLens, scope * 4)

	for i = len, 1, -1 do
		if items[i] == value then
			-- O(1) go brrr
			items[i] = items[len]
			items[len] = nil
			buffer.writeu8(tags, i - 1, buffer.readu8(tags, len - 1))
			buffer.writeu32(scopeLens, scope * 4, len - 1)
			return true
		end
	end

	return false
end

--[=[
	Disposes every tracked value in LIFO order (reverse of insertion) and
	empties the scope. The scope handle REMAINS VALID and can be reused
	immediately - its internal capacity is kept warm, so a clean/add
	cycle in steady state performs zero allocations.

	```lua
	Scythe.clean(scope) -- everything disposed, scope still usable
	```

	Disposal is not pcall-wrapped: if a cleanup function throws, the
	error propagates and remaining items in THIS clean are skipped.

	@param scope Scope -- handle from `Scythe.scope()`
]=]
@native
function Scythe.clean(scope: Scope): ()
	local slot = scope + 1
	local items = scopeItems[slot]
	local tags = scopeTags[slot]
	local len = buffer.readu32(scopeLens, scope * 4)

	buffer.writeu32(scopeLens, scope * 4, 0)

	for i = len, 1, -1 do
		local value = items[i]
		items[i] = nil
		dispose(buffer.readu8(tags, i - 1), value)
	end
end

--[=[
	Disposes every tracked value (exactly like `clean`), then recycles
	the handle back into the pool for a future `Scythe.scope()` call.

	```lua
	Scythe.destroy(scope)
	scope = nil :: any -- drop your reference; the handle is dead
	```

	Using the handle after `destroy` is undefined behaviour - it may
	alias a completely unrelated scope handed out later.

	@param scope Scope -- handle from `Scythe.scope()`
]=]
function Scythe.destroy(scope: Scope): ()
	Scythe.clean(scope)

	if freeLen >= freeCap then
		local newCap = freeCap * 2
		freeStack = growU32(freeStack, freeCap, newCap)
		freeCap = newCap
	end

	buffer.writeu32(freeStack, freeLen * 4, scope)
	freeLen += 1
end

--[=[
	Returns the number of values currently tracked by a scope.
	One u32 buffer read - effectively free. Useful for asserts, tests,
	and leak hunting.

	```lua
	assert(Scythe.count(scope) == 0, "scope leaked items!")
	```

	@param scope Scope -- handle from `Scythe.scope()`
	@return number -- live item count
]=]
function Scythe.count(scope: Scope): number
	return buffer.readu32(scopeLens, scope * 4)
end

table.freeze(Scythe)

return Scythe

-- checcerr.

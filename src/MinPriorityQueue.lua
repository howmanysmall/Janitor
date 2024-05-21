--!native
--!optimize 2

local MinPriorityQueue = {}
MinPriorityQueue.ClassName = "MinPriorityQueue"
MinPriorityQueue.__index = MinPriorityQueue

export type HeapEntry<T = any> = {
	Priority: number,
	Value: T,
}

local function PriorityCheck(A: number, B: number)
	return A < B
end

function MinPriorityQueue.new<T>(_: T): MinPriorityQueue<T>
	return setmetatable({
		Heap = {};
		Length = 0;
	}, MinPriorityQueue) :: any
end

--[=[
	Determines whether the passed value is a MinPriorityQueue.
	@param Value any -- The value to check.
	@return boolean -- Whether or not the passed value is a MinPriorityQueue.
]=]
function MinPriorityQueue.Is(Value: any)
	return type(Value) == "table" and getmetatable(Value) == MinPriorityQueue
end

--[=[
	Check whether the `MinPriorityQueue` has no elements.
	@return boolean -- This will be true iff the queue is empty.
]=]
function MinPriorityQueue:IsEmpty(): boolean
	return self.Length == 0
end

local function FindClosestIndex<T>(self: MinPriorityQueue<T>, Priority: number, Low: number, High: number): number
	local Middle = (Low + High) // 2

	if Middle == 0 then
		return -1
	end

	local Heap = self.Heap
	local Element: HeapEntry<T> = Heap[Middle]

	while Middle ~= High do
		local Priority2 = Element.Priority
		if Priority == Priority2 then
			return Middle
		end

		if PriorityCheck(Priority, Priority2) then
			High = Middle - 1
		else
			Low = Middle + 1
		end

		Middle = (Low + High) // 2
		Element = Heap[Middle]
	end

	return Middle
end

--[=[
	Add an element to the `MinPriorityQueue` with an associated priority.
	@error "InvalidValue" -- Thrown when the value is nil.

	@param Value T -- The value of the element.
	@param Priority number -- The priority of the element.
	@return number -- The inserted position.
]=]
function MinPriorityQueue:InsertWithPriority(Value: unknown, Priority: number): number
	if Value == nil then
		error("Argument #2 to 'MinPriorityQueue:InsertWithPriority' missing or nil", 2)
	end

	local Heap = self.Heap
	local Position = FindClosestIndex(self, Priority, 1, self.Length)
	local Element1: HeapEntry = {
		Priority = Priority;
		Value = Value;
	}

	local Element2: HeapEntry? = Heap[Position]

	if Element2 then
		Position = if PriorityCheck(Priority, Element2.Priority) then Position else Position + 1
	else
		Position = 1
	end

	table.insert(Heap, Position, Element1)
	self.Length += 1
	return Position
end

MinPriorityQueue.Insert = MinPriorityQueue.InsertWithPriority

--[=[
	Changes the priority of the given value in the `MinPriorityQueue`.
	@error "InvalidValue" -- Thrown when the value is nil.
	@error "CouldNotFind" -- Thrown when the value couldn't be found.

	@param Value T -- The value you are updating the priority of.
	@param NewPriority number -- The new priority of the value.
	@return number? -- The new position of the HeapEntry if it was found. This function will error if it couldn't find the value.
]=]
function MinPriorityQueue:ChangePriority(Value: unknown, NewPriority: number): number?
	if Value == nil then
		error("Argument #2 to 'MinPriorityQueue:ChangePriority' missing or nil", 2)
	end

	local Heap: {HeapEntry} = self.Heap
	for Index, HeapEntry in Heap do
		if HeapEntry.Value == Value then
			table.remove(Heap, Index)
			self.Length -= 1
			return self:InsertWithPriority(Value, NewPriority)
		end
	end

	error("Couldn't find value in queue?", 2)
end

--[=[
	Gets the priority of the first value in the `MinPriorityQueue`. This is the value that will be removed last.
	@return number? -- The priority of the first value.
]=]
function MinPriorityQueue:GetFirstPriority(): number?
	if self.Length == 0 then
		return nil
	end

	return self.Heap[1].Priority
end

--[=[
	Gets the priority of the last value in the `MinPriorityQueue`. This is the value that will be removed first.
	@return number? -- The priority of the last value.
]=]
function MinPriorityQueue:GetLastPriority(): number?
	local Length: number = self.Length
	if Length == 0 then
		return nil
	end

	return self.Heap[Length].Priority
end

--[=[
	Gets the value at the index.

	:::warning Performance
	If you want the maximum performance, ignore this function and index the `Heap` property directly.
	:::

	@param Index number -- The index of the value.
	@return HeapEntry<T>? -- The value located at the given index.
]=]
function MinPriorityQueue:Peek(Index: number): HeapEntry?
	return self.Heap[Index]
end

MinPriorityQueue.Get = MinPriorityQueue.Peek

--[=[
	Remove the element from the `MinPriorityQueue` that has the highest priority, and return it.
	@param OnlyValue boolean? -- Whether or not to return only the value or the entire entry.
	@return T | HeapEntry<T>? -- The removed element.
]=]
function MinPriorityQueue:PopElement(OnlyValue: boolean?): unknown | HeapEntry
	local Heap: {HeapEntry} = self.Heap
	local Length: number = self.Length
	self.Length = Length - 1

	local Element: HeapEntry = Heap[Length]
	Heap[Length] = nil
	return OnlyValue and Element.Value or Element or nil
end

MinPriorityQueue.PullHighestPriorityElement = MinPriorityQueue.PopElement
MinPriorityQueue.GetMaximumElement = MinPriorityQueue.PopElement

--[=[
	Converts the entire `MinPriorityQueue` to an array.
	@param OnlyValues boolean? -- Whether or not the array is just the values or the priorities as well.
	@return Array<T> | Array<HeapEntry<T>> -- The `MinPriorityQueue`'s array.
]=]
function MinPriorityQueue:ToArray(OnlyValues: boolean?): {unknown} | {HeapEntry}
	if OnlyValues then
		local Array = table.create(self.Length)
		for Index, HeapEntry in self.Heap do
			Array[Index] = HeapEntry.Value
		end

		return Array
	else
		return table.clone(self.Heap)
	end
end

--[=[
	Returns an iterator function for iterating over the `MinPriorityQueue`.

	:::warning Performance
	If you care about performance, do not use this function. Just do `for Index, Value in ipairs(MinPriorityQueue.Heap) do` directly.
	:::

	@param OnlyValues boolean? -- Whether or not the iterator returns just the values or the priorities as well.
	@return IteratorFunction -- The iterator function. Usage is `for Index, Value in MinPriorityQueue:Iterator(OnlyValues) do`.
]=]
function MinPriorityQueue:Iterator(OnlyValues: boolean?)
	if OnlyValues then
		local Array = table.create(self.Length)
		for Index, HeapEntry in self.Heap do
			Array[Index] = HeapEntry.Value
		end

		return ipairs(Array)
	else
		return ipairs(self.Heap)
	end
end

function MinPriorityQueue:FastIterator(OnlyValues: boolean?)
	if OnlyValues then
		local Array = table.create(self.Length)
		for Index, HeapEntry in self.Heap do
			Array[Index] = HeapEntry.Value
		end

		local Index = 0
		return function()
			Index += 1
			local Value = Array[Index]
			if Value ~= nil then
				return Index, Value
			end
		end
	else
		local Array = self.Heap
		local Index = 0
		return function()
			Index += 1
			local Value = Array[Index]
			if Value ~= nil then
				return Index, Value
			end
		end
	end
end

--[=[
	Returns an iterator function for iterating over the `MinPriorityQueue` in reverse.
	@param OnlyValues boolean? -- Whether or not the iterator returns just the values or the priorities as well.
	@return IteratorFunction -- The iterator function. Usage is `for Index, Value in MinPriorityQueue:ReverseIterator(OnlyValues) do`.
]=]
function MinPriorityQueue:ReverseIterator(OnlyValues: boolean?)
	local Array = self.Heap
	local Index = self.Length + 1

	if OnlyValues then
		return function()
			Index -= 1
			local Value = Array[Index]
			if Value ~= nil then
				return Index, Value.Value
			end
		end
	else
		return function()
			Index -= 1
			local Value = Array[Index]
			if Value ~= nil then
				return Index, Value
			end
		end
	end
end

function MinPriorityQueue:SlowReverseIterator(OnlyValues: boolean?)
	local Length: number = self.Length
	local Top = Length + 1

	if OnlyValues then
		local Array = table.create(Length)
		for Index, HeapEntry in self.Heap do
			Array[Top - Index] = HeapEntry.Value
		end

		return ipairs(Array)
	else
		local Array = table.create(Length)
		for Index, HeapEntry in self.Heap do
			Array[Top - Index] = HeapEntry
		end

		return ipairs(Array)
	end
end

MinPriorityQueue.Iterate = MinPriorityQueue.Iterator
MinPriorityQueue.ReverseIterate = MinPriorityQueue.ReverseIterator

--[=[
	Clears the entire `MinPriorityQueue`.
	@return MinPriorityQueue<T> -- The same `MinPriorityQueue`.
]=]
function MinPriorityQueue:Clear()
	table.clear(self.Heap)
	self.Length = 0
	return self
end

--[=[
	Determines if the `MinPriorityQueue` contains the given value.
	@error "InvalidValue" -- Thrown when the value is nil.

	@param Value T -- The value you are searching for.
	@return boolean -- Whether or not the value was found.
]=]
function MinPriorityQueue:Contains(Value: unknown): boolean
	if Value == nil then
		error("Argument #2 to 'MinPriorityQueue:Contains' missing or nil", 2)
	end

	for _, HeapEntry in self.Heap do
		if HeapEntry.Value == Value then
			return true
		end
	end

	return false
end

--[=[
	Removes the `HeapEntry` with the given priority, if it exists.
	@param Priority number -- The priority you are removing from the `MinPriorityQueue`.
]=]
function MinPriorityQueue:RemovePriority(Priority: number)
	for Index, HeapEntry in self.Heap do
		if HeapEntry.Priority == Priority then
			self.Length -= 1
			return table.remove(self.Heap, Index)
		end
	end

	return nil
end

--[=[
	Removes the `HeapEntry` with the given value, if it exists.
	@error "InvalidValue" -- Thrown when the value is nil.

	@param Value T -- The value you are removing from the `MinPriorityQueue`.
]=]
function MinPriorityQueue:RemoveValue(Value: unknown)
	if Value == nil then
		error("Argument #2 to 'MinPriorityQueue:RemoveValue' missing or nil", 2)
	end

	for Index, HeapEntry in self.Heap do
		if HeapEntry.Value == Value then
			self.Length -= 1
			return table.remove(self.Heap, Index)
		end
	end

	return nil
end

function MinPriorityQueue:Remove(Predicate: (Value: HeapEntry) -> boolean)
	for Index, HeapEntry in self.Heap do
		if Predicate(HeapEntry) then
			self.Length -= 1
			return table.remove(self.Heap, Index)
		end
	end

	return nil
end

function MinPriorityQueue:Find(Predicate: (Value: HeapEntry) -> boolean)
	for Index, HeapEntry in self.Heap do
		if Predicate(HeapEntry) then
			return Index
		end
	end

	return nil
end

function MinPriorityQueue:__tostring()
	local Array = table.create(self.Length)
	for Index, Value in ipairs(self.Heap) do
		Array[Index] = string.format("\t{Priority = %s, Value = %s};", tostring(Value.Priority), tostring(Value.Value))
	end

	return string.format("MinPriorityQueue<{\n%s\n}>", table.concat(Array, "\n"))
end

export type MinPriorityQueue<T = any> = {
	ClassName: "MinPriorityQueue",

	Heap: {HeapEntry<T>},
	Length: number,

	IsEmpty: (self: MinPriorityQueue<T>) -> boolean,

	InsertWithPriority: (self: MinPriorityQueue<T>, Value: T, Priority: number) -> number,
	Insert: (self: MinPriorityQueue<T>, Value: T, Priority: number) -> number,

	ChangePriority: (self: MinPriorityQueue<T>, Value: T, NewPriority: number) -> number?,

	GetFirstPriority: (self: MinPriorityQueue<T>) -> number?,
	GetLastPriority: (self: MinPriorityQueue<T>) -> number?,

	PopElement: (self: MinPriorityQueue<T>, OnlyValues: boolean?) -> T | HeapEntry<T> | nil,
	ToArray: (self: MinPriorityQueue<T>, OnlyValues: boolean?) -> {T} | {HeapEntry<T>},

	Iterator: (
		self: MinPriorityQueue<T>,
		OnlyValues: boolean?
	) -> typeof(ipairs({} :: {HeapEntry<T>})) | typeof(ipairs({} :: {T})),
	ReverseIterator: (
		self: MinPriorityQueue<T>,
		OnlyValues: boolean?
	) -> typeof(ipairs({} :: {HeapEntry<T>})) | typeof(ipairs({} :: {T})),

	Clear: (self: MinPriorityQueue<T>) -> MinPriorityQueue<T>,

	Contains: (self: MinPriorityQueue<T>, Value: T) -> boolean,
	RemovePriority: (self: MinPriorityQueue<T>, Priority: number) -> HeapEntry<T>?,
	RemoveValue: (self: MinPriorityQueue<T>, Value: T) -> HeapEntry<T>?,
	Remove: (self: MinPriorityQueue<T>, Predicate: (Value: HeapEntry<T>) -> boolean) -> HeapEntry<T>?,

	Find: (self: MinPriorityQueue<T>, Predicate: (Value: HeapEntry<T>) -> boolean) -> number?,
}

table.freeze(MinPriorityQueue)
return MinPriorityQueue

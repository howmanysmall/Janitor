export type CheckableTypes =
	"Axes"
	| "boolean"
	| "BrickColor"
	| "buffer"
	| "CFrame"
	| "Color3"
	| "ColorSequence"
	| "ColorSequenceKeypoint"
	| "DateTime"
	| "DockWidgetPluginGuiInfo"
	| "Enum"
	| "EnumItem"
	| "Enums"
	| "Faces"
	| "FloatCurveKey"
	| "Font"
	| "function"
	| "Instance"
	| "nil"
	| "number"
	| "NumberRange"
	| "NumberSequence"
	| "NumberSequenceKeypoint"
	| "OverlapParams"
	| "PathWaypoint"
	| "PhysicalProperties"
	| "Random"
	| "Ray"
	| "RaycastParams"
	| "RaycastResult"
	| "RBXScriptConnection"
	| "RBXScriptSignal"
	| "Rect"
	| "Region3"
	| "Region3int16"
	| "string"
	| "table"
	| "thread"
	| "TweenInfo"
	| "UDim"
	| "UDim2"
	| "userdata"
	| "vector"
	| "Vector2"
	| "Vector2int16"
	| "Vector3"
	| "Vector3int16"

export type CustomMatchers = {[never]: (received: unknown, expected: unknown) -> { pass: boolean, message: string }}

export type Expectation<T> = {
	to: Expectation<T> & CustomMatchers,
	be: Expectation<T> & CustomMatchers,
	been: Expectation<T> & CustomMatchers,
	have: Expectation<T> & CustomMatchers,
	was: Expectation<T> & CustomMatchers,
	at: Expectation<T> & CustomMatchers,
	never: Expectation<T> & CustomMatchers,

	a: (typeName: CheckableTypes) -> Expectation<T>,
	an: (typeName: CheckableTypes) -> Expectation<T>,
	ok: () -> Expectation<T>,
	equal: (otherValue: unknown) -> Expectation<T>,
	near: (otherValue: number, limit: number?) -> Expectation<T>,
	throw: (search: string?) -> Expectation<T>,
}

declare function afterAll(callback: () -> ()): ()
declare function afterEach(callback: () -> ()): ()

declare function beforeAll(callback: () -> ()): ()
declare function beforeEach(callback: () -> ()): ()

declare function describe(phrase: string, callback: () -> ()): ()
declare function describeFOCUS(phrase: string, callback: () -> ()): ()
declare function fdescribe(phrase: string, callback: () -> ()): ()
declare function describeSKIP(phrase: string, callback: () -> ()): ()
declare function xdescribe(phrase: string, callback: () -> ()): ()

declare function expect<T>(value: T): Expectation<T>

declare function FIXME(optionalMessage: string?): ()
declare function FOCUS(): ()
declare function SKIP(): ()

declare function it(phrase: string, callback: () -> ()): ()
declare function itFOCUS(phrase: string, callback: () -> ()): ()
declare function fit(phrase: string, callback: () -> ()): ()
declare function itSKIP(phrase: string, callback: () -> ()): ()
declare function xit(phrase: string, callback: () -> ()): ()
declare function itFIXME(phrase: string, callback: () -> ()): ()
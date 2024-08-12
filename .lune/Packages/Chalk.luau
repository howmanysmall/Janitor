--!native
--!optimize 2
--!strict

-- ROBLOX NOTE: inline stringReplaceAll to keep ChalkLua as one file
local function stringReplaceAll(value: string, substring: string, replacer: string)
	local index = string.find(value, substring, 1, true)
	if index == nil then
		return value
	end

	local substringLength = #substring
	local endIndex = 1
	local returnValue = ""
	repeat
		returnValue ..= string.sub(value, endIndex, index - 1) .. substring .. replacer
		endIndex = index + substringLength
		index = string.find(value, substring, endIndex, true)
	until index == nil
	returnValue ..= string.sub(value, endIndex)
	return returnValue
end

-- ROBLOX NOTE: inline stringEncaseCRLFWithFirstIndex to keep ChalkLua as one file
local function stringEncaseCRLFWithFirstIndex(value: string, prefix: string, postfix: string, index: number)
	local endIndex = 1
	local returnValue = ""
	repeat
		local gotCR = string.sub(value, index - 1, index - 1) == "\r"
		returnValue ..= string.sub(value, endIndex, if gotCR then index - 2 else index - 1) .. prefix .. (if gotCR
			then "\r\n"
			else "\n") .. postfix
		endIndex = index + 1
		index = string.find(value, "\n", endIndex) :: number
	until index == nil

	returnValue ..= string.sub(value, endIndex)
	return returnValue
end

local ansiStyles: {[string]: {[string]: {number}}} = {
	Modifier = {
		Reset = {0, 0};
		Bold = {1, 22};
		Dim = {2, 22};
		Italic = {3, 23};
		Underline = {4, 24};
		Overline = {53, 55};
		Inverse = {7, 27};
		Hidden = {8, 28};
		Strikethrough = {9, 29};
	};

	Color = {
		Black = {30, 39};
		Red = {31, 39};
		Green = {32, 39};
		Yellow = {33, 39};
		Blue = {34, 39};
		Magenta = {35, 39};
		Cyan = {36, 39};
		White = {37, 39};

		-- bright color
		BlackBright = {90, 39};
		Gray = {90, 39};
		Grey = {90, 39};
		RedBright = {91, 39};
		GreenBright = {92, 39};
		YellowBright = {93, 39};
		BlueBright = {94, 39};
		MagentaBright = {95, 39};
		CyanBright = {96, 39};
		WhiteBright = {97, 39};
	};

	BgColor = {
		BgBlack = {40, 49};
		BgRed = {41, 49};
		BgGreen = {42, 49};
		BgYellow = {43, 49};
		BgBlue = {44, 49};
		BgMagenta = {45, 49};
		BgCyan = {46, 49};
		BgWhite = {47, 49};

		-- bright color
		BgBlackBright = {100, 49};
		BgGray = {100, 49};
		BgGrey = {100, 49};
		BgRedBright = {101, 49};
		BgGreenBright = {102, 49};
		BgYellowBright = {103, 49};
		BgBlueBright = {104, 49};
		BgMagentaBright = {105, 49};
		BgCyanBright = {106, 49};
		BgWhiteBright = {107, 49};
	};
}

local ansi16 = "%c[%dm"
local ansi256 = "%c[%d;5;%dm"
local ESC = 27
local ANSI_SET_FOREGROUND = 38
local ANSI_SET_BACKGROUND = 48

type BaseStyle = {
	Close: string,
	Open: string,
}

local styles: {[string]: BaseStyle} = {}

for _, group in ansiStyles do
	for styleName, style in group do
		styles[styleName] = {
			Open = string.format(ansi16, ESC, style[1]);
			Close = string.format(ansi16, ESC, style[2]);
		}
	end
end

local createStyler
local applyStyle

local function compositeStyler(style: Styler, otherStyle: Styler)
	return createStyler(style.Open .. otherStyle.Open, otherStyle.Close .. style.Close)
end

local Chalk = {level = 2}
if _G.NOCOLOR then
	Chalk.level = 0
end

setmetatable(Chalk, {
	__call = function(_, value)
		if value == nil or type(value) == "string" and #value == 0 then
			return ""
		end

		return tostring(value)
	end;
})

type Styler = typeof(setmetatable(
	{} :: BaseStyle,
	{} :: {
		__call: (self: Styler, value: string) -> string,
		__concat: (self: Styler, other: Styler) -> Styler,
	}
))

local StylerMetatable = {}
function StylerMetatable:__call(value: string)
	return applyStyle(self, value)
end
function StylerMetatable:__concat(other: Styler)
	return compositeStyler(self, other)
end

function createStyler(open: string, close: string): Styler
	return setmetatable({
		Close = close;
		Open = open;
	}, StylerMetatable) :: any
end

function applyStyle(self: BaseStyle, value)
	if value == nil or type(value) == "string" and #value == 0 then
		return ""
	end

	if Chalk.level == 0 then
		return tostring(value)
	end

	local styler = self
	local openAll, closeAll = styler.Open, styler.Close

	-- insane
	-- selene: allow(bad_string_escape)
	if string.match(value, "\u{001B}") then
		-- ROBLOX deviation START: no parent styles support yet
		-- Replace any instances already present with a re-opening code
		-- otherwise only the part of the string until said closing code
		-- will be colored, and the rest will simply be 'plain'.
		value = stringReplaceAll(value, styler.Close, styler.Open)
		-- ROBLOX deviation END
	end

	-- We can move both next actions out of loop, because remaining actions in loop won't have
	-- any/visible effect on parts we add here. Close the styling before a linebreak and reopen
	-- after next line to fix a bleed issue on macOS: https://github.com/chalk/chalk/pull/92
	local lfIndex = string.find(value, "\n")
	if lfIndex ~= nil then
		value = stringEncaseCRLFWithFirstIndex(value, closeAll, openAll, lfIndex)
	end

	return `{self.Open}{value}{self.Close}`
end

local function noStyle()
	return createStyler("", "")
end

local close = string.format(ansi16, ESC, 39)
local bgClose = string.format(ansi16, ESC, 49)
local reset = string.format(ansi16, ESC, 0)

for styleName, style in styles do
	Chalk[styleName] = createStyler(style.Open, style.Close)
end

Chalk.Reset = createStyler(reset, reset)

local function rgbToAnsi256(red: number, green: number, blue: number)
	if red == green and green == blue then
		if red < 8 then
			return 16
		end

		if red > 248 then
			return 231
		end

		return math.round((red - 8) / 247 * 24 + 232)
	end

	local ansi = 16 + (36 * math.round(red / 255 * 5)) + (6 * math.round(green / 255 * 5)) + math.round(blue / 255 * 5)
	return ansi
end

function Chalk.Rgb(red: number, green: number, blue: number)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, close)
end

function Chalk.BgRgb(red: number, green: number, blue: number)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, bgClose)
end

local function hexToRgb(hex)
	local red = tonumber(string.sub(hex, 2, 3), 16) or 0
	local blue = tonumber(string.sub(hex, 4, 5), 16) or 0
	local green = tonumber(string.sub(hex, 6, 7), 16) or 0

	return rgbToAnsi256(red, blue, green)
end

function Chalk.Hex(hex: string)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, hexToRgb(hex))
	return createStyler(open, close)
end

function Chalk.BgHex(hex: string)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, hexToRgb(hex))
	return createStyler(open, bgClose)
end

function Chalk.Ansi(ansi: number)
	if type(ansi) ~= "number" or ansi < 30 or (ansi > 37 and ansi < 90) or ansi > 97 then
		return noStyle()
	end

	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, close)
end

function Chalk.BgAnsi(ansi: number)
	if type(ansi) ~= "number" or ansi < 40 or (ansi > 47 and ansi < 100) or ansi > 107 then
		return noStyle()
	end

	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, bgClose)
end

function Chalk.Ansi256(ansi: number)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, ansi)
	return createStyler(open, close)
end

function Chalk.BgAnsi256(ansi: number)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end

	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, ansi)
	return createStyler(open, bgClose)
end

type Chalk = typeof(setmetatable(
	{} :: {
		Ansi: (ansi: number) -> Styler,
		Ansi256: (ansi: number) -> Styler,
		BgAnsi: (ansi: number) -> Styler,
		BgAnsi256: (ansi: number) -> Styler,
		BgBlack: Styler,
		BgBlackBright: Styler,
		BgBlue: Styler,
		BgBlueBright: Styler,
		BgCyan: Styler,
		BgCyanBright: Styler,
		BgGray: Styler,
		BgGreen: Styler,
		BgGreenBright: Styler,
		BgGrey: Styler,
		BgHex: (hex: string) -> Styler,
		BgMagenta: Styler,
		BgMagentaBright: Styler,
		BgRed: Styler,
		BgRedBright: Styler,
		BgRgb: (red: number, green: number, blue: number) -> Styler,
		BgWhite: Styler,
		BgWhiteBright: Styler,
		BgYellow: Styler,
		BgYellowBright: Styler,
		Black: Styler,
		BlackBright: Styler,
		Blue: Styler,
		BlueBright: Styler,
		Bold: Styler,
		Cyan: Styler,
		CyanBright: Styler,
		Dim: Styler,
		Gray: Styler,
		Green: Styler,
		GreenBright: Styler,
		Grey: Styler,
		Hex: (hex: string) -> Styler,
		Hidden: Styler,
		Inverse: Styler,
		Italic: Styler,
		Magenta: Styler,
		MagentaBright: Styler,
		Overline: Styler,
		Red: Styler,
		RedBright: Styler,
		Reset: Styler,
		Rgb: (red: number, green: number, blue: number) -> Styler,
		Strikethrough: Styler,
		Underline: Styler,
		White: Styler,
		WhiteBright: Styler,
		Yellow: Styler,
		YellowBright: Styler,
	},
	{} :: {__call: (self: Chalk, value: unknown?) -> string}
))

return Chalk :: Chalk

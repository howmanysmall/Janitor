--!native
--!optimize 2
--!strict

local function ParsePrereleaseAndBuildWithSign(value: string): (string, string)
	local prereleaseWithSign, buildWithSign = string.match(value, "^(-[^+]+)(+.+)$")
	if prereleaseWithSign == nil or buildWithSign == nil then
		prereleaseWithSign = string.match(value, "^(-.+)$")
		buildWithSign = string.match(value, "^(+.+)$")
	end

	if prereleaseWithSign == nil and buildWithSign == nil then
		error(string.format("The parameter %q must begin with + or - to denote a prerelease or a build", value))
	end

	return prereleaseWithSign :: string, buildWithSign :: string
end

local function ParsePrerelease(prereleaseWithSign: string?): string?
	if prereleaseWithSign == nil then
		return nil
	end

	local prerelease = string.match(prereleaseWithSign, "^-(%w[%.%w-]*)$" :: string)
	if prerelease == nil then
		error(
			string.format(
				"The prerelease %q is not a slash followed by alphanumerics, dots and slashes",
				prereleaseWithSign
			)
		)
	end

	return prerelease
end

local function ParseBuild(buildWithSign: string?): string?
	if buildWithSign == nil then
		return nil
	end

	local build = string.match(buildWithSign, "^%+(%w[%.%w-]*)$" :: string)
	if build == nil then
		error(string.format("The build %q is not a + sign followed by alphanumerics, dots and slashes", buildWithSign))
	end

	return build
end

type Option = {
	Build: string,
	Prerelease: string,
} | {
	Build: nil,
	Prerelease: nil,
}

local function ParsePrereleaseAndBuild(value: string?): Option
	if not (value ~= "" and value) then
		return {}
	end

	local prereleaseWithSign, buildWithSign = ParsePrereleaseAndBuildWithSign(value)
	local prerelease = ParsePrerelease(prereleaseWithSign)
	local build = ParseBuild(buildWithSign)
	return {
		Build = build :: string;
		Prerelease = prerelease :: string;
	}
end

local function ParseVersion(value: string)
	local stringMajor, stringMinor, stringPatch, stringPrereleaseAndBuild =
		string.match(value, "^(%d+)%.?(%d*)%.?(%d*)(.-)$")
	if stringMajor == nil then
		error(string.format("Could not extract version number(s) from %q", value))
	end

	local major = tonumber(stringMajor) :: number
	local minor = tonumber(stringMinor) :: number
	local patch = tonumber(stringPatch) :: number
	local option = ParsePrereleaseAndBuild(stringPrereleaseAndBuild :: string)
	return major, minor, patch, option.Prerelease, option.Build
end

local function _Compare(a: any, b: any)
	return if a == b then 0 elseif a < b then -1 else 1
end
local Compare = (_Compare :: never) :: ((a: number, b: number) -> number) & ((a: string, b: string) -> number)

local function CompareIds(selfId: string, otherId: string)
	if selfId == otherId then
		return 0
	end

	if selfId == nil then
		return -1
	end

	if otherId == nil then
		return 1
	end

	local selfNumber = tonumber(selfId)
	local otherNumber = tonumber(otherId)
	if selfNumber and otherNumber then
		return Compare(selfNumber, otherNumber)
	end

	if selfNumber then
		return -1
	end

	if otherNumber then
		return 1
	end

	return Compare(selfId, otherId)
end

local function SmallerIdList(selfIds: {string}, otherIds: {string})
	for index, value in selfIds do
		local comparison = CompareIds(value, otherIds[index])
		if comparison ~= 0 then
			return comparison == -1
		end
	end

	return #selfIds < #otherIds
end

local function SmallerPrerelease(mine: string?, other: string?)
	if mine == other or not mine then
		return false
	end

	if not other then
		return true
	end

	return SmallerIdList(string.split(mine, "."), string.split(other, "."))
end

export type SemanticVersion = typeof(setmetatable(
	{} :: {
		Major: number,
		Minor: number,
		Patch: number,
		Prerelease: string?,
		Build: string?,

		NextMajor: (self: SemanticVersion) -> SemanticVersion,
		NextMinor: (self: SemanticVersion) -> SemanticVersion,
		NextPatch: (self: SemanticVersion) -> SemanticVersion,
	},
	{} :: {
		__eq: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__lt: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__pow: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__tostring: (self: SemanticVersion) -> string,
	}
))

type BaseStatics = {
	ClassName: "SemanticVersion",
	new: (
		major: number | string,
		minor: number?,
		patch: number?,
		prerelease: string?,
		build: string?
	) -> SemanticVersion,
}
type SemanticVersionStatics = BaseStatics & {
	__eq: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__lt: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__pow: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__tostring: (self: SemanticVersion) -> string,
}

local SemanticVersion = {} :: SemanticVersion & SemanticVersionStatics
SemanticVersion.ClassName = "SemanticVersion";
(SemanticVersion :: any).__index = SemanticVersion

function SemanticVersion.new(
	major: number | string,
	minor: number?,
	patch: number?,
	prerelease: string?,
	build: string?
): SemanticVersion
	local self = setmetatable({}, SemanticVersion)
	if type(major) == "string" then
		major, minor, patch, prerelease, build = ParseVersion(major)
	end

	local trueMinor = minor or 0
	local truePatch = patch or 0

	self.Major = major
	self.Minor = trueMinor
	self.Patch = truePatch
	self.Prerelease = prerelease
	self.Build = build
	table.freeze(self)
	return (self :: any) :: SemanticVersion
end

function SemanticVersion:NextMajor(): SemanticVersion
	return SemanticVersion.new(self.Major + 1, 0, 0)
end

function SemanticVersion:NextMinor(): SemanticVersion
	return SemanticVersion.new(self.Major, self.Minor + 1, 0)
end

function SemanticVersion:NextPatch(): SemanticVersion
	return SemanticVersion.new(self.Major, self.Minor, self.Patch + 1)
end

function SemanticVersion:__eq(other)
	return self.Major == other.Major
		and self.Minor == other.Minor
		and self.Patch == other.Patch
		and self.Prerelease == other.Prerelease
end
function SemanticVersion:__lt(other)
	if self.Major ~= other.Major then
		return self.Major < other.Major
	end

	if self.Minor ~= other.Minor then
		return self.Minor < other.Minor
	end

	if self.Patch ~= other.Patch then
		return self.Patch < other.Patch
	end

	return SmallerPrerelease(self.Prerelease, other.Prerelease)
end

function SemanticVersion:__pow(other)
	return if self.Major == 0 then self == other else self.Major == other.Major and self.Minor <= other.Minor
end

function SemanticVersion:__tostring()
	local stringBuilder = {string.format("%*.%*.%*", self.Major, self.Minor, self.Patch)}
	local build = self.Build
	local prerelease = self.Prerelease

	if prerelease ~= "" and prerelease then
		table.insert(stringBuilder, `-{prerelease}`)
	end

	if build ~= "" and build then
		table.insert(stringBuilder, `+{build}`)
	end

	return table.concat(stringBuilder)
end

return table.freeze(SemanticVersion :: BaseStatics)

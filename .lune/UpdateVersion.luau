--!native
--!optimize 2

local SemanticVersion = require("./Packages/SemanticVersion")

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local wally = serde.decode("toml", fs.readFile("wally.toml"))
local lastVersion = wally.package.version

local lastVersionSemantic = SemanticVersion.new(lastVersion)

local nextVersion = stdio.prompt("text", "What is the next version?", tostring(lastVersionSemantic:NextMinor()))
local nextVersionSemantic = SemanticVersion.new(nextVersion)

local function SanitizePattern(value: string)
	return (string.gsub(value, "([%.%-%*%+%?%%])", "%%%1"))
end

local function ReplaceVersion(file: string, from: string, to: string)
	fs.writeFile(file, (string.gsub(fs.readFile(file), SanitizePattern(from), to)))
end

do
	ReplaceVersion("docs/installation.md", `@{lastVersionSemantic}`, `@{nextVersionSemantic}`)
	ReplaceVersion("docs/intro.md", `@{lastVersionSemantic}`, `@{nextVersionSemantic}`)
	ReplaceVersion("README.md", `@{lastVersionSemantic}`, `@{nextVersionSemantic}`)
end
do
	ReplaceVersion("docs/installation.md", `@%^{lastVersionSemantic}`, `@^{nextVersionSemantic}`)
	ReplaceVersion("docs/intro.md", `@%^{lastVersionSemantic}`, `@^{nextVersionSemantic}`)
	ReplaceVersion("README.md", `@%^{lastVersionSemantic}`, `@^{nextVersionSemantic}`)
end
ReplaceVersion("wally.toml", `version = "{lastVersionSemantic}"`, `version = "{nextVersionSemantic}"`)

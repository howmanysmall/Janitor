---
sidebar_position: 2
---

# Installation

### Method #1 - RepoToRoblox

Using Boatbomber's [RepoToRoblox](https://devforum.roblox.com/t/repotoroblox-simple-and-quick-github-cloning-into-your-explorer/1000272) plugin is the easiest way to install in Studio.

1. In the RepoToRoblox widget, enter `howmanysmall` as the Owner and `Janitor` as the Repo.
2. Click the Clone Repo button.

![Widget](https://i.imgur.com/mOYl9T1.png)

### Method #2 - HttpService

This method uses `HttpService` to install Janitor.

1. In Roblox Studio, paste the following command into your command bar.
2. Run the following command:

<textarea readonly rows="5" onClick={e => e.target.select()} style={{
   width: "100%"
}}>
   {`local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local HttpEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local function RequestAsync(RequestDictionary)
	return HttpService:RequestAsync(RequestDictionary)
end
local function GetAsync(Url, Headers)
	Headers["cache-control"] = "no-cache"
	local Success, ResponseDictionary = pcall(RequestAsync, {
		Headers = Headers;
		Method = "GET";
		Url = Url;
	})
	if Success then
		if ResponseDictionary.Success then
			return ResponseDictionary.Body
		else
			return false, string.format("HTTP %d: %s", ResponseDictionary.StatusCode, ResponseDictionary.StatusMessage)
		end
	else
		return false, ResponseDictionary
	end
end
local function Initify(Root)
	local InitFile = Root:FindFirstChild("init") or Root:FindFirstChild("init.lua") or Root:FindFirstChild("init.client.lua") or Root:FindFirstChild("init.server.lua")
	if InitFile then
		InitFile.Name = Root.Name
		InitFile.Parent = Root.Parent
		for _, Child in ipairs(Root:GetChildren()) do
			Child.Parent = InitFile
		end
		Root:Destroy()
		Root = InitFile
	end
	for _, Child in ipairs(Root:GetChildren()) do
		Initify(Child)
	end
	return Root
end
local FilesList = HttpService:JSONDecode(assert(GetAsync(
	"https://api.github.com/repos/howmanysmall/Janitor/contents/src",
	{accept = "application/vnd.github.v3+json"}
)))
local Janitor = Instance.new("Folder")
Janitor.Name = "Janitor"
for _, FileData in ipairs(FilesList) do
	local ModuleScript = Instance.new("ModuleScript")
	ModuleScript.Name = tostring(string.match(FileData.name, "(%w+)%.lua"))
	local Success, Source = GetAsync(FileData.download_url, {})
	if not Success then
		ModuleScript.Source = string.format("-- %s", tostring(Source))
	else
		ModuleScript.Source = tostring(Success)
	end
	ModuleScript.Parent = Janitor
end
Janitor.Parent = ReplicatedStorage
Initify(Janitor)
HttpService.HttpEnabled = HttpEnabled`}
</textarea>

### Method 3 - Manual

1. Visit the [latest release](https://github.com/howmanysmall/Janitor/releases)
2. Under *Assets*, click `Janitor.rbxm`
3. - Using [Rojo](https://rojo.space/)? Put the file into your game directly.
   - Using Roblox Studio? Drag the file onto the viewport. It should insert under Workspace.

### Method 4 - Wally

1. Setup [Wally](https://wally.run/) by using `wally init`.
2. Add `howmanysmall/Janitor` as a dependency.

```toml
[dependencies]
Janitor = "howmanysmall/janitor@^1.13.13"
```

## Next

Now, check out the [API reference](/api/Janitor)!

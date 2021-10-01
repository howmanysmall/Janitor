<div align="center">
	<h1><strong>Janitor</strong></h1>
	<h3 href="https://www.npmjs.com/package/@rbxts/janitor">Now on roblox-ts!</h3>
	<h3 href="https://github.com/RoStrap/Events/blob/master/Janitor.lua">Original by Validark.</h3>
</div>
<!--moonwave-hide-before-this-line-->

## What is Janitor?

Janitor is an object that manages your other objects. When you add something to a Janitor and destroy said Janitor, the object will be cleaned up alongside it. It's very similar to how [Maid](https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua) ([explanation](https://www.youtube.com/watch?v=MOjiKS6F59s)) works, with a few differences that make it more useful.

## Why use Janitor?

- Janitor makes dealing with garbage collection much less annoying and stressful because it manages them all in a nice interface.
- `Janitor:Add` returns whatever was added, which Maid doesn't.
- `Janitor:Add` also accepts a custom method, if you want to call `:Stop` on a `Tween`. You can see this being used in the `Janitor:AddPromise` method.
- `Janitor:Add` also accepts a custom reference to store under, which keeps the api more consistent. (`Maid.A = X` and `Maid:GiveTask(Y)` vs `Janitor:Add(X, nil, "A")` and `Janitor:Add(Y)`)
- Janitor also allows linking to an Instance, so when the Instance is destroyed, the Janitor cleans up everything along with it.

## Projects that use Janitor

If your project uses Janitor, leave a PR on the readme!

- [Armtastic](https://www.roblox.com/games/6242582774/SHOP-Armtastic-Alpha) by [Mullets Mafia Red](https://www.roblox.com/groups/9160772/Mullet-Mafia-Red#!/about)
- [Be an Alien: Renewal](https://www.roblox.com/games/463915360/Be-an-Alien-Renewal) by [PeZsmistic](https://www.roblox.com/users/121643/profile)
- [Benchmarker](https://www.roblox.com/library/5853950046/Benchmarker) by [boatbomber](https://www.roblox.com/users/33655127/profile/)
- [Bloopville (NOT RELEASED)](https://www.roblox.com/games/1919575283/BloopVille0) by [BloopVille Team](https://www.bloopville.com/)
- [RBLX04](https://www.roblox.com/games/5040794421/RBLX04-A-ROBLOX-2004-Simulation) by [movsb](https://www.roblox.com/games/5040794421/RBLX04-A-ROBLOX-2004-Simulation)
- [RepoToRoblox](https://www.roblox.com/library/6284281701/RepoToRoblox) by [boatbomber](https://www.roblox.com/users/33655127/profile)
- [Science Simulator](https://www.roblox.com/games/5414779423/5M-EVENT-Science-Simulator) by [Interbyte Studio](https://www.roblox.com/groups/5126818/Interbyte-Studio#!/about)
- [Studio Tweaks](https://www.roblox.com/library/5601031949/Studio-Tweaks) by [PeZsmistic](https://www.roblox.com/users/121643/profile)

## Performance

Janitor runs incredibly well. It is quite a bit faster than [Maid](https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua) and around as fast as [Dumpster](https://gist.github.com/Fraktality/f0ab4ad950698e9f08bb01bea486845e). You can run the benchmark for yourself using [boatbomber's benchmark plugin](https://devforum.roblox.com/t/benchmarker-plugin-compare-function-speeds-with-graphs-percentiles-and-more/829912) and the bench found [here](https://github.com/boatbomber/BenchmarkerLibrary).

![Benchmark results](https://cdn.discordapp.com/attachments/507950082285502465/807365433388433408/unknown.png)

Benchmarks ran on an R9 3900X with 32GB of DDR4-3600 RAM.

## Example

```lua
local Obliterator = Janitor.new()
Obliterator:Add(function()
	print("Cleaned up!")
end, true)

Obliterator:Cleanup() -- prints "Cleaned up!".
Obliterator:Add(function()
	print("Cleaned up!")
end, true)

local Tween = Obliterator:Add(TweenService:Create(workspace.Baseplate, TweenInfo.new(1), {Transparency = 1}), "Stop", "Tween")

Obliterator:AddPromise(Promise.delay(5)):andThen(function()
	print("Success!")
end):catch(warn)

Tween:Play()
Obliterator:LinkToInstance(Workspace.Baseplate) -- When the Baseplate is destroyed, the Tween will be stopped.

task.wait(0.5)
Obliterator:Remove("Tween") -- Cancels the Tween.
Workspace.Baseplate:Destroy() -- Cancels the Promise and prints "Cleaned up!" again.
```

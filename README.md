# Janitor

Janitor library. This branch is for the thread safe version of Janitor that does not use a global state.

[Original](https://github.com/RoStrap/Events/blob/master/Janitor.lua) was made by [Validark](https://github.com/Validark), however he doesn't really maintain that version anymore. It does have all the [original documentation](https://rostrap.github.io/Libraries/Events/Janitor/) for it though.

[Now on roblox-ts!](https://www.npmjs.com/package/@rbxts/janitor)

## Projects that use Janitor

If your project uses Janitor, leave a PR on the readme!

- [Armtastic](https://www.roblox.com/games/6242582774/SHOP-Armtastic-Alpha) by [Mullets Mafia Red](https://www.roblox.com/groups/9160772/Mullet-Mafia-Red#!/about)
- [Be an Alien: Renewal](https://www.roblox.com/games/463915360/Be-an-Alien-Renewal) by [PeZsmistic](https://www.roblox.com/users/121643/profile)
- [Benchmarker](https://www.roblox.com/library/5853950046/Benchmarker) by [boatbomber](https://www.roblox.com/users/33655127/profile/)
- [RBLX04](https://www.roblox.com/games/5040794421/RBLX04-A-ROBLOX-2004-Simulation) by [movsb](https://www.roblox.com/games/5040794421/RBLX04-A-ROBLOX-2004-Simulation)
- [RepoToRoblox](https://www.roblox.com/library/6284281701/RepoToRoblox) by [a great friend](https://www.roblox.com/users/33655127/profile) (boatbomber lol)
- [Science Simulator](https://www.roblox.com/games/5414779423/5M-EVENT-Science-Simulator) by [Interbyte Studio](https://www.roblox.com/groups/5126818/Interbyte-Studio#!/about)
- [Studio Tweaks](https://www.roblox.com/library/5601031949/Studio-Tweaks) by [PeZsmistic](https://www.roblox.com/users/121643/profile)
- [Bloopville (NOT RELEASED)](https://www.roblox.com/games/1919575283/BloopVille0) by [BloopVille Team](https://www.bloopville.com/)
- [Tropical Town Tycoon](https://www.roblox.com/games/8391439627/) by [Mightybull Games](https://www.roblox.com/groups/8573100/Mightybull-Games)

## Why use Janitor?

- Janitor makes dealing with garbage collection much less annoying and stressful because it manages them all in a nice interface.
- `Janitor:Add` returns whatever was added, which Maid doesn't.
- `Janitor:Add` also accepts a custom method, if you want to call `:Stop` on a `Tween`. You can see this being used in the [JanitorPromise](https://github.com/howmanysmall/Janitor/blob/main/src/Promise/init.lua#L100) library.
- `Janitor:Add` also accepts a custom reference to store under, which keeps the api more consistent. (`Maid.A = X` and `Maid:GiveTask(Y)` vs `Janitor:Add(X, nil, "A")` and `Janitor:Add(Y)`)
- Janitor also allows linking to an Instance, so when the Instance is destroyed, the Janitor cleans up everything along with it.

### Some less important benefits

- Runs a little better than Maid does.

## Performance

Janitor runs incredibly well. It is quite a bit faster than [Maid](https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua) and around as fast as [Dumpster](https://gist.github.com/Fraktality/f0ab4ad950698e9f08bb01bea486845e). You can run the benchmark for yourself using [boatbomber's benchmark plugin](https://devforum.roblox.com/t/benchmarker-plugin-compare-function-speeds-with-graphs-percentiles-and-more/829912) and the bench found [here](https://github.com/boatbomber/BenchmarkerLibrary).

![Benchmark results](https://cdn.discordapp.com/attachments/507950082285502465/807365433388433408/unknown.png)

Benchmarks ran on an R9 3900X with 32GB of DDR4-3600 RAM.

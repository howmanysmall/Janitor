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

## Why use Janitor?

- Janitor makes dealing with garbage collection much less annoying and stressful because it manages them all in a nice interface.
- `Janitor:Add` returns whatever was added, which Maid doesn't.
- `Janitor:Add` also accepts a custom method, if you want to call `:Stop` on a `Tween`. You can see this being used in the [JanitorPromise](https://github.com/howmanysmall/Janitor/blob/main/src/Promise/init.lua#L100) library.
- `Janitor:Add` also accepts a custom reference to store under, which keeps the api more consistent. (`Maid.A = X` and `Maid:GiveTask(Y)` vs `Janitor:Add(X, nil, "A")` and `Janitor:Add(Y)`)
- Janitor also allows linking to an Instance, so when the Instance is destroyed, the Janitor cleans up everything along with it.

### Some less important benefits:

- Runs a little better than Maid does.

## Which version should you use?

- If you use [Promise](https://github.com/evaera/roblox-lua-promise), you should take a look at [JanitorPromise](https://github.com/howmanysmall/Janitor/blob/main/src/Promise/init.lua).
- If you don't use Promise, you should look at [Janitor](https://github.com/howmanysmall/Janitor/blob/main/src/Standard/init.lua).
- If you don't want extra dependencies, use one of the Light libraries.

## Performance

Janitor runs incredibly well. It is quite a bit faster than [Maid](https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua) and around as fast as [Dumpster](https://gist.github.com/Fraktality/f0ab4ad950698e9f08bb01bea486845e). You can run the benchmark for yourself using [boatbomber's benchmark plugin](https://devforum.roblox.com/t/benchmarker-plugin-compare-function-speeds-with-graphs-percentiles-and-more/829912) and the bench found [here](https://github.com/boatbomber/BenchmarkerLibrary).

![Benchmark results](https://cdn.discordapp.com/attachments/507950082285502465/807365433388433408/unknown.png)

Benchmarks ran on an R9 3900X with 32GB of DDR4-3600 RAM.

## Janitor API

<details>
<summary><code>function Janitor.new()</code></summary>

Instantiates a new Janitor object.

**Returns:**  
`Janitor`  


</details>

<details>
<summary><code>function Janitor.Is(Object)</code></summary>

Determines if the passed object is a Janitor.

**Parameters:**
- `Object` (`any`)  
The object you are checking.

**Returns:**  
`boolean`  
Whether or not the object is a Janitor.

</details>

<details>
<summary><code>function Janitor.__index:Add(Object, MethodName, Index)</code></summary>

Adds an `Object` to Janitor for later cleanup, where `MethodName` is the key of the method within `Object` which should be called at cleanup time. If the `MethodName` is `true` the `Object` itself will be called instead. If passed an index it will occupy a namespace which can be `Remove()`d or overwritten. Returns the `Object`.

**Parameters:**
- `Object` (`any`)  
The object you want to clean up.
- `MethodName` (`string|true?`)  
The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
- `Index` (`any?`)  
The index that can be used to clean up the object manually.

**Returns:**  
`any`  
The object that was passed.

</details>

<details>
<summary><code>function Janitor.__index:AddPromise(PromiseObject)</code></summary>

Adds a promise to the janitor. If the janitor is cleaned up and the promise is not completed, the promise will be cancelled.

**Parameters:**
- `PromiseObject` (`Promise`)  
The promise you want to add to the janitor.

**Returns:**  
`Promise`  


</details>

<details>
<summary><code>function Janitor.__index:Remove(Index)</code></summary>

Cleans up whatever `Object` was set to this namespace by the 3rd parameter of `:Add()`.

**Parameters:**
- `Index` (`any`)  
The index you want to remove.

**Returns:**  
`Janitor`  
The same janitor, for chaining reasons.

</details>

<details>
<summary><code>function Janitor.__index:Get(Index)</code></summary>

Gets whatever object is stored with the given index, if it exists. This was added since Maid allows getting the task using `__index`.

**Parameters:**
- `Index` (`any`)  
The index that the object is stored under.

**Returns:**  
`any?`  
This will return the object if it is found, but it won't return anything if it doesn't exist.

</details>

<details>
<summary><code>function Janitor.__index:Cleanup()</code></summary>

Calls each Object's `MethodName` (or calls the Object if `MethodName == true`) and removes them from the Janitor. Also clears the namespace. This function is also called when you call a Janitor Object (so it can be used as a destructor callback).

**Returns:**  
`void`  


</details>

<details>
<summary><code>function Janitor.__index:Destroy()</code></summary>

Calls `:Cleanup()` and renders the Janitor unusable.

**Returns:**  
`void`  


</details>

<details>
<summary><code>function Janitor.__index:LinkToInstance(Object, AllowMultiple)</code></summary>

"Links" this Janitor to an Instance, such that the Janitor will `Cleanup` when the Instance is `Destroyed()` and garbage collected. A Janitor may only be linked to one instance at a time, unless `AllowMultiple` is true. When called with a truthy `AllowMultiple` parameter, the Janitor will "link" the Instance without overwriting any previous links, and will also not be overwritable. When called with a falsy `AllowMultiple` parameter, the Janitor will overwrite the previous link which was also called with a falsy `AllowMultiple` parameter, if applicable.

**Parameters:**
- `Object` (`Instance`)  
The instance you want to link the Janitor to.
- `AllowMultiple` (`boolean?`)  
Whether or not to allow multiple links on the same Janitor.

**Returns:**  
`RbxScriptConnection`  
A pseudo RBXScriptConnection that can be disconnected.

</details>

<details>
<summary><code>function Janitor.__index:LinkToInstances(...)</code></summary>

Links several instances to a janitor, which is then returned.

**Parameters:**
- `...` (`...Instance`)  
All the instances you want linked.

**Returns:**  
`Janitor`  
A janitor that can be used to manually disconnect all LinkToInstances.

</details>


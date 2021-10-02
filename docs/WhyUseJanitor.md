---
sidebar_position: 3
---

# Why use Janitor?

Most of what I can say about why use something similar to Janitor has already been said by Quenty in his [RDC 2020 talk](https://www.youtube.com/watch?v=MOjiKS6F59s), so this page will only cover the reasons to use Janitor itself.

### Ease of use

Janitor makes dealing with garbage collection much less annoying and stressful because it manages them all in a nice interface.

### Returning

`Janitor:Add()` returns the first object passed, which Maid does not.

### Custom Cleanup Methods

With Maid, you can't tell it to do anything other than `:Destroy()`, `:Disconnect()`, or call something. Janitor allows any method you choose to be called for cleanup. This includes `Tween:Stop()`, `Humanoid:BreakJoints()`, or `Tool:Deactivate()`. You can see this being used in the `Janitor:AddPromise()` method.

### API Consistency

`Janitor:Add()` also accepts a custom reference to store under, which keeps the API more consistent.

|                                        | **Janitor**                                 | **Maid**                  |
|----------------------------------------|---------------------------------------------|---------------------------|
| Adding an Instance                     | `Janitor:Add(Instance, "Destroy")`          | `Maid:GiveTask(Instance)` |
| Adding an Instance under a given index | `Janitor:Add(Instance, "Destroy", "Index")` | `Maid.Index = Instance`   |

### LinkToInstance

Janitor also allows linking to an Instance via the `Janitor:LinkToInstance()` method. This allows the Janitor to cleanup everything added to it when an Instance has its `Instance:Destroy()` method invoked.

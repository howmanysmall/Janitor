---
sidebar_position: 3
---

# Why use Janitor?

Most of what I can say about why use something similar to Janitor has already been said by Quenty in his [RDC 2020 talk](https://www.youtube.com/watch?v=MOjiKS6F59s), so this page will only cover the reasons to use Janitor itself.

### Ease of use

Janitor makes dealing with garbage collection much less annoying and stressful because it manages them all in a nice interface.

### High Performance

While I don't really *recommend* using Janitor if you're gonna be cleaning up every frame, it is significantly faster than any other library with a similar API design.

### Returning

`Janitor:Add()` returns the first object passed, which Maid does not.

### Custom Cleanup Methods

With Maid, you can't tell it to do anything other than `:Destroy()`, `:Disconnect()`, or call something. Janitor allows any method you choose to be called for cleanup. This includes `Tween:Stop()`, `Humanoid:BreakJoints()`, or `Tool:Deactivate()`. You can see this being used in the `Janitor:AddPromise()` method.

### API Consistency

`Janitor:Add()` also accepts a custom reference to store under, which keeps the API more consistent.

|                                          | **Janitor**                             | **Maid**                  | **Trove**                    |
|------------------------------------------|-----------------------------------------|---------------------------|------------------------------|
| Adding an Instance                       | `Janitor:Add(Instance)`                 | `Maid:GiveTask(Instance)` | `Trove:Add(Instance)`        |
| Adding an Instance with a given index    | `Janitor:Add(Instance, false, "Index")` | `Maid.Index = Instance`   | **CAN NOT DO THIS**          |
| Adding an Instance with a cleanup method | `Janitor:Add(Tween, "Cancel")`          | **CAN NOT DO THIS**       | `Trove:Add(Tween, "Cancel")` |
| Removing an Instance                     | `Janitor:Remove("Index")`               | `Maid.Index = nil`        | **CAN NOT DO THIS**          |
| Removing without cleanup                 | `Janitor:RemoveNoClean("Index")`        | **CAN NOT DO THIS**       | **CAN NOT DO THIS**          |

### LinkToInstance

Janitor also allows linking to an Instance via the `Janitor:LinkToInstance()` method. This allows the Janitor to cleanup everything added to it when an Instance has its `Instance:Destroy()` method invoked.

### Native support for Promises

Janitor is the only library of its kind that supports cancelling Promises.

### TypeScript Support

Janitor has the best TypeScript support of any library like it. You have full intellisense with the objects stored in it, as well as the methods you can use to cleanup with.

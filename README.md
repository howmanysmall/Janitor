# Janitor

A thread-safe garbage-collection library for Roblox. This branch is a rewritten version that does not use global state.

Originally created by [Validark](https://github.com/Validark), now maintained here.

- 📦 [npm](https://www.npmjs.com/package/@rbxts/janitor) (roblox-ts)
- 📖 [Docs](https://howmanysmall.github.io/Janitor/) — installation, API reference, why you'd use it, and more.

## Benchmark

Janitor is significantly faster than [Maid](https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua) and roughly on par with [Dumpster](https://gist.github.com/Fraktality/f0ab4ad950698e9f08bb01bea486845e). Run the benchmarks yourself using [boatbomber's Benchmarker plugin](https://devforum.roblox.com/t/benchmarker-plugin-compare-function-speeds-with-graphs-percentiles-and-more/829912).

![Benchmark results](https://cdn.discordapp.com/attachments/507950082285502465/807365433388433408/unknown.png)

Benchmarks ran on an R9 3900X with 32 gigabytes of DDR4-3600 RAM.

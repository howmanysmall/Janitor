# Janitor Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.17.0] - 2024-08-12

### Added

- Removed old TestEZ unit testing in favor of Jest.
- Added Lune scripts for building.
- Improved the documentation.
- Fixed doc comments being way too long.

### Changed

- Rewrote the API to be correct for Luau LSP strict mode and Roblox strict mode.
- Changed the `Janitor.AddPromise` API to be a better typed version.
- Rewrote the code to be a little bit more readable.
- Optimized the code with funny micro optimizations.

### Fixed

- Fixed suspicious thread cleanup.

## [1.16.0] - 2024-05-01

### Added

- Added `Janitor.AddObject` for constructing an object.
- Made the type for Janitor more accurate (you can now actually do `__call` without it whining!)

### Changed

- Changed some minor syntax things.

## [1.15.7] - 2023-12-27

### Added

- Added `Janitor.instanceof` for rbxts usage.

### Changed

- Made the Promise dependency "optional". It's still required in the Wally file, but it's not actually required if it can't detect it.
- Updated the dependencies in the aftman file.
- Changed one of the tests to use itSKIP.

## [1.15.6] - 2023-08-09

### Added

- Added a small safeguard in `Janitor:LinkToInstances()` that prevents non-Instances.

### Changed

- The Promise dependency has been bumped to `4.0.0-rc.2`.
- Changed how the formatting of Janitor is (120 character lines).

### Fixed

- Fixed an error that would only happen if you set SuppressInstanceReDestroy (tries to clean it up). Thanks Meta-Maxim!

### Removed

- "Removed" `LegacyLinkToInstance`. This reduces the overall size of the package. The function itself still technically exists,
just as a pointer to `LinkToInstance`, but it is not exported with the class type.
- Removed the Symbol ModuleScript. We're gonna use a metatable'd table instead from now on. This also reduces the size of the package.

## [1.15.5] - 2023-07-28

### Changed

- Promise is now a required dependency. This prevents a bug with `AddPromise` not detecting a Promise library if it is not
called exactly `Promise`. Thanks colbert2677!

## [1.15.4] - 2023-07-20

### Added

- Added a toggle to avoid double destruction of instances. Thanks Meta-Maxim!

### Fixed

- Fixed an error being thrown when an ended thread is cleaned up. (#31) Thanks brinkokevin!

## [1.15.3] - 2023-07-01

### Changed

- Changed how threads are cleaned up internally.

## [1.15.2] - 2023-04-11

### Changed

- `Janitor.new` actually returns the typed Janitor class.

## [1.15.1] - 2022-11-30

### Added

- Added `Janitor:GetAll` as requested by AlreadyPro.

### Fixed

- Fixed incorrect type in the Janitor exported type.
- Fixed out of date documentation in `Installation.md`.

### Removed

- Removed the old toml files for Selene.
- Removed `foreman.toml`.

## [1.15.0] - 2022-11-30

### Added

- Added `Janitor:RemoveNoClean` and `Janitor:RemoveListNoClean`, which allows removal without cleaning.
- Added a nicer type return for Janitor. No more `typeof(Janitor.new())`!

### Fixed

- Fixed serious issue where `Janitor:RemoveList` would not actually remove anything from the indices reference.

## [1.14.2] - 2022-11-09

### Added 

### Fixed

- Fixed Janitor error when attempting call task.cancel on a running thread

## 1.14.1 - 2022-03-17

### Added

- Added a new `LinkToInstance` method which will instead use `Instance.Destroying`.
- Added traceback to `Janitor:AddPromise` for invalid promises.

### Changed

- The legacy `LinkToInstance` method has been renamed to `LegacyLinkToInstance`.

### Fixed

- Fixed Janitor not warning about an invalid `MethodName` for threads and functions.
- Fixed incorrect documentation about `Janitor.CurrentlyCleaning`.

## 1.14 - 2022-03-12

### Added

- You can now add a `thread` using `:Add`. This will cancel said thread when the Janitor is cleaned up.
- Added `__tostring` to the Janitor class.
- Added `:RemoveList` as an alternative to long `:Remove` chains.
- Added the properties of `Janitor` and `RbxScriptConnection` to the documentation.

### Changed

- Recompiled with L+ C Edition.
- Put `RbxScriptConnection` in a separate file.
- Documentation now will split the code examples by language more obviously.

## 1.13.15 - 2021-11-24

### Changed

- `Janitor:Cleanup` now uses a while loop instead of a for loop when cleaning up. Fixed by @codesenseAye.

## 1.13.14 - 2021-11-05

### Fixed

- `Janitor:AddPromise` now will handle cancellations properly.

## 1.13.13 - 2021-10-20

### Changed

- Finding Promise is now more aware for plugins. This way it won't load a Promise library inside of ReplicatedStorage.

### Fixed

- APIs that return Janitor like `Janitor::Remove` no longer explicitly state the return type. This seems to cause problems with typed Luau.

## 1.13.12 - 2021-10-02

### Added

- A brand new [documentation site](https://howmanysmall.github.io/Janitor/api/Janitor/).

### Changed

- Janitor's `__index` no longer points to a separate table.

### Fixed

- Urgent fix for the cleanup loop. I had forgotten the `continue` so it would've likely broken.

## 1.13.11 - 

- This version has been scrubbed from GitHub releases for a reason.

## 1.13.10 - 2021-09-29

### Added

- Added support for Promise existing in the `Server*` services.
- Documentation comments have been overhauled.

## 1.13.9 - 2021-09-18

### Added

- A singular version of Janitor is now the only version. This still supports Promises, it just searches for the Promise library.

### Changed

- The file tree for Janitor has been standardized.

## 1.13.7 - 2021-09-16

### Changed

- The cleanup loop now uses `in pairs` instead of `in next`.

### Removed

- The `task.spawn` cleanups are now removed.

## 1.13.6 - 2021-08-21

### Added

- Janitor now cleans up the tasks using `task.spawn`.
- Janitor now has types.
- Janitor will work far better with typed Luau as well.

## 1.13.4 - 2021-05-27

### Fixed

- `Janitor:LinkToInstance` now works on deferred event mode. Shoutout to @Elttob for fixing it.

## 1.0.0 - 

- Initial release.

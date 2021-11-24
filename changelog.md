# Janitor Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

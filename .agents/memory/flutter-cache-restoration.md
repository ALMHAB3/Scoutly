---
name: Flutter cache restoration
description: Workspace Flutter caches may be missing or stale, including generated web plugin manifests after dependency changes.
---

Use the workspace Flutter SDK for project commands; the Nix-provided Flutter on PATH can be older than the dependency constraints. Do not assume a retained SDK, web build, or package configuration means the global Pub cache is intact. After removing Flutter plugins, a stale generated web plugin registrant can still reference packages that are no longer in the dependency graph.

**Why:** The workspace toolchain may satisfy the project while the system Flutter cannot resolve its locked packages, and referenced Pub packages may also disappear between sessions. Stale web plugin output can make a release build fail even when analysis and tests pass.

**How to apply:** Prefer `.local/toolchains/flutter/bin/flutter`; run `pub get` there before formatting or testing when cached package paths are missing. If a web build imports a removed plugin, run `flutter clean`, `pub get`, then rebuild before restoring dependencies. Do not downgrade dependencies or remove lint configuration to work around a missing or stale system SDK/cache.

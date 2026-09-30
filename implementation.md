# T3 Code Flake Implementation Plan

## Purpose

This document is a handoff-grade implementation plan for this repository. Another agent should be able to take over from here and understand the architecture, invariants, update flow, and validation expectations without re-deriving context.

## Objective

Build and maintain a Nix flake that:

- packages the upstream T3 Code desktop application from the GitHub release assets for Linux and macOS,
- exposes the upstream `t3` CLI as an optional secondary package from npm,
- tracks upstream releases automatically,
- updates pinned versions and hashes in-repo,
- validates the updated derivations before proposing a PR.

## Current Upstream Facts

Verified on September 29, 2026:

- Upstream repository: `https://github.com/pingdotgg/t3code`
- Latest release: `v0.0.44`
- Desktop Linux amd64 Debian asset: `T3-Code-0.0.44-amd64.deb`
- Desktop Linux amd64 Debian asset digest from GitHub API: `sha256:aac558cbb5f66a4ed3c08147cdc7c9918c06203404fc17dd90e011eb7ce01453`
- Desktop Linux arm64 Debian asset: `T3-Code-0.0.44-arm64.deb`
- Desktop Linux arm64 Debian asset digest from GitHub API: `sha256:d0112ba1e1416e78f92898a4204ff63596b37ca1d8bf2ebefad806fa88f2acce`
- Desktop macOS arm64 zip asset: `T3-Code-0.0.44-arm64.zip`
- Desktop macOS arm64 zip digest from GitHub API: `sha256:480b5cd8ebcee4f4f43e108d309d91fe7c879931d8aae8a67b71cfd8a07ce0df`
- Matching npm package exists: `t3@0.0.44`
- Matching npm tarball integrity: `sha512-xUewTKiHquRurWIvsM6FMFMPQ6dyZUBerAmrkO5pAGX+0qDUT/VXJpSis7j1ROLI85bS6JAcYTws9dcDP2vudw==`

## Design Decisions

### Primary artifact

The primary artifact is the desktop application, not the npm CLI.

The default flake package and app must therefore resolve to the desktop package, using the upstream Debian package on `x86_64-linux` and `aarch64-linux`, and macOS zip archives on Darwin.

### Secondary artifact

The CLI is kept as an optional secondary package because upstream publishes it separately and the repository structure is intentionally similar to `sadjow/codex-cli-nix`, where multiple upstream artifact forms are packaged side by side.

### Packaging rules

The repository must package upstream artifacts directly.

That means:

- no `npx` runtime wrapper,
- no `npm exec` runtime wrapper,
- no first-run dependency downloads,
- pinned hashes in Nix expressions,
- automated updates through repository changes, not through runtime install logic.

## Repository Layout

### `package.nix`

Desktop package source of truth.

Responsibilities:

- pin desktop version,
- pin Linux and macOS desktop hashes,
- fetch the matching Linux Debian package or macOS zip archive depending on platform,
- unpack the Linux Debian package with `dpkg-deb -x`,
- patch the Linux ELF files with `autoPatchelfHook` and explicit runtime libraries,
- install the Debian application tree under `$out/lib/t3code`, desktop entry, and icons,
- expose `$out/bin/t3code` through a wrapper with `T3CODE_DISABLE_AUTO_UPDATE=true`,
- install the macOS `.app` bundle and a `t3code` launcher on Darwin,
- expose correct package metadata.

### `package-cli.nix`

CLI package source of truth.

Responsibilities:

- pin CLI version,
- pin npm tarball integrity hash,
- build with `buildNpmPackage`,
- use committed `npm/package.json` and `npm/package-lock.json`,
- vendor dependencies into the Nix store,
- expose a `t3` executable.

### `npm/package.json` and `npm/package-lock.json`

Committed upstream CLI metadata.

Responsibilities:

- reflect the exact published npm package for the pinned CLI version,
- provide the lockfile consumed by `importNpmLock`,
- allow deterministic vendoring in Nix.

### `flake.nix`

Responsibilities:

- expose `packages.default = desktop`,
- expose `packages.t3code`, `packages.t3code-desktop`, `packages.t3code-cli`, and `packages.t3`,
- expose matching `apps`,
- expose `overlays.default`,
- expose `devShells.default`,
- expose basic checks.

### `scripts/update.sh`

Responsibilities:

- fetch the latest GitHub release JSON,
- extract the `amd64.deb`, `arm64.deb`, and `arm64.zip` desktop assets and digests,
- convert the GitHub digest to SRI format for Nix,
- verify a matching npm `t3` version exists,
- refresh `npm/package.json` and `npm/package-lock.json`,
- update `package.nix` and `package-cli.nix`,
- validate the flake.

### `.github/workflows/update.yml`

Responsibilities:

- schedule update checks,
- support manual dispatch,
- install Nix and Node.js,
- run `./scripts/update.sh --check`,
- run the real update when needed,
- open a PR with the changed files.

### `.github/workflows/ci.yml`

Responsibilities:

- run on pushes, pull requests, and manual dispatch,
- build the flake on `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`,
- verify the desktop launcher exists,
- verify the CLI entrypoint runs.

### `.github/workflows/release.yml`

Responsibilities:

- run on pushes to `main` that update packaged artifacts,
- read the packaged version from `package.nix`,
- create a `v<version>` tag and matching GitHub release when one does not already exist.

## Update Invariant

The repository intentionally keeps the desktop package and CLI package on the same upstream version.

That means the updater should only succeed when both are available for the target version:

- GitHub release amd64 Debian package exists,
- GitHub release arm64 Debian package exists,
- GitHub release macOS `arm64.zip` exists,
- npm `t3@<version>` exists.

If one exists without the other, the update should fail explicitly rather than silently creating a split-version repository state.

## GitHub Setup Requirements

Repository settings should be configured so that:

- GitHub Actions has read/write workflow permissions,
- GitHub Actions is allowed to create pull requests,
- auto-merge is enabled,
- `main` is protected by required CI checks,
- a `GH_TOKEN_FOR_UPDATES` secret is available if updater PRs must trigger `pull_request` workflows.

## Validation Expectations

Minimum local validation after an update:

- `nix flake check`
- `nix eval .#packages.aarch64-darwin.t3code.drvPath`
- `nix eval .#packages.aarch64-darwin.t3code-cli.drvPath`
- `nix build .#t3code`
- `test -x ./result/bin/t3code`
- `nix build .#t3code-cli`
- `./result/bin/t3 --help`

If GUI execution is practical in the environment, the desktop binary should also be launched manually. In headless CI, build validation is sufficient.

## Known Constraints

- Desktop packaging is currently implemented for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.
- The desktop package is built from upstream binary artifacts, so this is not a source build.
- The CLI package depends on native npm modules such as `node-pty`, so validation should not be assumed across architectures without an actual build.
- GitHub Actions should provide real build validation on `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

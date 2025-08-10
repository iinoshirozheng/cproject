# cproject (Rust CLI Skeleton)

A minimal, production-ready-ish skeleton of a Rust-powered generator for C/C++ projects,
designed to gradually replace shell scripts while staying compatible with your current workflow.

## Quick Start

```bash
# 1) Build the Rust CLI
cargo build

# 2) Generate a C++ executable project
./target/debug/cproject create HelloApp

# 3) Build & Run it (uses CMake)
cd HelloApp
../../target/debug/cproject build
../../target/debug/cproject run
```

> Note: `vcpkg` is optional here. If `VCPKG_ROOT` is set, the toolchain file will be passed to CMake automatically.

## What’s inside

- Single-crate Rust CLI using `clap` + `anyhow`
- Embedded templates via `rust-embed` + `handlebars`
- Minimal `create`, `build`, `run`, `test`, `doctor` commands
- (Beta) `pkg` subcommands that demonstrate vcpkg integration
- Shell scripts preserved under `scripts/` for fallback/transition

See inline comments in code for details.

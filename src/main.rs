// src/main.rs

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use tracing_subscriber::EnvFilter;

// 載入我們新的核心模組
mod archetype;
mod build;
mod config;
mod doctor;
mod pkg;
mod util;

#[derive(Parser)]
#[command(
    name = "cproject",
    version,
    about = "A configuration-driven C++ project manager (Rust CLI)"
)]
struct Cli {
    /// Verbose logs (set RUST_LOG for more control)
    #[arg(long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Create a new project from an archetype.
    Create {
        /// The archetype to use (e.g., 'app', 'lib'). Defined in cproject.toml.
        archetype_name: String,
        /// The name of the new project directory.
        project_name: String,
        /// Use defaults for all prompts (non-interactive)
        #[arg(long, alias = "yes")]
        defaults: bool,
    },
    /// Configure & build the project.
    Build {
        #[arg(long)]
        debug: bool,
    },
    /// Build & run the executable.
    Run {
        #[arg(long)]
        debug: bool,
    },
    /// Build & run tests.
    Test,
    /// Manage vcpkg packages (experimental).
    Pkg {
        #[command(subcommand)]
        sub: PkgCmd,
    },
    /// Check environment and tools.
    Doctor,
}

#[derive(Subcommand)]
enum PkgCmd {
    /// Install a vcpkg port and inject CMake usage.
    Add { name: String },
    /// Remove a vcpkg port and injected block.
    Rm { name: String },
    /// Search for available ports.
    Search { name: String },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // 初始化日誌
    let filter = if cli.verbose {
        "info,cproject=debug"
    } else {
        "warn"
    };
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(filter)),
        )
        .init();

    // 載入應用程式組態
    let config = config::Config::load().context("Failed to load configuration")?;

    // --- 命令處理 ---
    // 注意：現在我們將 `config` 物件傳遞給需要它的命令處理函數
    match cli.cmd {
        Cmd::Create {
            archetype_name,
            project_name,
            defaults,
        } => {
            // 1. 載入原型
            let archetype = archetype::Archetype::load(&config, &archetype_name)
                .with_context(|| format!("Failed to load archetype '{}'", archetype_name))?;

            // 2. 實例化原型
            let dest_path = PathBuf::from(&project_name);
            archetype
                .instantiate(&project_name, &dest_path, defaults)
                .with_context(|| format!("Failed to instantiate project '{}'", project_name))?;
        }
        Cmd::Build { debug } => build::cmake_build(&config, debug)?,
        Cmd::Run { debug } => {
            build::cmake_build(&config, debug)?;
            build::run_exe(&config, debug)?;
        }
        Cmd::Test => {
            // 測試通常在 debug 模式下進行
            build::cmake_build(&config, true)?;
            build::run_tests(&config)?;
        }
        Cmd::Pkg { sub } => match sub {
            PkgCmd::Add { name } => pkg::add(&name)?,
            PkgCmd::Rm { name } => pkg::rm(&name)?,
            PkgCmd::Search { name } => pkg::search(&name)?,
        },
        Cmd::Doctor => doctor::run()?,
    }

    Ok(())
}

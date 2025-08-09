use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

mod scaffold;
mod build;
mod doctor;
mod pkg;
mod util;

#[derive(Parser)]
#[command(name = "cproject", version, about = "C/C++ project generator & manager (Rust CLI)")]
struct Cli {
    /// Verbose logs (set RUST_LOG for more control)
    #[arg(long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Create a new project (default: executable). Use --library for a library.
    Create {
        /// Project name
        name: String,
        /// Create a library project
        #[arg(long)]
        library: bool,
    },
    /// Configure & build (Debug with --debug)
    Build {
        #[arg(long)]
        debug: bool,
    },
    /// Build & run
    Run {
        #[arg(long)]
        debug: bool,
    },
    /// Build & run tests (ctest)
    Test,
    /// Manage vcpkg packages (experimental)
    Pkg {
        #[command(subcommand)]
        sub: PkgCmd,
    },
    /// Check environment/tools
    Doctor,
}

#[derive(Subcommand)]
enum PkgCmd {
    /// Install a vcpkg port and inject CMake usage
    Add { name: String },
    /// Remove a vcpkg port and remove injected block
    Rm { name: String },
    /// Search ports (calls `vcpkg search`)
    Search { name: String },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    // basic logging setup
    let filter = if cli.verbose { "info" } else { "warn" };
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(filter)))
        .init();

    match cli.cmd {
        Cmd::Create { name, library } => scaffold::create_project(&name, library)?,
        Cmd::Build { debug } => build::cmake_build(debug)?,
        Cmd::Run { debug } => { build::cmake_build(debug)?; build::run_exe(debug)?; }
        Cmd::Test => { build::cmake_build(true)?; build::run_tests()?; }
        Cmd::Pkg { sub } => match sub {
            PkgCmd::Add { name } => pkg::add(&name)?,
            PkgCmd::Rm { name } => pkg::rm(&name)?,
            PkgCmd::Search { name } => pkg::search(&name)?,
        },
        Cmd::Doctor => doctor::run()?,
    }
    Ok(())
}

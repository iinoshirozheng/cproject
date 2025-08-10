use anyhow::{anyhow, Context, Result};
use std::{fs, path::Path, process::Command};

// Import our new Config struct
use crate::config::Config;
use crate::util;

/// Configure and build the project using CMake.
/// Now accepts the application config to find the toolchain.
pub fn cmake_build(config: &Config, debug: bool) -> Result<()> {
    let build_type = if debug { "Debug" } else { "Release" };
    let build_dir = format!("build/{}", if debug { "debug" } else { "release" });
    fs::create_dir_all(&build_dir)?;

    // Configure
    let mut cfg = Command::new("cmake");
    cfg.args(["-S", ".", "-B", &build_dir])
        .arg(format!("-DCMAKE_BUILD_TYPE={build_type}"));

    // If we later add C++ standard to Config, we can pass -DCMAKE_CXX_STANDARD here.

    // --- ARCHITECTURE CHANGE ---
    // Instead of guessing, we now get the vcpkg path directly from the config.
    if let Some(vcpkg_root) = &config.vcpkg_root {
        let toolchain_file = vcpkg_root.join("scripts/buildsystems/vcpkg.cmake");
        if toolchain_file.exists() {
            cfg.arg(format!(
                "-DCMAKE_TOOLCHAIN_FILE={}",
                toolchain_file.display()
            ));
        } else {
            // It's good practice to inform the user if the configured path is problematic.
            println!(
                "⚠️  Warning: vcpkg_root is set, but toolchain file not found at {}",
                toolchain_file.display()
            );
        }
    }

    let st = cfg.status().context("Failed to invoke cmake (configure)")?;
    if !st.success() {
        return Err(anyhow!("cmake configure failed"));
    }

    // Build
    println!("🔨 Building project in '{}' mode...", build_type);
    let st = Command::new("cmake")
        .args(["--build", &build_dir, "--"])
        // A simple improvement: use multiple cores for faster builds.
        .arg(format!("-j{}", num_cpus::get()))
        .status()
        .context("Failed to invoke cmake --build")?;
    if !st.success() {
        return Err(anyhow!("cmake build failed"));
    }

    println!("✅ Build complete.");
    Ok(())
}

/// Build and run the project's main executable.
pub fn run_exe(_config: &Config, debug: bool) -> Result<()> {
    // Accept config for future use
    let name = util::project_name_from_cmakelists(".")?;
    let exe_path = Path::new("build")
        .join(if debug { "debug" } else { "release" })
        .join(&name);

    println!("🚀 Running executable: {}", exe_path.display());
    println!("------------------------------------------");

    let st = Command::new(&exe_path)
        .status()
        .with_context(|| format!("Failed to run executable at {}", exe_path.display()))?;

    println!("------------------------------------------");
    if !st.success() {
        return Err(anyhow!("Program exited with non-zero status"));
    }
    Ok(())
}

/// Build and run the project's tests using CTest.
pub fn run_tests(_config: &Config) -> Result<()> {
    // Accept config for future use
    // Tests are almost always run in Debug mode.
    let test_dir = "build/debug";

    println!("🔬 Running tests in '{}'...", test_dir);
    let st = Command::new("ctest")
        .current_dir(test_dir) // It's often more reliable to run ctest from its build dir.
        .args(["--output-on-failure"])
        .status()
        .context("Failed to invoke ctest")?;

    if !st.success() {
        return Err(anyhow!("Tests failed"));
    }

    println!("✅ All tests passed.");
    Ok(())
}

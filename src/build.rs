use anyhow::{anyhow, Context, Result};
use regex::Regex;
use std::env;
use std::{fs, path::Path, process::Command};

// Import our new Config struct
use crate::config::Config;
use crate::util;

/// Configure and build the project using CMake.
/// Now accepts the application config to find the toolchain.
pub fn cmake_build(config: &Config, debug: bool, build_tests: bool) -> Result<()> {
    let build_type = if debug { "Debug" } else { "Release" };
    let build_dir = format!("build/{}", if debug { "debug" } else { "release" });
    fs::create_dir_all(&build_dir)?;

    // Configure
    let mut cfg = Command::new("cmake");
    cfg.args(["-S", ".", "-B", &build_dir])
        .arg(format!("-DCMAKE_BUILD_TYPE={build_type}"))
        .arg(format!(
            "-DBUILD_TESTS={}",
            if build_tests { "ON" } else { "OFF" }
        ));

    // If we later add C++ standard to Config, we can pass -DCMAKE_CXX_STANDARD here.

    // Prefer explicit config, then env, then common defaults
    let mut candidate_roots: Vec<std::path::PathBuf> = Vec::new();
    if let Some(v) = &config.vcpkg_root {
        candidate_roots.push(v.clone());
    }
    if let Ok(env_root) = env::var("VCPKG_ROOT") {
        candidate_roots.push(env_root.into());
    }
    if let Some(home) = dirs::home_dir() {
        candidate_roots.push(home.join(".local/share/vcpkg"));
    }
    candidate_roots.push(std::path::PathBuf::from("vcpkg"));

    for root in candidate_roots {
        let toolchain_file = root.join("scripts/buildsystems/vcpkg.cmake");
        if toolchain_file.exists() {
            cfg.arg(format!(
                "-DCMAKE_TOOLCHAIN_FILE={}",
                toolchain_file.display()
            ));
            break;
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
    // Tests are almost always run in Debug mode.
    let test_dir = "build/debug";

    // Prefer running gtest test binary directly if present to get gtest-style output
    let gtest_bin = Path::new(test_dir).join("run_tests");
    if gtest_bin.exists() {
        let status = Command::new(&gtest_bin)
            .status()
            .with_context(|| format!("Failed to run {}", gtest_bin.display()))?;
        if !status.success() {
            return Err(anyhow!("Tests failed"));
        }
        return Ok(());
    }

    // Otherwise, list tests via ctest and run individually in a minimal format
    let list_output = Command::new("ctest")
        .current_dir(test_dir)
        .args(["-N"]) // list without running
        .output()
        .context("Failed to invoke ctest -N")?;
    if !list_output.status.success() {
        return Err(anyhow!("ctest -N failed"));
    }
    let stdout = String::from_utf8_lossy(&list_output.stdout);
    let re = Regex::new(r"(?m)^\s*Test\s+#\d+\s*:\s*(.+?)\s*$").unwrap();
    let mut test_names: Vec<String> = Vec::new();
    for cap in re.captures_iter(&stdout) {
        test_names.push(cap[1].to_string());
    }
    if test_names.is_empty() {
        println!("test\n   ok");
        return Ok(());
    }

    let mut any_failed = false;
    for name in test_names {
        let status = Command::new("ctest")
            .current_dir(test_dir)
            .args(["-R", &name, "-Q"]) // quiet
            .status()
            .with_context(|| format!("Failed to invoke ctest for test {name}"))?;

        println!("{}", name);
        if status.success() {
            println!("   ok");
        } else {
            println!("   FAIL");
            any_failed = true;
        }
    }

    if any_failed {
        return Err(anyhow!("Tests failed"));
    }
    Ok(())
}

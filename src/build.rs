use anyhow::{Result, anyhow, Context};
use std::{process::Command, fs};
use crate::util;

pub fn cmake_build(debug: bool) -> Result<()> {
    let build_type = if debug { "Debug" } else { "Release" };
    let build_dir = format!("build/{}", if debug { "debug" } else { "release" });
    fs::create_dir_all(&build_dir)?;

    let toolchain = util::maybe_toolchain_file()?;

    // Configure
    let mut cfg = Command::new("cmake");
    cfg.args(["-S", ".", "-B", &build_dir])
       .arg(format!("-DCMAKE_BUILD_TYPE={build_type}"));
    if let Some(tc) = toolchain {
        cfg.arg(format!("-DCMAKE_TOOLCHAIN_FILE={}", tc.display()));
    }
    let st = cfg.status().context("failed to invoke cmake (configure)")?;
    if !st.success() { return Err(anyhow!("cmake configure failed")); }

    // Build
    let st = Command::new("cmake")
        .args(["--build", &build_dir, "--"])
        .arg("-j")
        .status()
        .context("failed to invoke cmake --build")?;
    if !st.success() { return Err(anyhow!("cmake build failed")); }

    Ok(())
}

pub fn run_exe(debug: bool) -> Result<()> {
    let name = util::project_name_from_cmakelists(".")?;
    let exe = format!("build/{}/{}", if debug { "debug" } else { "release" }, name);
    let st = Command::new(&exe).status()?;
    if !st.success() { return Err(anyhow!("program exited non-zero")); }
    Ok(())
}

pub fn run_tests() -> Result<()> {
    // Prefer Debug ctest dir
    let test_dir = "build/debug";
    let st = Command::new("ctest").args(["--test-dir", test_dir, "--output-on-failure"]).status()?;
    if !st.success() { return Err(anyhow!("tests failed")); }
    Ok(())
}

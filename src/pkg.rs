use anyhow::{Result, anyhow};
use std::process::Command;
use crate::util;

pub fn add(name: &str) -> Result<()> {
    // Minimal demo: vcpkg install + naive injection.
    // TODO: parse `vcpkg x-package-info --x-json` for proper targets & find_package.
    ensure_vcpkg()?;
    let st = Command::new("vcpkg").args(["install", name]).status()?;
    if !st.success() { return Err(anyhow!("vcpkg install failed")); }

    let find_line = format!("find_package({} CONFIG REQUIRED)", name);
    let targets = format!("{}::{}", name, name);
    util::append_dep_block("cmake/dependencies.cmake", name, &find_line, &[targets])?;
    println!("✅ installed and injected: {name}");
    Ok(())
}

pub fn rm(name: &str) -> Result<()> {
    ensure_vcpkg()?;
    let st = Command::new("vcpkg").args(["remove", name]).status()?;
    if !st.success() { return Err(anyhow!("vcpkg remove failed")); }
    util::remove_dep_block("cmake/dependencies.cmake", name)?;
    println!("✅ removed: {name}");
    Ok(())
}

pub fn search(name: &str) -> Result<()> {
    ensure_vcpkg()?;
    let st = Command::new("vcpkg").args(["search", name]).status()?;
    if !st.success() { return Err(anyhow!("vcpkg search failed")); }
    Ok(())
}

fn ensure_vcpkg() -> Result<()> {
    which::which("vcpkg").map_err(|_| anyhow!("vcpkg not found; please install or export PATH"))?;
    Ok(())
}

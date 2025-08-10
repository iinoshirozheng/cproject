use anyhow::{Result, anyhow};
use which::which;
use std::env;

pub fn run() -> Result<()> {
    println!("🔎 Doctor: checking required tools");
    check("git")?;
    check("cmake")?;
    check("bash")?;
    // optional
    opt("ninja");
    opt("jq");
    opt("vcpkg");

    if let Ok(root) = env::var("VCPKG_ROOT") {
        println!("• VCPKG_ROOT = {}", root);
    } else {
        println!("• VCPKG_ROOT not set (toolchain will be skipped)");
    }
    println!("✅ Doctor finished");
    Ok(())
}

fn check(bin: &str) -> Result<()> {
    which(bin).map_err(|_| anyhow!("required tool not found: {bin}"))?;
    println!("• {} ✓", bin);
    Ok(())
}
fn opt(bin: &str) {
    if which(bin).is_ok() {
        println!("• {} ✓ (optional)", bin);
    } else {
        println!("• {} (optional) not found", bin);
    }
}

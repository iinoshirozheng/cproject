use crate::util;
use anyhow::{anyhow, Result};
use std::env;
use regex::Regex;
use std::path::PathBuf;
use std::process::Command;

pub fn add(name: &str) -> Result<()> {
    // ... (第一次安裝和 gtest 的判斷邏輯保持不變) ...
    println!("📦 First-pass: Installing '{name}' with vcpkg (output will be shown)...");
    let first_run_status = Command::new("vcpkg").args(["install", name]).status()?;
    if !first_run_status.success() {
        return Err(anyhow!("vcpkg install failed during first pass."));
    }
    println!("✅ First-pass installation complete.\n---");

    if name.to_lowercase() == "gtest" {
        println!("✅ gtest is installed and supported by default through cmake/gtest.cmake.");
        println!("   You can run tests with: cproject test");
        return Ok(());
    }

    // ... (第二次捕獲輸出的邏輯保持不變) ...
    println!("📦 Second-pass: Capturing CMake usage hints...");
    let command_to_run = format!("vcpkg install {}", name);
    let output = Command::new("script")
        .args(["-q", "/dev/null", "bash", "-c", &command_to_run])
        .output()?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!("vcpkg install failed during second pass (capturing output):\n{}", stderr));
    }
    
    let stdout_raw = String::from_utf8_lossy(&output.stdout);
    // 清理 ANSI 碼
    let ansi_re = Regex::new(r"\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]")?;
    let stdout = ansi_re.replace_all(&stdout_raw, "").to_string();

    let cmake_name = name.replace('-', "_");
    let _ = util::remove_dep_block("cmake/dependencies.cmake", name);
    if cmake_name != name {
        let _ = util::remove_dep_block("cmake/dependencies.cmake", &cmake_name);
    }
    
    // --- 修改開始: 智慧解析並產生正確的 CMake 指令 ---
    let re_find = Regex::new(r"find_package\(([^)]+)\)")?;
    let re_link = Regex::new(r"target_link_libraries\([^)]+ (PRIVATE|PUBLIC|INTERFACE) ([^)]+)\)")?;

    let find_line = re_find.captures(&stdout).map(|c| c[0].to_string());
    let link_libs: Option<Vec<String>> = re_link.captures(&stdout).map(|c| {
        c[2].split_whitespace().map(|s| s.to_string()).collect()
    });

    let injection_block = if let (Some(find), Some(libs)) = (find_line, link_libs) {
        println!("🎯 Found CMake usage hint. Constructing injection block...");
        let libs_str = libs.join(" ");
        format!("{}\nlist(APPEND THIRD_PARTY_LIBS {})", find, libs_str)
    } else {
        // --- Fallback: 如果解析失敗，使用原本的簡易注入邏輯 ---
        println!("⚠️ Could not find specific usage hint, falling back to naive injection.");
        let find_line = format!("find_package({} CONFIG REQUIRED)", cmake_name);
        let target = format!("{}::{}", cmake_name, cmake_name);
        format!("{}\nlist(APPEND THIRD_PARTY_LIBS {})", find_line, target)
    };

    util::append_dep_block("cmake/dependencies.cmake", name, &injection_block)?;
    println!("✅ Installed and injected dependency '{name}' into cmake/dependencies.cmake");

    Ok(())
}

pub fn rm(name: &str) -> Result<()> {
    ensure_vcpkg()?;
    let st = Command::new("vcpkg").args(["remove", name]).status()?;
    if !st.success() {
        return Err(anyhow!("vcpkg remove failed"));
    }
    util::remove_dep_block("cmake/dependencies.cmake", name)?;
    let cmake_name = name.replace('-', "_");
    if cmake_name != name {
        let _ = util::remove_dep_block("cmake/dependencies.cmake", &cmake_name);
    }
    println!("✅ removed: {name}");
    Ok(())
}

pub fn search(name: &str) -> Result<()> {
    ensure_vcpkg()?;
    let st = Command::new("vcpkg").args(["search", name]).status()?;
    if !st.success() {
        return Err(anyhow!("vcpkg search failed"));
    }
    Ok(())
}

fn ensure_vcpkg() -> Result<()> {
    // If vcpkg is already on PATH, we are good.
    if which::which("vcpkg").is_ok() {
        return Ok(());
    }

    // If VCPKG_ROOT is not set, attempt to setup vcpkg into a sensible default.
    let has_root = env::var("VCPKG_ROOT")
        .ok()
        .map(|p| PathBuf::from(p).exists())
        .unwrap_or(false);
    if !has_root {
        println!("VCPKG_ROOT not set; setting up vcpkg...");
        vcpkg_setup(None)?;
    }

    // After setup, try to add VCPKG_ROOT to PATH for this process so child Commands can find it.
    if let Ok(root) = env::var("VCPKG_ROOT") {
        let root_path = PathBuf::from(&root);
        let vcpkg_bin = root_path.join("vcpkg");
        if vcpkg_bin.exists() {
            let old_path = env::var("PATH").unwrap_or_default();
            let new_path = format!("{}:{}", root_path.display(), old_path);
            env::set_var("PATH", new_path);
        }
    }

    // Final check
    which::which("vcpkg").map_err(|_| {
        anyhow!("vcpkg not found; please install or export PATH (or run: cproject pkg setup)")
    })?;
    Ok(())
}

/// Clone and bootstrap vcpkg at the provided path (or a sensible default)
pub fn vcpkg_setup(path: Option<&str>) -> Result<()> {
    use std::fs;
    let target_root: PathBuf = if let Some(p) = path {
        PathBuf::from(p)
    } else if let Ok(env_root) = std::env::var("VCPKG_ROOT") {
        PathBuf::from(env_root)
    } else {
        // default user-local location
        let mut p = dirs::home_dir().ok_or_else(|| anyhow!("cannot resolve home directory"))?;
        p.push(".local/share/vcpkg");
        p
    };

    if !target_root.exists() {
        println!("Cloning vcpkg into {}...", target_root.display());
        fs::create_dir_all(
            target_root
                .parent()
                .unwrap_or_else(|| std::path::Path::new(".")),
        )?;
        let status = Command::new("git")
            .args([
                "clone",
                "https://github.com/microsoft/vcpkg",
                target_root.to_str().unwrap(),
            ])
            .status()?;
        if !status.success() {
            return Err(anyhow!("git clone vcpkg failed"));
        }
    } else {
        println!("vcpkg directory exists at {}", target_root.display());
    }

    // Bootstrap
    let bootstrap = target_root.join("bootstrap-vcpkg.sh");
    if bootstrap.exists() {
        let status = Command::new("bash")
            .arg(bootstrap)
            .arg("-disableMetrics")
            .current_dir(&target_root)
            .status()?;
        if !status.success() {
            return Err(anyhow!("bootstrap-vcpkg.sh failed"));
        }
    } else {
        // On Windows it would be bootstrap-vcpkg.bat, but we are on macOS per user env
        println!(
            "Warning: bootstrap-vcpkg.sh not found at {}",
            bootstrap.display()
        );
    }

    // Make vcpkg discoverable for the current process
    env::set_var("VCPKG_ROOT", &target_root);
    let old_path = env::var("PATH").unwrap_or_default();
    env::set_var("PATH", format!("{}:{}", target_root.display(), old_path));

    println!("✅ vcpkg is ready at {}", target_root.display());
    println!(
        "Hint: set VCPKG_ROOT or configure cproject.toml with vcpkg-root = \"{}\"",
        target_root.display()
    );
    Ok(())
}

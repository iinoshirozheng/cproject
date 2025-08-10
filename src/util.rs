use anyhow::{anyhow, Result};
use regex::Regex;
use std::{fs, path::PathBuf};

pub fn project_name_from_cmakelists(dir: &str) -> Result<String> {
    let path = PathBuf::from(dir).join("CMakeLists.txt");
    let s = fs::read_to_string(&path)
        .map_err(|e| anyhow!("failed to read {}: {}", path.display(), e))?;
    let re = Regex::new(r#"(?m)^\s*project\(\s*([A-Za-z0-9_\-]+)"#)?;
    if let Some(cap) = re.captures(&s) {
        Ok(cap[1].to_string())
    } else {
        Err(anyhow!("cannot parse project name from CMakeLists.txt"))
    }
}

#[allow(dead_code)]
pub fn maybe_toolchain_file() -> Result<Option<PathBuf>> {
    // Use VCPKG_ROOT if available
    if let Ok(root) = std::env::var("VCPKG_ROOT") {
        let p = PathBuf::from(root).join("scripts/buildsystems/vcpkg.cmake");
        if p.exists() {
            return Ok(Some(p));
        }
    }
    // Also try local vcpkg submodule in repo root
    let p = PathBuf::from("vcpkg/scripts/buildsystems/vcpkg.cmake");
    if p.exists() {
        return Ok(Some(p));
    }
    Ok(None)
}

// Append/remove dependency blocks in cmake/dependencies.cmake
pub fn append_dep_block(file: &str, name: &str, find_pkg: &str, targets: &[String]) -> Result<()> {
    use std::fmt::Write as _;
    let mut s = String::new();
    if let Ok(existing) = fs::read_to_string(file) {
        s = existing;
    } else {
        // initialize the file with a baseline
        s.push_str("set(THIRD_PARTY_LIBS)\n");
    }
    writeln!(
        &mut s,
        "\n# === {n} START ===\n{fp}\nlist(APPEND THIRD_PARTY_LIBS {tg})\n# === {n} END ===",
        n = name,
        fp = find_pkg,
        tg = targets.join(" ")
    )?;
    fs::create_dir_all(std::path::Path::new(file).parent().unwrap())?;
    fs::write(file, s)?;
    Ok(())
}

pub fn remove_dep_block(file: &str, name: &str) -> Result<()> {
    let s = fs::read_to_string(file)?;
    let pat = format!(r"(?s)# === {0} START ===.*?# === {0} END ===\n?", name);
    let re = Regex::new(&pat)?;
    fs::write(file, re.replace(&s, "").to_string())?;
    Ok(())
}

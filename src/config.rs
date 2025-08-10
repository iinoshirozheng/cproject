// src/config.rs

use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// 應用程式的頂層組態
#[derive(Deserialize, Debug, Default)]
#[serde(rename_all = "kebab-case")]
pub struct Config {
    pub vcpkg_root: Option<PathBuf>,

    #[serde(default)]
    pub templates: Templates,

    #[serde(default)]
    pub archetypes: HashMap<String, String>,
}

/// 模板來源設定
#[derive(Deserialize, Debug, Default)]
pub struct Templates {
    #[serde(default)]
    pub locations: Vec<PathBuf>,
}

impl Config {
    /// 載入組態。
    /// 優先讀取目前目錄的 .cproject.toml，若無則讀取家目錄的設定。
    pub fn load() -> Result<Self> {
        let from_current_dir = PathBuf::from("./.cproject.toml");
        let from_home = dirs::home_dir().map(|p| p.join(".config/cproject/cproject.toml"));

        let config_path = if from_current_dir.exists() {
            Some(from_current_dir)
        } else if let Some(home_path) = from_home {
            if home_path.exists() {
                Some(home_path)
            } else {
                None
            }
        } else {
            None
        };

        if let Some(path) = config_path {
            println!("🔎 Loading config from: {}", path.display());
            let content = fs::read_to_string(&path)
                .with_context(|| format!("Failed to read config file at {}", path.display()))?;

            let mut config: Config = toml::from_str(&content)
                .with_context(|| format!("Failed to parse TOML from {}", path.display()))?;

            // 展開 home 路徑 (~)
            config.expand_paths()?;
            return Ok(config);
        }

        // 若找不到任何組態檔，回傳一個預設的 Config
        println!("🔎 No config file found, using default settings.");
        Ok(Config::default())
    }

    /// 將組態中的 `~` 符號展開為家目錄的絕對路徑
    fn expand_paths(&mut self) -> Result<()> {
        if let Some(vcpkg_root) = &self.vcpkg_root {
            if vcpkg_root.starts_with("~") {
                self.vcpkg_root = Some(
                    shellexpand::tilde(vcpkg_root.to_str().unwrap())
                        .into_owned()
                        .into(),
                );
            }
        }

        for loc in self.templates.locations.iter_mut() {
            if loc.starts_with("~") {
                *loc = shellexpand::tilde(loc.to_str().unwrap())
                    .into_owned()
                    .into();
            }
        }

        Ok(())
    }
}

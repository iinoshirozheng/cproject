// src/archetype.rs

use crate::config::Config;
use anyhow::{anyhow, Context, Result};
use handlebars::Handlebars;
use serde::Deserialize;
use serde_json::json;
use shlex::Shlex;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Deserialize, Debug)]
struct ArchetypeConfig {
    #[allow(dead_code)]
    description: String,
    #[serde(default)]
    variables: HashMap<String, ArchetypeVariable>,
    #[serde(default)]
    hooks: Hooks,
}

#[derive(Deserialize, Debug)]
struct ArchetypeVariable {
    prompt: String,
    default: Option<String>,
}

#[derive(Deserialize, Debug, Default)]
struct Hooks {
    #[serde(default)]
    post_create: PostCreateHooks,
}

#[derive(Deserialize, Debug, Default)]
struct PostCreateHooks {
    #[serde(default)]
    commands: Vec<String>,
}

/// 代表一個已載入記憶體的專案原型
pub struct Archetype {
    pub name: String,
    config: ArchetypeConfig,
    template_path: PathBuf,
}

impl Archetype {
    /// 從組態和原型名稱載入
    pub fn load(app_config: &Config, name: &str) -> Result<Self> {
        // Build candidate relative paths for the archetype
        let mut candidates: Vec<String> = Vec::new();
        if let Some(mapped) = app_config.archetypes.get(name) {
            candidates.push(mapped.clone());
        }
        // Built-in aliases for convenience when config is missing
        match name {
            "app" | "exe" | "executable" => candidates.push("default/executable".to_string()),
            "lib" | "library" => candidates.push("default/library".to_string()),
            _ => {}
        }
        // Also allow direct folder name usage
        candidates.push(name.to_string());

        // 在所有模板位置中尋找原型
        let mut template_locations = app_config.templates.locations.clone();
        // 將內建模板位置加入搜尋路徑
        template_locations.push(PathBuf::from("./templates"));

        let mut final_template_path: Option<PathBuf> = None;

        'outer: for loc in &template_locations {
            for rel in &candidates {
                let potential_path = loc.join(rel);
                if potential_path.exists() {
                    final_template_path = Some(potential_path);
                    break 'outer;
                }
            }
        }

        let template_path = final_template_path
            .ok_or_else(|| anyhow!("Could not find template directory for archetype '{}'", name))?;

        let archetype_config_path = template_path.join("archetype.toml");
        let content =
            fs::read_to_string(&archetype_config_path).context("Failed to read archetype.toml")?;
        let config: ArchetypeConfig =
            toml::from_str(&content).context("Failed to parse archetype.toml")?;

        Ok(Archetype {
            name: name.to_string(),
            config,
            template_path,
        })
    }

    /// 實例化原型，生成專案
    pub fn instantiate(
        &self,
        project_name: &str,
        destination: &Path,
        use_defaults: bool,
    ) -> Result<()> {
        if destination.exists() {
            return Err(anyhow!(
                "Destination '{}' already exists",
                destination.display()
            ));
        }
        fs::create_dir_all(destination)?;

        // 1. 收集變數
        let context_data = if use_defaults {
            self.collect_variables_with_defaults(project_name)?
        } else {
            self.collect_variables_interactively(project_name)?
        };

        // 2. 渲染模板
        println!("🚀 Rendering template for '{}'...", self.name);
        self.render_template_dir(destination, &context_data)?;

        // 3. 執行鉤子
        println!("🎣 Running post-create hooks...");
        self.run_hooks(destination, &context_data)?;

        println!(
            "🎉 Project '{}' created successfully at {}",
            project_name,
            destination.display()
        );

        Ok(())
    }

    /// 透過互動式提示收集使用者輸入的變數
    fn collect_variables_interactively(&self, project_name: &str) -> Result<serde_json::Value> {
        let mut context = HashMap::new();
        context.insert("name".to_string(), json!(project_name));
        context.insert(
            "year".to_string(),
            json!(chrono::Utc::now().format("%Y").to_string()),
        );

        println!("Please provide the following details for your project:");
        for (key, var_info) in &self.config.variables {
            // Ensure reserved keys are not overridden by template variables
            if key == "name" || key == "year" {
                continue;
            }
            // 簡易的互動式輸入，可以使用 `dialoguer` crate 來優化
            println!(
                "▶️ {} (default: {}):",
                var_info.prompt,
                var_info.default.as_deref().unwrap_or("")
            );
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            let value = input.trim();

            if value.is_empty() {
                context.insert(key.clone(), json!(var_info.default));
            } else {
                context.insert(key.clone(), json!(value));
            }
        }
        Ok(json!(context))
    }

    /// 使用預設值自動填入變數（非互動）
    fn collect_variables_with_defaults(&self, project_name: &str) -> Result<serde_json::Value> {
        let mut context = HashMap::new();
        context.insert("name".to_string(), json!(project_name));
        context.insert(
            "year".to_string(),
            json!(chrono::Utc::now().format("%Y").to_string()),
        );

        for (key, var_info) in &self.config.variables {
            if key == "name" || key == "year" {
                continue;
            }
            context.insert(
                key.clone(),
                json!(var_info.default.clone().unwrap_or_default()),
            );
        }
        Ok(json!(context))
    }

    fn render_template_dir(&self, dest_path: &Path, context: &serde_json::Value) -> Result<()> {
        let hbs = Handlebars::new();
        let walker = walkdir::WalkDir::new(&self.template_path).into_iter();

        for entry in walker.filter_map(Result::ok) {
            let src_path = entry.path();
            if src_path == self.template_path
                || src_path.file_name().unwrap_or_default() == "archetype.toml"
            {
                continue;
            }

            let rel_path = src_path.strip_prefix(&self.template_path)?;
            let rendered_rel_path_str =
                hbs.render_template(&rel_path.to_string_lossy(), context)?;
            let dest_file_path = dest_path.join(PathBuf::from(rendered_rel_path_str));

            if entry.file_type().is_dir() {
                fs::create_dir_all(&dest_file_path)?;
            } else {
                if let Some(parent) = dest_file_path.parent() {
                    fs::create_dir_all(parent)?;
                }

                // 將所有文字檔案內容當作模板渲染；二進位檔案直接複製
                let is_hbs = src_path.extension().map_or(false, |e| e == "hbs");
                let bytes = fs::read(src_path)?;
                if let Ok(template_str) = String::from_utf8(bytes) {
                    let rendered_content = hbs.render_template(&template_str, context)?;
                    let final_path = if is_hbs {
                        dest_file_path.with_extension("")
                    } else {
                        dest_file_path.clone()
                    };
                    fs::write(final_path, rendered_content)?;
                } else {
                    // binary: just copy
                    fs::copy(src_path, &dest_file_path)?;
                }
            }
        }
        Ok(())
    }

    fn run_hooks(&self, working_dir: &Path, context: &serde_json::Value) -> Result<()> {
        let hbs = Handlebars::new();
        for cmd_template in &self.config.hooks.post_create.commands {
            let cmd_str = hbs.render_template(cmd_template, context)?;
            println!("  -> Executing: `{}`", cmd_str);
            let mut lexer = Shlex::new(&cmd_str);
            let parts: Vec<String> = lexer.by_ref().collect();
            let program = parts
                .get(0)
                .ok_or_else(|| anyhow!("Empty command in hooks"))?;
            let args: Vec<&str> = parts.iter().skip(1).map(|s| s.as_str()).collect();

            let status = Command::new(program)
                .args(args)
                .current_dir(working_dir)
                .status()
                .with_context(|| format!("Failed to execute hook command: {}", cmd_str))?;

            if !status.success() {
                return Err(anyhow!("Hook command failed: {}", cmd_str));
            }
        }
        Ok(())
    }
}

use anyhow::{Result, anyhow};
use rust_embed::RustEmbed;
use handlebars::Handlebars;
use serde_json::json;
use std::{path::{Path, PathBuf}, fs};

#[derive(RustEmbed)]
#[folder = "assets/templates"]
struct Templates;

pub fn create_project(name: &str, is_lib: bool) -> Result<()> {
    let dst = PathBuf::from(name);
    if dst.exists() {
        return Err(anyhow!("destination '{}' already exists", name));
    }
    let flavor = if is_lib { "cpp/single/library" } else { "cpp/single/executable" };
    let ctx = json!({
        "name": name,
        "year": chrono::Utc::now().format("%Y").to_string(),
    });
    render_dir(flavor, &dst, &ctx)?;
    println!("🎉 Created project at {}", dst.display());
    Ok(())
}

fn render_dir(flavor: &str, dst: &Path, ctx: &serde_json::Value) -> Result<()> {
    fs::create_dir_all(dst)?;
    let mut hbs = Handlebars::new();
    for f in Templates::iter() {
        let path = f.as_ref();
        if !path.starts_with(flavor) { continue; }
        // strip the flavor prefix -> relative template path
        let mut rel = path.strip_prefix(flavor).unwrap().trim_start_matches('/').to_string();

        // render filename segments (support {{name}} in filenames)
        rel = hbs.render_template(&rel, ctx)?;

        // read file contents
        let contents = Templates::get(path).expect("embedded template").data;
        let text = std::str::from_utf8(&contents).ok()
            .map(|s| hbs.render_template(s, ctx)).transpose()?;

        let out = dst.join(rel);
        if let Some(parent) = out.parent() { fs::create_dir_all(parent)?; }
        if let Some(text) = text {
            fs::write(&out, text)?;
        } else {
            // binary (not used here), just write bytes
            fs::write(&out, &contents)?;
        }
    }
    Ok(())
}

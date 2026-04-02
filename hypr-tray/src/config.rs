use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::PathBuf;

/// The Hyprland special workspace used to hold hidden windows.
pub const TRAY_WORKSPACE: &str = "special:󰘸";

#[derive(Debug, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub apps: HashMap<String, AppConfig>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub command: Option<String>,
    pub class: String,
    #[allow(dead_code)] // used in config but not read by daemon
    #[serde(default = "default_icon")]
    pub icon: String,
    #[serde(default)]
    pub has_tray: bool,
    #[serde(default)]
    pub restart: bool,
}

fn default_icon() -> String {
    "application-x-executable".into()
}

impl Config {
    pub fn load() -> Result<Self> {
        let path = config_path();
        if path.exists() {
            let content = std::fs::read_to_string(&path).context("failed to read config")?;
            toml::from_str(&content).context("failed to parse config")
        } else {
            Ok(Self {
                apps: HashMap::new(),
            })
        }
    }

    /// Find the app entry whose class matches.
    pub fn find_by_class(&self, class: &str) -> Option<(&str, &AppConfig)> {
        self.apps
            .iter()
            .find(|(_, a)| a.class == class)
            .map(|(n, a)| (n.as_str(), a))
    }

}

pub fn config_path() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| {
            log::warn!("XDG_CONFIG_HOME not set, using ~/.config");
            PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/tmp".into())).join(".config")
        })
        .join("hypr-tray")
        .join("config.toml")
}

use anyhow::{Context, Result};
use serde::Deserialize;
use std::env;
use std::path::PathBuf;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::net::UnixStream;
use tokio::process::Command;

// ── hyprctl wrappers ────────────────────────────────────────────────────────

async fn hyprctl(args: &[&str]) -> Result<String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .await
        .context("failed to run hyprctl")?;
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

pub async fn keyword(args: &[&str]) -> Result<()> {
    let mut cmd = vec!["keyword"];
    cmd.extend_from_slice(args);
    hyprctl(&cmd).await?;
    Ok(())
}

pub async fn keyword_remove(args: &[&str]) -> Result<()> {
    let mut cmd = vec!["keyword", "-r"];
    cmd.extend_from_slice(args);
    hyprctl(&cmd).await?;
    Ok(())
}

#[derive(Debug, Default, Deserialize)]
pub struct WorkspaceRef {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct ClientInfo {
    pub class: String,
    pub address: String,
    pub workspace: WorkspaceRef,
}

pub async fn list_clients() -> Result<Vec<ClientInfo>> {
    let json = hyprctl(&["clients", "-j"]).await?;
    Ok(serde_json::from_str(&json)?)
}

// ── Hyprland event socket ───────────────────────────────────────────────────

fn socket2_path() -> Result<PathBuf> {
    let runtime = env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR not set")?;
    let sig =
        env::var("HYPRLAND_INSTANCE_SIGNATURE").context("HYPRLAND_INSTANCE_SIGNATURE not set")?;
    Ok(PathBuf::from(runtime)
        .join("hypr")
        .join(sig)
        .join(".socket2.sock"))
}

#[derive(Debug)]
pub enum Event {
    Opened {
        addr: String,
        class: String,
    },
    Closed {
        addr: String,
    },
}

fn parse_event(line: &str) -> Option<Event> {
    let (name, data) = line.split_once(">>")?;
    match name {
        "openwindow" => {
            let mut parts = data.splitn(4, ',');
            Some(Event::Opened {
                addr: format!("0x{}", parts.next()?),
                class: { parts.next()?; parts.next()?.to_string() },
            })
        }
        "closewindow" if !data.is_empty() => Some(Event::Closed {
            addr: format!("0x{}", data),
        }),
        _ => None,
    }
}

pub async fn event_listener(tx: tokio::sync::mpsc::Sender<Event>) -> Result<()> {
    let path = socket2_path()?;
    let stream = UnixStream::connect(&path)
        .await
        .with_context(|| format!("connect to {}", path.display()))?;
    let mut lines = BufReader::new(stream).lines();

    while let Some(line) = lines.next_line().await? {
        if let Some(event) = parse_event(&line)
            && tx.send(event).await.is_err()
        {
            break;
        }
    }
    Ok(())
}

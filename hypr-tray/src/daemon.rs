use crate::config::{self, Config};
use crate::hyprland::{self, Event};
use anyhow::Result;
use std::collections::{HashMap, HashSet};
use tokio::process::Command;
use tokio::sync::mpsc;

struct ManagedApp {
    command: Option<String>,
    restart: bool,
    class: String,
}

struct WindowRecord {
    app_name: String,
}

/// Signal waybar to refresh the tray module.
fn signal_waybar() {
    let _ = std::process::Command::new("pkill")
        .args(["-RTMIN+10", "waybar"])
        .spawn();
}

/// Add a temporary window rule to send new windows of this class directly to tray.
async fn add_tray_rule(class: &str) {
    let rule = format!("workspace {},class:^({})$", config::TRAY_WORKSPACE, class);
    let _ = hyprland::keyword(&["windowrulev2", &rule]).await;
}

/// Remove the temporary tray window rule.
async fn remove_tray_rule(class: &str) {
    let rule = format!("workspace {},class:^({})$", config::TRAY_WORKSPACE, class);
    let _ = hyprland::keyword_remove(&["windowrulev2", &rule]).await;
}

pub async fn run() -> Result<()> {
    let config = Config::load()?;
    let mut apps: HashMap<String, ManagedApp> = HashMap::new();
    let mut windows: HashMap<String, WindowRecord> = HashMap::new();

    // Apps whose next window should be moved to the tray workspace
    let mut pending_tray: HashSet<String> = HashSet::new();

    // Channel for child process exits
    let (child_tx, mut child_rx) = mpsc::channel::<String>(16);

    // Fetch existing windows once for both setup and registration
    let existing_clients = hyprland::list_clients().await.unwrap_or_default();

    // Set up managed apps: register and launch processes
    for (name, app_cfg) in config.apps.iter().filter(|(_, a)| !a.has_tray) {
        apps.insert(
            name.to_string(),
            ManagedApp {
                command: app_cfg.command.clone(),
                restart: app_cfg.restart,
                class: app_cfg.class.clone(),
            },
        );

        let already_running = existing_clients.iter().any(|c| c.class == app_cfg.class);

        if !already_running && let Some(cmd) = &app_cfg.command {
            pending_tray.insert(name.to_string());
            add_tray_rule(&app_cfg.class).await;
            spawn_app(name, cmd, child_tx.clone());
        }
    }

    // Register existing windows for tracking
    for client in &existing_clients {
        if let Some((name, _)) = config.find_by_class(&client.class) {
            windows.insert(
                client.address.clone(),
                WindowRecord {
                    app_name: name.to_string(),
                },
            );
        }
    }

    // Start Hyprland event listener with reconnect
    let (event_tx, mut event_rx) = mpsc::channel(64);
    tokio::spawn(async move {
        loop {
            match hyprland::event_listener(event_tx.clone()).await {
                Ok(()) => {
                    log::warn!("event listener disconnected, reconnecting...");
                }
                Err(e) => {
                    log::error!("event listener error: {e}, retrying in 2s...");
                }
            }
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        }
    });

    log::info!("hypr-tray daemon started, managing {} apps", apps.len());

    // Main event loop
    loop {
        tokio::select! {
            Some(event) = event_rx.recv() => {
                handle_event(&event, &config, &apps, &mut windows, &mut pending_tray, &child_tx).await;
            }
            Some(name) = child_rx.recv() => {
                log::info!("{name} process exited");
                if let Some(app) = apps.get(&name)
                    && app.restart
                    && let Some(cmd) = &app.command
                {
                    log::info!("restarting {name} → tray");
                    pending_tray.insert(name.clone());
                    add_tray_rule(&app.class).await;
                    spawn_app(&name, cmd, child_tx.clone());
                }
            }
            _ = tokio::signal::ctrl_c() => {
                log::info!("shutting down");
                break;
            }
        }
    }

    Ok(())
}

async fn handle_event(
    event: &Event,
    config: &Config,
    apps: &HashMap<String, ManagedApp>,
    windows: &mut HashMap<String, WindowRecord>,
    pending_tray: &mut HashSet<String>,
    child_tx: &mpsc::Sender<String>,
) {
    match event {
        Event::Opened { addr, class } => {
            if let Some((name, _)) = config.find_by_class(class) {
                log::debug!("tracked window opened: {name} ({class}) at {addr}");
                windows.insert(
                    addr.clone(),
                    WindowRecord {
                        app_name: name.to_string(),
                    },
                );

                // Remove temporary rule now that the window has opened in tray
                if pending_tray.remove(name) {
                    if let Some(app) = apps.get(name) {
                        remove_tray_rule(&app.class).await;
                    }
                    signal_waybar();
                }
            }
        }
        Event::Closed { addr } => {
            if let Some(record) = windows.remove(addr) {
                log::debug!("tracked window closed: {}", record.app_name);
                let has_other = windows.values().any(|w| w.app_name == record.app_name);
                if !has_other
                    && let Some(app) = apps.get(&record.app_name)
                    && app.restart
                    && let Some(cmd) = &app.command
                {
                    log::info!("restarting {} → tray", record.app_name);
                    pending_tray.insert(record.app_name.clone());
                    add_tray_rule(&app.class).await;
                    spawn_app(&record.app_name, cmd, child_tx.clone());
                }
                signal_waybar();
            }
        }
    }
}

fn spawn_app(name: &str, command: &str, tx: mpsc::Sender<String>) {
    let name = name.to_string();
    let command = command.to_string();
    tokio::spawn(async move {
        let Some(parts) = shlex::split(&command) else {
            log::error!("failed to parse command for {name}: {command}");
            let _ = tx.send(name).await;
            return;
        };
        if parts.is_empty() {
            log::error!("empty command for {name}");
            let _ = tx.send(name).await;
            return;
        }
        match Command::new(&parts[0]).args(&parts[1..]).spawn() {
            Ok(mut child) => {
                let _ = child.wait().await;
                let _ = tx.send(name).await;
            }
            Err(e) => {
                log::error!("failed to spawn {name}: {e}");
                let _ = tx.send(name).await;
            }
        }
    });
}

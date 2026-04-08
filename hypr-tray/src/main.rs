use anyhow::Result;
use clap::{Parser, Subcommand};

mod config;
mod daemon;
mod hyprland;

#[derive(Parser)]
#[command(
    name = "hypr-tray",
    about = "Process supervisor and tray workspace manager for Hyprland"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the daemon (process supervision, auto-restart to tray)
    Daemon,
    /// Output JSON for waybar custom module
    Waybar,
    /// List managed apps and their state
    Status,
    /// Close active window, or hide it to tray if it's a managed app
    CloseOrHide,
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Daemon => daemon::run().await,
        Commands::Waybar => cmd_waybar().await,
        Commands::Status => cmd_status().await,
        Commands::CloseOrHide => cmd_close_or_hide().await,
    }
}

async fn cmd_waybar() -> Result<()> {
    let config = config::Config::load()?;
    let clients = hyprland::list_clients().await?;

    let hidden: Vec<&str> = clients
        .iter()
        .filter(|c| c.workspace.name == config::TRAY_WORKSPACE)
        .filter_map(|c| {
            config
                .find_by_class(&c.class)
                .filter(|(_, app)| !app.has_tray)
                .map(|(name, _)| name)
        })
        .collect();

    if hidden.is_empty() {
        println!("{{}}");
    } else {
        let tooltip = hidden.join(", ");
        let tooltip = tooltip.replace('"', "\\\"");
        println!(
            "{{\"text\": \"󰘸 {}\", \"tooltip\": \"{}\", \"class\": \"has-hidden\"}}",
            hidden.len(),
            tooltip
        );
    }
    Ok(())
}

async fn cmd_status() -> Result<()> {
    let config = config::Config::load()?;
    let clients = hyprland::list_clients().await?;

    println!(
        "{:<15} {:<20} {:<10} {:<10} {:<10}",
        "NAME", "CLASS", "STATE", "WINDOWS", "TRAY"
    );
    println!("{}", "─".repeat(68));

    for (name, app) in &config.apps {
        let tray_type = if app.has_tray { "native" } else { "managed" };
        let hidden_count = clients
            .iter()
            .filter(|c| c.class == app.class && c.workspace.name == config::TRAY_WORKSPACE)
            .count();
        let visible_count = clients
            .iter()
            .filter(|c| c.class == app.class && c.workspace.name != config::TRAY_WORKSPACE)
            .count();

        let state = if hidden_count > 0 && visible_count > 0 {
            "mixed"
        } else if hidden_count > 0 {
            "hidden"
        } else if visible_count > 0 {
            "visible"
        } else {
            "stopped"
        };

        let window_info = if hidden_count + visible_count > 0 {
            format!("{}v/{}h", visible_count, hidden_count)
        } else {
            "-".to_string()
        };

        println!(
            "{:<15} {:<20} {:<10} {:<10} {:<10}",
            name, app.class, state, window_info, tray_type
        );
    }

    Ok(())
}

async fn cmd_close_or_hide() -> Result<()> {
    let config = config::Config::load()?;
    let active = hyprland::active_window().await?;

    if let Some((_, app)) = config.find_by_class(&active.class) {
        if !app.has_tray {
            // Managed app — hide to tray instead of closing
            let arg = format!("{},address:{}", config::TRAY_WORKSPACE, active.address);
            hyprland::dispatch(&["movetoworkspacesilent", &arg]).await?;
            signal_waybar();
            return Ok(());
        }
    }

    // Not a managed app — normal close
    hyprland::dispatch(&["killactive"]).await?;
    Ok(())
}

fn signal_waybar() {
    daemon::signal_waybar();
}

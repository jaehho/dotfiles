# battery-log

README.md covers install, use and how it works; PRODUCT.md is the design brief for the `ui/` window (impeccable).

- **Tauri command args are camelCase:** `#[tauri::command]` defaults to `ArgumentCase::Camel` (`invoke("cmd", { fromMin: 1 })` matches Rust `from_min`), and mismatched snake_case keys fail silently; verify against installed `tauri-macros` source when unsure.

///|
priv struct CatalogPlugin {
  name : String
  load : () -> @lepusa.Plugin
}

///|
pub fn plugin(name : String) -> @lepusa.Plugin? {
  for entry in catalog_plugins() {
    if entry.name == name {
      return Some((entry.load)())
    }
  }
  None
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  plugin_name : String,
) -> @lepusa.CommandRegistry {
  register_with_filesystem_scopes(registry, plugin_name, scopes=[])
}

///|
pub fn register_with_filesystem_scopes(
  registry : @lepusa.CommandRegistry,
  plugin_name : String,
  scopes~ : Array[@lepusa.FileSystemScope],
) -> @lepusa.CommandRegistry {
  match plugin_name {
    "log" => @log.register(registry)
    "store" => @store.register(registry)
    "fs" =>
      @fs_plugin.register(registry, policy=@fs_plugin.FsPolicy::new(scopes~))
    _ => registry
  }
}

///|
pub fn registered_plugin_names() -> Array[String] {
  ["fs", "log", "store"]
}

///|
pub fn plugin_names() -> Array[String] {
  catalog_plugins().map(fn(entry) { entry.name })
}

///|
fn catalog_plugins() -> Array[CatalogPlugin] {
  [
    { name: "autoLaunch", load: fn() { @auto_launch.plugin() } },
    { name: "clipboard", load: fn() { @clipboard.plugin() } },
    { name: "deepLink", load: fn() { @deep_link.plugin() } },
    { name: "dialog", load: fn() { @dialog.plugin() } },
    { name: "fileDialog", load: fn() { @file_dialog.plugin() } },
    { name: "fs", load: fn() { @fs_plugin.plugin() } },
    { name: "localhost", load: fn() { @localhost.plugin() } },
    { name: "log", load: fn() { @log.plugin() } },
    { name: "notification", load: fn() { @notification.plugin() } },
    { name: "opener", load: fn() { @opener.plugin() } },
    { name: "process", load: fn() { @process.plugin() } },
    { name: "serviceDiscovery", load: fn() { @service_discovery.plugin() } },
    { name: "shell", load: fn() { @shell.plugin() } },
    { name: "singleInstance", load: fn() { @single_instance.plugin() } },
    { name: "store", load: fn() { @store.plugin() } },
    { name: "tray", load: fn() { @tray.plugin() } },
    { name: "updater", load: fn() { @updater.plugin() } },
    { name: "windowState", load: fn() { @window_state.plugin() } },
  ]
}

///|
pub fn plugin(name : String) -> @lepusa.Plugin? {
  match name {
    "clipboard" => Some(@clipboard.plugin())
    "dialog" => Some(@dialog.plugin())
    "fileDialog" => Some(@file_dialog.plugin())
    "log" => Some(@log.plugin())
    "notification" => Some(@notification.plugin())
    "opener" => Some(@opener.plugin())
    "process" => Some(@process.plugin())
    "shell" => Some(@shell.plugin())
    "store" => Some(@store.plugin())
    "fs" => Some(@fs_plugin.plugin())
    _ => None
  }
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  plugin_name : String,
) -> @lepusa.CommandRegistry {
  match plugin_name {
    "log" => @log.register(registry)
    "store" => @store.register(registry)
    _ => registry
  }
}

///|
pub fn registered_plugin_names() -> Array[String] {
  ["log", "store"]
}

///|
pub fn plugin_names() -> Array[String] {
  [
    "clipboard", "dialog", "fileDialog", "fs", "log", "notification", "opener", "process",
    "shell", "store",
  ]
}

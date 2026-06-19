///|
pub fn plugin(name : String) -> @lepusa.Plugin? {
  match name {
    "clipboard" => Some(@clipboard.plugin())
    "dialog" => Some(@dialog.plugin())
    "log" => Some(@log.plugin())
    "notification" => Some(@notification.plugin())
    "opener" => Some(@opener.plugin())
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
    "clipboard", "dialog", "fs", "log", "notification", "opener", "shell", "store",
  ]
}

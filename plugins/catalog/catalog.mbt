///|
pub fn plugin(name : String) -> @lepusa.Plugin? {
  match name {
    "log" => Some(@log.plugin())
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
  ["fs", "log", "store"]
}

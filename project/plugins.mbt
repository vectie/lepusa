///|
fn project_registry_from_plugins(
  plugins : Array[@lepusa.Plugin],
  filesystem_scopes~ : Array[@lepusa.FileSystemScope],
  local_services? : Array[@lepusa.LocalService] = [],
) -> @lepusa.CommandRegistry {
  let mut registry = @lepusa.CommandRegistry::new()
  let context = @catalog.CatalogContext::new(
    filesystem_scopes~,
    local_services~,
  )
  for plugin in plugins {
    registry = @catalog.register_with_context(registry, plugin.name(), context~)
  }
  registry
}

///|
fn project_plugins_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> Array[@lepusa.Plugin] {
  let plugins : Array[@lepusa.Plugin] = []
  match optional_config_array(object, "plugins") {
    Some(items) =>
      for item in items {
        match item {
          Object(plugin_object) =>
            plugins.push(plugin_from_object(plugin_object, problems))
          _ => problems.push("project plugins entries must be objects")
        }
      }
    None => ()
  }
  plugins
}

///|
fn plugin_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.Plugin {
  let name = required_config_string(object, "name", problems)
  let mut plugin = @lepusa.Plugin::new(name)
  match optional_config_array(object, "commands") {
    Some(commands) =>
      for command in commands {
        plugin = plugin_command_from_json(plugin, command, problems)
      }
    None =>
      match @catalog.plugin(name) {
        Some(official) => plugin = official
        None => ()
      }
  }
  plugin
}

///|
fn plugin_command_from_json(
  plugin : @lepusa.Plugin,
  json : Json,
  problems : Array[String],
) -> @lepusa.Plugin {
  match json {
    String(name) => plugin.command_sync(name)
    Object(object) => {
      let name = required_config_string(object, "name", problems)
      let mode = optional_config_string(object, "mode").unwrap_or("sync")
      let permission = command_permission_from_object(
        object,
        route="\{plugin.name()}.\{name}",
        problems,
      )
      match mode {
        "sync" => plugin.command_sync(name, permission?)
        "async" => plugin.command_async(name, permission?)
        "stream" => plugin.command_stream(name, permission?)
        "event" => plugin.command_event(name, permission?)
        value => {
          problems.push("unknown plugin command mode: \{value}")
          plugin.command_sync(name, permission?)
        }
      }
    }
    _ => {
      problems.push("project plugin commands must be strings or objects")
      plugin
    }
  }
}

///|
fn command_permission_from_object(
  object : Map[String, Json],
  route~ : String,
  problems : Array[String],
) -> @lepusa.Permission? {
  match optional_config_string(object, "permission") {
    Some(name) =>
      match permission_from_string(name, problems) {
        Some(permission) => Some(permission)
        None => Some(@lepusa.Permission::command(route))
      }
    None => None
  }
}

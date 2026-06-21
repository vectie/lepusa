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
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.Plugin] {
  let plugins : Array[@lepusa.Plugin] = []
  match optional_config_array(object, "plugins") {
    Some(items) =>
      for item in items {
        match item {
          Object(plugin_object) =>
            plugins.push(plugin_from_object(plugin_object, base_dir~, problems))
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
  base_dir~ : String,
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
  plugin = plugin_lifecycle_from_object(plugin, object, base_dir~, problems)
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
      let affinity = command_affinity_from_object(object, problems)
      let permission = command_permission_from_object(
        object,
        route="\{plugin.name()}.\{name}",
        problems,
      )
      let request = command_schema_from_object(
        object, "requestSchema", problems,
      )
      let response = command_schema_from_object(
        object, "responseSchema", problems,
      )
      match mode {
        "sync" =>
          plugin.command_sync(name, permission?, request?, response?, affinity~)
        "async" =>
          plugin.command_async(
            name,
            permission?,
            request?,
            response?,
            affinity~,
          )
        "stream" =>
          plugin.command_stream(
            name,
            permission?,
            request?,
            response?,
            affinity~,
          )
        "event" =>
          plugin.command_event(
            name,
            permission?,
            request?,
            response?,
            affinity~,
          )
        value => {
          problems.push("unknown plugin command mode: \{value}")
          plugin.command_sync(name, permission?, request?, response?, affinity~)
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
fn command_affinity_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.CommandExecutionAffinity {
  match optional_config_string(object, "affinity") {
    Some(value) =>
      match value {
        "main-thread" => MainThread
        "worker-thread" => WorkerThread
        "any-thread" => AnyThread
        _ => {
          problems.push("unknown plugin command affinity: \{value}")
          AnyThread
        }
      }
    None => AnyThread
  }
}

///|
fn command_schema_from_object(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> @lepusa.IpcSchema? {
  match object.get(key) {
    Some(Object(schema)) => {
      let name = required_config_string(schema, "name", problems)
      let typescript = required_config_string(schema, "typescript", problems)
      let description = optional_config_string(schema, "description").unwrap_or(
        "",
      )
      Some(@lepusa.IpcSchema::new(name~, typescript~, description~))
    }
    Some(_) => {
      problems.push("project \{key} must be an object")
      None
    }
    None => None
  }
}

///|
fn plugin_lifecycle_from_object(
  plugin : @lepusa.Plugin,
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Plugin {
  let mut plugin = plugin
  match optional_config_array(object, "lifecycle") {
    Some(items) =>
      for item in items {
        plugin = plugin_lifecycle_hook_from_json(
          plugin,
          item,
          base_dir~,
          problems,
        )
      }
    None => ()
  }
  plugin
}

///|
fn plugin_lifecycle_hook_from_json(
  plugin : @lepusa.Plugin,
  json : Json,
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Plugin {
  match json {
    Object(object) => {
      let event = required_config_string(object, "event", problems)
      let command = match object.get("command") {
        Some(command_json) =>
          command_from_json(
            command_json,
            "plugin lifecycle command",
            base_dir~,
            problems,
          )
        None => {
          problems.push("project plugin lifecycle command is required")
          @lepusa.Cmd::batch([])
        }
      }
      match event {
        "setup" => plugin.on_setup(command)
        "ready" => plugin.on_ready(command)
        "will-exit" => plugin.on_will_exit(command)
        value => {
          problems.push("unknown plugin lifecycle event: \{value}")
          plugin
        }
      }
    }
    _ => {
      problems.push("project plugin lifecycle entries must be objects")
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

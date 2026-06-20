///|
pub struct DesktopKit {
  plugins : Array[@lepusa.Plugin]
  capabilities : Array[@lepusa.Capability]
  filesystem_scopes : Array[@lepusa.FileSystemScope]
  local_services : Array[@lepusa.LocalService]
  problems : Array[String]
}

///|
pub fn DesktopKit::new() -> DesktopKit {
  {
    plugins: [],
    capabilities: [],
    filesystem_scopes: [],
    local_services: [],
    problems: [],
  }
}

///|
pub fn DesktopKit::with_plugin(
  self : DesktopKit,
  name : String,
  window_label? : String = "main",
  capability_name? : String = "",
) -> DesktopKit {
  match @catalog.plugin(name) {
    None => self.with_problem("unknown official plugin: \{name}")
    Some(plugin) => {
      let next = self.with_plugin_spec(plugin)
      let name = capability_name_if_empty(capability_name, plugin.name())
      next.with_capability(plugin_capability(plugin, name~, window_label~))
    }
  }
}

///|
pub fn DesktopKit::with_plugins(
  self : DesktopKit,
  names : Array[String],
  window_label? : String = "main",
) -> DesktopKit {
  let mut kit = self
  for name in names {
    kit = kit.with_plugin(name, window_label~)
  }
  kit
}

///|
pub fn DesktopKit::with_plugin_spec(
  self : DesktopKit,
  plugin : @lepusa.Plugin,
) -> DesktopKit {
  if self.plugin_names().contains(plugin.name()) {
    self
  } else {
    let plugins = self.plugins.copy()
    plugins.push(plugin)
    { ..self, plugins, }
  }
}

///|
pub fn DesktopKit::with_capability(
  self : DesktopKit,
  capability : @lepusa.Capability,
) -> DesktopKit {
  if self.capability_names().contains(capability.name()) {
    self
  } else {
    let capabilities = self.capabilities.copy()
    capabilities.push(capability)
    { ..self, capabilities, }
  }
}

///|
pub fn DesktopKit::with_filesystem_scope(
  self : DesktopKit,
  scope : @lepusa.FileSystemScope,
) -> DesktopKit {
  let scopes = self.filesystem_scopes.copy()
  scopes.push(scope)
  { ..self, filesystem_scopes: scopes }
}

///|
pub fn DesktopKit::with_local_service(
  self : DesktopKit,
  service : @lepusa.LocalService,
) -> DesktopKit {
  let services = self.local_services.copy()
  services.push(service)
  { ..self, local_services: services }
}

///|
pub fn DesktopKit::plugins(self : DesktopKit) -> Array[@lepusa.Plugin] {
  self.plugins.copy()
}

///|
pub fn DesktopKit::plugin_names(self : DesktopKit) -> Array[String] {
  self.plugins.map(fn(plugin) { plugin.name() })
}

///|
pub fn DesktopKit::capabilities(self : DesktopKit) -> Array[@lepusa.Capability] {
  self.capabilities.copy()
}

///|
pub fn DesktopKit::capability_names(self : DesktopKit) -> Array[String] {
  self.capabilities.map(fn(capability) { capability.name() })
}

///|
pub fn DesktopKit::filesystem_scopes(
  self : DesktopKit,
) -> Array[@lepusa.FileSystemScope] {
  self.filesystem_scopes.copy()
}

///|
pub fn DesktopKit::local_services(
  self : DesktopKit,
) -> Array[@lepusa.LocalService] {
  self.local_services.copy()
}

///|
pub fn DesktopKit::problems(self : DesktopKit) -> Array[String] {
  self.problems.copy()
}

///|
pub fn DesktopKit::validate(self : DesktopKit) -> Array[String] {
  let problems = self.problems.copy()
  let seen_plugins : Array[String] = []
  for plugin in self.plugins {
    for problem in plugin.validate() {
      problems.push(problem)
    }
    if plugin.name() != "" {
      if seen_plugins.contains(plugin.name()) {
        problems.push("desktop plugin must be unique: \{plugin.name()}")
      } else {
        seen_plugins.push(plugin.name())
      }
    }
  }
  let seen_capabilities : Array[String] = []
  for capability in self.capabilities {
    for problem in capability.validate() {
      problems.push(problem)
    }
    if capability.name() != "" {
      if seen_capabilities.contains(capability.name()) {
        problems.push("desktop capability must be unique: \{capability.name()}")
      } else {
        seen_capabilities.push(capability.name())
      }
    }
  }
  for scope in self.filesystem_scopes {
    for problem in scope.validate() {
      problems.push(problem)
    }
  }
  for service in self.local_services {
    for problem in service.validate() {
      problems.push(problem)
    }
  }
  problems
}

///|
pub fn DesktopKit::registry(self : DesktopKit) -> @lepusa.CommandRegistry {
  let context = @catalog.CatalogContext::new(
    filesystem_scopes=self.filesystem_scopes,
    local_services=self.local_services,
  )
  let mut registry = @lepusa.CommandRegistry::new()
  for plugin in self.plugins {
    registry = @catalog.register_with_context(registry, plugin.name(), context~)
  }
  registry
}

///|
pub fn DesktopKit::registered_routes(self : DesktopKit) -> Array[String] {
  self.registry().routes()
}

///|
pub fn DesktopKit::apply(
  self : DesktopKit,
  app : @lepusa.App,
) -> Result[@lepusa.App, Array[String]] {
  let problems = self.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  let mut next = app
  for plugin in self.plugins {
    next = next.with_plugin(plugin)
  }
  for capability in self.capabilities {
    next = next.with_capability(capability)
  }
  Ok(next)
}

///|
pub fn DesktopKit::runtime_host(
  self : DesktopKit,
  plan : @lepusa.RuntimePlan,
) -> Result[@runtime.RuntimeHost, Array[String]] {
  let problems = self.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  let registry = self.registry()
  let registry_problems = registry.validate()
  if !registry_problems.is_empty() {
    return Err(registry_problems)
  }
  Ok(@runtime.RuntimeHost::new(plan, registry~))
}

///|
fn DesktopKit::with_problem(self : DesktopKit, problem : String) -> DesktopKit {
  let problems = self.problems.copy()
  problems.push(problem)
  { ..self, problems, }
}

///|
fn plugin_capability(
  plugin : @lepusa.Plugin,
  name~ : String,
  window_label~ : String,
) -> @lepusa.Capability {
  let mut capability = @lepusa.Capability::new(name)
  if window_label != "" {
    capability = capability.window(window_label)
  }
  let permissions : Array[@lepusa.Permission] = []
  for command in plugin.commands() {
    let permission = command.permission()
    if !permissions.contains(permission) {
      permissions.push(permission)
      capability = capability.permission(permission)
    }
  }
  capability
}

///|
fn capability_name_if_empty(name : String, fallback : String) -> String {
  if name == "" {
    fallback
  } else {
    name
  }
}

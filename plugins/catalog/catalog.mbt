///|
priv struct CatalogPlugin {
  name : String
  load : () -> @lepusa.Plugin
}

///|
priv struct CatalogRegistration {
  name : String
  register : (@lepusa.CommandRegistry, CatalogContext) -> @lepusa.CommandRegistry
}

///|
pub struct CatalogContext {
  filesystem_scopes : Array[@lepusa.FileSystemScope]
  local_services : Array[@lepusa.LocalService]
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
  register_with_context(registry, plugin_name, context=CatalogContext::new())
}

///|
pub fn register_with_filesystem_scopes(
  registry : @lepusa.CommandRegistry,
  plugin_name : String,
  scopes~ : Array[@lepusa.FileSystemScope],
) -> @lepusa.CommandRegistry {
  register_with_context(
    registry,
    plugin_name,
    context=CatalogContext::new(filesystem_scopes=scopes),
  )
}

///|
pub fn register_with_context(
  registry : @lepusa.CommandRegistry,
  plugin_name : String,
  context~ : CatalogContext,
) -> @lepusa.CommandRegistry {
  for entry in catalog_registrations() {
    if entry.name == plugin_name {
      return (entry.register)(registry, context)
    }
  }
  registry
}

///|
pub fn CatalogContext::new(
  filesystem_scopes? : Array[@lepusa.FileSystemScope] = [],
  local_services? : Array[@lepusa.LocalService] = [],
) -> CatalogContext {
  {
    filesystem_scopes: filesystem_scopes.copy(),
    local_services: local_services.copy(),
  }
}

///|
pub fn CatalogContext::filesystem_scopes(
  self : CatalogContext,
) -> Array[@lepusa.FileSystemScope] {
  self.filesystem_scopes.copy()
}

///|
pub fn CatalogContext::local_services(
  self : CatalogContext,
) -> Array[@lepusa.LocalService] {
  self.local_services.copy()
}

///|
pub fn registered_plugin_names() -> Array[String] {
  catalog_registrations().map(fn(entry) { entry.name })
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

///|
fn catalog_registrations() -> Array[CatalogRegistration] {
  [
    {
      name: "fs",
      register: fn(registry, context) {
        @fs_plugin.register(
          registry,
          policy=@fs_plugin.FsPolicy::new(scopes=context.filesystem_scopes()),
        )
      },
    },
    {
      name: "clipboard",
      register: fn(registry, _) { @clipboard.register(registry) },
    },
    {
      name: "deepLink",
      register: fn(registry, _) { @deep_link.register(registry) },
    },
    { name: "dialog", register: fn(registry, _) { @dialog.register(registry) } },
    { name: "log", register: fn(registry, _) { @log.register(registry) } },
    {
      name: "localhost",
      register: fn(registry, context) {
        @localhost.register(
          registry,
          policy=@localhost.LocalhostPolicy::new(
            services=context.local_services(),
          ),
        )
      },
    },
    {
      name: "notification",
      register: fn(registry, _) { @notification.register(registry) },
    },
    { name: "opener", register: fn(registry, _) { @opener.register(registry) } },
    {
      name: "process",
      register: fn(registry, _) { @process.register(registry) },
    },
    {
      name: "serviceDiscovery",
      register: fn(registry, context) {
        @service_discovery.register(
          registry,
          policy=@service_discovery.ServiceDiscoveryPolicy::from_local_services(
            context.local_services(),
          ),
        )
      },
    },
    { name: "shell", register: fn(registry, _) { @shell.register(registry) } },
    {
      name: "singleInstance",
      register: fn(registry, _) { @single_instance.register(registry) },
    },
    { name: "store", register: fn(registry, _) { @store.register(registry) } },
    {
      name: "windowState",
      register: fn(registry, _) { @window_state.register(registry) },
    },
  ]
}

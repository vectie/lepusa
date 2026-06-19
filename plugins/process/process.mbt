///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("process")
  .command_sync("info", permission=ProcessInfo)
  .command_sync("cwd", permission=ProcessInfo)
  .command_async("env", permission=ProcessEnvironment)
  .command_async("setEnv", permission=ProcessEnvironment)
  .command_async("exit", permission=ProcessControl)
}

///|
pub fn info_capability(name? : String = "process-info") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessInfo)
}

///|
pub fn environment_capability(
  name? : String = "process-environment",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessEnvironment)
}

///|
pub fn control_capability(
  name? : String = "process-control",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessControl)
}

///|
pub fn capability(name? : String = "process") -> @lepusa.Capability {
  @lepusa.Capability::new(name)
  .permission(ProcessInfo)
  .permission(ProcessEnvironment)
  .permission(ProcessControl)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "process",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

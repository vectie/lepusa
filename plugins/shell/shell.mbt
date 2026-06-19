///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("shell")
  .command_async("execute", permission=Shell)
  .command_async("spawn", permission=Shell)
  .command_async("kill", permission=Shell)
  .command_async("stdinWrite", permission=Shell)
}

///|
pub fn capability(name? : String = "shell") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Shell)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "shell",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

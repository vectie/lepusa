///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("opener")
  .command_async("openUrl", permission=Opener)
  .command_async("openPath", permission=Opener)
  .command_async("revealPath", permission=Opener)
}

///|
pub fn capability(name? : String = "opener") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Opener)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "opener",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

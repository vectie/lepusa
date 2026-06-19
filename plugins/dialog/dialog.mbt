///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("dialog")
  .command_async("message", permission=Dialog)
  .command_async("confirm", permission=Dialog)
  .command_async("prompt", permission=Dialog)
}

///|
pub fn capability(name? : String = "dialog") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Dialog)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "dialog",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

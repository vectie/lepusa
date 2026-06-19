///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("clipboard")
  .command_async("readText", permission=Clipboard)
  .command_async("writeText", permission=Clipboard)
  .command_async("clear", permission=Clipboard)
}

///|
pub fn capability(name? : String = "clipboard") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Clipboard)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "clipboard",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

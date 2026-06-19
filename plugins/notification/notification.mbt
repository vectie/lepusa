///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("notification")
  .command_async("show", permission=Notification)
  .command_async("permissionState", permission=Notification)
  .command_async("requestPermission", permission=Notification)
}

///|
pub fn capability(name? : String = "notification") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Notification)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "notification",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct SingleInstancePolicy {
  key : String
  primary_window : String?
  forward_args : Bool
  forward_urls : Bool
} derive(Debug, Eq)

///|
pub fn SingleInstancePolicy::new(
  key~ : String,
  primary_window? : String,
  forward_args? : Bool = true,
  forward_urls? : Bool = true,
) -> SingleInstancePolicy {
  { key, primary_window, forward_args, forward_urls }
}

///|
pub fn SingleInstancePolicy::key(self : SingleInstancePolicy) -> String {
  self.key
}

///|
pub fn SingleInstancePolicy::primary_window(
  self : SingleInstancePolicy,
) -> String? {
  self.primary_window
}

///|
pub fn SingleInstancePolicy::forward_args(self : SingleInstancePolicy) -> Bool {
  self.forward_args
}

///|
pub fn SingleInstancePolicy::forward_urls(self : SingleInstancePolicy) -> Bool {
  self.forward_urls
}

///|
pub fn SingleInstancePolicy::validate(
  self : SingleInstancePolicy,
) -> Array[String] {
  let problems : Array[String] = []
  if self.key == "" {
    problems.push("single instance key is required")
  } else if invalid_key(self.key) {
    problems.push("single instance key is invalid: \{self.key}")
  }
  match self.primary_window {
    Some(label) =>
      if label == "" {
        problems.push("single instance primary window is required")
      }
    None => ()
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("singleInstance")
  .command_async("status", permission=SingleInstance)
  .command_async("acquire", permission=SingleInstance)
  .command_async("release", permission=SingleInstance)
  .command_async("focus", permission=SingleInstance)
  .command_event("onSecondLaunch", permission=SingleInstance)
}

///|
pub fn capability(name? : String = "single-instance") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(SingleInstance)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "single-instance",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn invalid_key(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

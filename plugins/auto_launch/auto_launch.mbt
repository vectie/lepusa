///|
pub struct AutoLaunchPolicy {
  name : String
  executable : String?
  arguments : Array[String]
  open_hidden : Bool
} derive(Debug, Eq)

///|
pub fn AutoLaunchPolicy::new(
  name~ : String,
  executable? : String,
  arguments? : Array[String] = [],
  open_hidden? : Bool = false,
) -> AutoLaunchPolicy {
  { name, executable, arguments, open_hidden }
}

///|
pub fn AutoLaunchPolicy::name(self : AutoLaunchPolicy) -> String {
  self.name
}

///|
pub fn AutoLaunchPolicy::executable(self : AutoLaunchPolicy) -> String? {
  self.executable
}

///|
pub fn AutoLaunchPolicy::arguments(self : AutoLaunchPolicy) -> Array[String] {
  self.arguments.copy()
}

///|
pub fn AutoLaunchPolicy::open_hidden(self : AutoLaunchPolicy) -> Bool {
  self.open_hidden
}

///|
pub fn AutoLaunchPolicy::argument(
  self : AutoLaunchPolicy,
  argument : String,
) -> AutoLaunchPolicy {
  let arguments = self.arguments.copy()
  arguments.push(argument)
  { ..self, arguments, }
}

///|
pub fn AutoLaunchPolicy::validate(self : AutoLaunchPolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("auto launch name is required")
  } else if invalid_name(self.name) {
    problems.push("auto launch name is invalid: \{self.name}")
  }
  match self.executable {
    Some("") => problems.push("auto launch executable is required")
    Some(path) =>
      if path.contains("\\") {
        problems.push("auto launch executable must use forward slashes")
      }
    None => ()
  }
  for argument in self.arguments {
    if argument == "" {
      problems.push("auto launch argument is required")
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("autoLaunch")
  .command_async("status", permission=AutoLaunch)
  .command_async("enable", permission=AutoLaunch)
  .command_async("disable", permission=AutoLaunch)
  .command_async("setEnabled", permission=AutoLaunch)
}

///|
pub fn capability(name? : String = "auto-launch") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(AutoLaunch)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "auto-launch",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn invalid_name(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains("\t") ||
  value.contains("\n")
}

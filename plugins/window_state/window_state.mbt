///|
pub struct WindowStateRule {
  window_label : String
  remember_size : Bool
  remember_position : Bool
  remember_visibility : Bool
} derive(Debug, Eq)

///|
pub struct WindowStatePolicy {
  store_name : String
  rules : Array[WindowStateRule]
} derive(Debug, Eq)

///|
pub fn WindowStateRule::new(
  window_label~ : String,
  remember_size? : Bool = true,
  remember_position? : Bool = true,
  remember_visibility? : Bool = false,
) -> WindowStateRule {
  { window_label, remember_size, remember_position, remember_visibility }
}

///|
pub fn WindowStateRule::window_label(self : WindowStateRule) -> String {
  self.window_label
}

///|
pub fn WindowStateRule::remember_size(self : WindowStateRule) -> Bool {
  self.remember_size
}

///|
pub fn WindowStateRule::remember_position(self : WindowStateRule) -> Bool {
  self.remember_position
}

///|
pub fn WindowStateRule::remember_visibility(self : WindowStateRule) -> Bool {
  self.remember_visibility
}

///|
pub fn WindowStateRule::validate(self : WindowStateRule) -> Array[String] {
  let problems : Array[String] = []
  if self.window_label == "" {
    problems.push("window state label is required")
  } else if invalid_key(self.window_label) {
    problems.push("window state label is invalid: \{self.window_label}")
  }
  if !self.remember_size && !self.remember_position && !self.remember_visibility {
    problems.push("window state rule must remember at least one property")
  }
  problems
}

///|
pub fn WindowStatePolicy::new(
  store_name~ : String,
  rules? : Array[WindowStateRule] = [],
) -> WindowStatePolicy {
  { store_name, rules }
}

///|
pub fn WindowStatePolicy::store_name(self : WindowStatePolicy) -> String {
  self.store_name
}

///|
pub fn WindowStatePolicy::rules(
  self : WindowStatePolicy,
) -> Array[WindowStateRule] {
  self.rules.copy()
}

///|
pub fn WindowStatePolicy::rule(
  self : WindowStatePolicy,
  rule : WindowStateRule,
) -> WindowStatePolicy {
  let rules = self.rules.copy()
  rules.push(rule)
  { ..self, rules, }
}

///|
pub fn WindowStatePolicy::validate(self : WindowStatePolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.store_name == "" {
    problems.push("window state store name is required")
  } else if invalid_key(self.store_name) {
    problems.push("window state store name is invalid: \{self.store_name}")
  }
  let seen : Array[String] = []
  for rule in self.rules {
    problems.append(rule.validate())
    let label = rule.window_label()
    if label != "" {
      if seen.contains(label) {
        problems.push("window state rule must be unique: \{label}")
      } else {
        seen.push(label)
      }
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("windowState")
  .command_async("save", permission=WindowState)
  .command_async("restore", permission=WindowState)
  .command_async("clear", permission=WindowState)
  .command_async("get", permission=WindowState)
  .command_async("set", permission=WindowState)
}

///|
pub fn capability(name? : String = "window-state") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(WindowState)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "window-state",
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

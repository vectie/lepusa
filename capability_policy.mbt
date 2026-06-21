///|
pub struct CapabilityDecision {
  allowed : Bool
  window_label : String
  origin : String
  permission : Permission
  capability : String
  reason : String
} derive(Debug, Eq)

///|
fn CapabilityDecision::allow(
  window_label~ : String,
  origin~ : String,
  permission~ : Permission,
  capability~ : String,
) -> CapabilityDecision {
  { allowed: true, window_label, origin, permission, capability, reason: "" }
}

///|
fn CapabilityDecision::deny(
  window_label~ : String,
  origin~ : String,
  permission~ : Permission,
  reason~ : String,
) -> CapabilityDecision {
  { allowed: false, window_label, origin, permission, capability: "", reason }
}

///|
pub fn CapabilityDecision::allowed(self : CapabilityDecision) -> Bool {
  self.allowed
}

///|
pub fn CapabilityDecision::denied(self : CapabilityDecision) -> Bool {
  !self.allowed
}

///|
pub fn CapabilityDecision::window_label(self : CapabilityDecision) -> String {
  self.window_label
}

///|
pub fn CapabilityDecision::origin(self : CapabilityDecision) -> String {
  self.origin
}

///|
pub fn CapabilityDecision::permission(self : CapabilityDecision) -> Permission {
  self.permission
}

///|
pub fn CapabilityDecision::capability(self : CapabilityDecision) -> String {
  self.capability
}

///|
pub fn CapabilityDecision::reason(self : CapabilityDecision) -> String {
  self.reason
}

///|
pub fn CapabilityDecision::to_json(self : CapabilityDecision) -> String {
  [
    "{",
    "\"allowed\":\{capability_bool_json(self.allowed)},",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"origin\":\{self.origin.json_string()},",
    "\"permission\":\{self.permission.name().json_string()},",
    "\"capability\":\{self.capability.json_string()},",
    "\"reason\":\{self.reason.json_string()}",
    "}",
  ].join("")
}

///|
pub struct CapabilityPolicy {
  capabilities : Array[Capability]
} derive(Debug, Eq)

///|
pub fn CapabilityPolicy::new(
  capabilities? : Array[Capability] = [],
) -> CapabilityPolicy {
  { capabilities: capabilities.copy() }
}

///|
pub fn CapabilityPolicy::capabilities(
  self : CapabilityPolicy,
) -> Array[Capability] {
  self.capabilities.copy()
}

///|
pub fn CapabilityPolicy::allows(
  self : CapabilityPolicy,
  window_label~ : String,
  permission~ : Permission,
  origin? : String = "",
) -> Bool {
  self.evaluate(window_label~, permission~, origin~).allowed()
}

///|
pub fn CapabilityPolicy::allows_window(
  self : CapabilityPolicy,
  window_label~ : String,
  permission~ : Permission,
) -> Bool {
  for capability in self.capabilities {
    let window_allowed = capability.windows().is_empty() ||
      capability.windows().contains(window_label)
    if window_allowed && capability.permissions().contains(permission) {
      return true
    }
  }
  false
}

///|
pub fn CapabilityPolicy::evaluate(
  self : CapabilityPolicy,
  window_label~ : String,
  permission~ : Permission,
  origin? : String = "",
) -> CapabilityDecision {
  for capability in self.capabilities {
    if capability.allows(window_label~, permission~, origin~) {
      return CapabilityDecision::allow(
        window_label~,
        origin~,
        permission~,
        capability=capability.name(),
      )
    }
  }
  CapabilityDecision::deny(
    window_label~,
    origin~,
    permission~,
    reason=capability_deny_reason(window_label, origin, permission),
  )
}

///|
pub fn CapabilityPolicy::allowed_origins(
  self : CapabilityPolicy,
  window_label~ : String,
  permission~ : Permission,
) -> Array[String] {
  let origins : Array[String] = []
  for capability in self.capabilities {
    let window_allowed = capability.windows().is_empty() ||
      capability.windows().contains(window_label)
    if window_allowed && capability.permissions().contains(permission) {
      let capability_origins = capability.origins()
      if capability_origins.is_empty() {
        return []
      }
      for origin in capability_origins {
        if !origins.contains(origin) {
          origins.push(origin)
        }
      }
    }
  }
  origins
}

///|
pub fn CapabilityPolicy::validate(self : CapabilityPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for capability in self.capabilities {
    for problem in capability.validate() {
      problems.push(problem)
    }
    if capability.name() != "" {
      if seen.contains(capability.name()) {
        problems.push("capability name must be unique: \{capability.name()}")
      } else {
        seen.push(capability.name())
      }
    }
  }
  problems
}

///|
pub fn CapabilityPolicy::to_json(self : CapabilityPolicy) -> String {
  [
    "{",
    "\"capabilities\":[\{self.capabilities.map(fn(capability) { capability_policy_capability_json(capability) }).join(",")}]",
    "}",
  ].join("")
}

///|
fn capability_deny_reason(
  window_label : String,
  origin : String,
  permission : Permission,
) -> String {
  if origin == "" {
    "permission denied for window \{window_label}: \{permission.name()}"
  } else {
    "permission denied for window \{window_label} origin \{origin}: \{permission.name()}"
  }
}

///|
fn capability_policy_capability_json(capability : Capability) -> String {
  [
    "{",
    "\"name\":\{capability.name().json_string()},",
    "\"windows\":[\{capability.windows().map(fn(window) { window.json_string() }).join(",")}],",
    "\"origins\":[\{capability.origins().map(fn(origin) { origin.json_string() }).join(",")}],",
    "\"permissions\":[\{capability.permissions().map(fn(permission) { permission.name().json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn capability_bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

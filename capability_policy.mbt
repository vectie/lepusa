///|
pub struct CapabilityDecision {
  allowed : Bool
  window_label : String
  permission : Permission
  capability : String
  reason : String
} derive(Debug, Eq)

///|
fn CapabilityDecision::allow(
  window_label~ : String,
  permission~ : Permission,
  capability~ : String,
) -> CapabilityDecision {
  { allowed: true, window_label, permission, capability, reason: "" }
}

///|
fn CapabilityDecision::deny(
  window_label~ : String,
  permission~ : Permission,
  reason~ : String,
) -> CapabilityDecision {
  { allowed: false, window_label, permission, capability: "", reason }
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
) -> Bool {
  self.evaluate(window_label~, permission~).allowed()
}

///|
pub fn CapabilityPolicy::evaluate(
  self : CapabilityPolicy,
  window_label~ : String,
  permission~ : Permission,
) -> CapabilityDecision {
  for capability in self.capabilities {
    if capability.allows(window_label~, permission~) {
      return CapabilityDecision::allow(
        window_label~,
        permission~,
        capability=capability.name(),
      )
    }
  }
  CapabilityDecision::deny(
    window_label~,
    permission~,
    reason=capability_deny_reason(window_label, permission),
  )
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
  permission : Permission,
) -> String {
  "permission denied for window \{window_label}: \{permission.name()}"
}

///|
fn capability_policy_capability_json(capability : Capability) -> String {
  [
    "{",
    "\"name\":\{capability.name().json_string()},",
    "\"windows\":[\{capability.windows().map(fn(window) { window.json_string() }).join(",")}],",
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

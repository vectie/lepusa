///|
pub struct DeepLinkScheme {
  scheme : String
  hosts : Array[String]
} derive(Debug, Eq)

///|
pub struct DeepLinkPolicy {
  schemes : Array[DeepLinkScheme]
} derive(Debug, Eq)

///|
pub fn DeepLinkScheme::new(
  scheme~ : String,
  hosts? : Array[String] = [],
) -> DeepLinkScheme {
  { scheme, hosts }
}

///|
pub fn DeepLinkScheme::scheme(self : DeepLinkScheme) -> String {
  self.scheme
}

///|
pub fn DeepLinkScheme::hosts(self : DeepLinkScheme) -> Array[String] {
  self.hosts.copy()
}

///|
pub fn DeepLinkScheme::validate(self : DeepLinkScheme) -> Array[String] {
  let problems : Array[String] = []
  if self.scheme == "" {
    problems.push("deep link scheme is required")
  } else if invalid_scheme(self.scheme) {
    problems.push("deep link scheme is invalid: \{self.scheme}")
  }
  for host in self.hosts {
    if host == "" {
      problems.push("deep link host is required")
    } else if invalid_host(host) {
      problems.push("deep link host is invalid: \{host}")
    }
  }
  problems
}

///|
pub fn DeepLinkPolicy::new(
  schemes? : Array[DeepLinkScheme] = [],
) -> DeepLinkPolicy {
  { schemes, }
}

///|
pub fn DeepLinkPolicy::scheme(
  self : DeepLinkPolicy,
  scheme : DeepLinkScheme,
) -> DeepLinkPolicy {
  let schemes = self.schemes.copy()
  schemes.push(scheme)
  { schemes, }
}

///|
pub fn DeepLinkPolicy::schemes(self : DeepLinkPolicy) -> Array[DeepLinkScheme] {
  self.schemes.copy()
}

///|
pub fn DeepLinkPolicy::scheme_names(self : DeepLinkPolicy) -> Array[String] {
  let names : Array[String] = []
  for scheme in self.schemes {
    names.push(scheme.scheme())
  }
  names
}

///|
pub fn DeepLinkPolicy::validate(self : DeepLinkPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for scheme in self.schemes {
    problems.append(scheme.validate())
    let name = scheme.scheme()
    if name != "" {
      if seen.contains(name) {
        problems.push("deep link scheme must be unique: \{name}")
      } else {
        seen.push(name)
      }
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("deepLink")
  .command_async("getInitialUrls", permission=DeepLink)
  .command_event("onOpenUrl", permission=DeepLink)
  .command_async("register", permission=DeepLink)
  .command_async("unregister", permission=DeepLink)
  .command_async("openUrl", permission=DeepLink)
}

///|
pub fn capability(name? : String = "deep-link") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(DeepLink)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "deep-link",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn invalid_scheme(value : String) -> Bool {
  value.contains(":") ||
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

///|
fn invalid_host(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

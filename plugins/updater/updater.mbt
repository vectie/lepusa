///|
pub struct UpdaterPolicy {
  feed_url : String
  channel : String
  public_key : String?
  allow_prerelease : Bool
} derive(Debug, Eq)

///|
pub fn UpdaterPolicy::new(
  feed_url~ : String,
  channel? : String = "stable",
  public_key? : String,
  allow_prerelease? : Bool = false,
) -> UpdaterPolicy {
  { feed_url, channel, public_key, allow_prerelease }
}

///|
pub fn UpdaterPolicy::feed_url(self : UpdaterPolicy) -> String {
  self.feed_url
}

///|
pub fn UpdaterPolicy::channel(self : UpdaterPolicy) -> String {
  self.channel
}

///|
pub fn UpdaterPolicy::public_key(self : UpdaterPolicy) -> String? {
  self.public_key
}

///|
pub fn UpdaterPolicy::allow_prerelease(self : UpdaterPolicy) -> Bool {
  self.allow_prerelease
}

///|
pub fn UpdaterPolicy::validate(self : UpdaterPolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.feed_url == "" {
    problems.push("updater feed url is required")
  } else if !self.feed_url.has_prefix("https://") {
    problems.push("updater feed url must use https")
  }
  if self.channel == "" {
    problems.push("updater channel is required")
  } else if invalid_channel(self.channel) {
    problems.push("updater channel is invalid: \{self.channel}")
  }
  match self.public_key {
    Some("") => problems.push("updater public key is required")
    _ => ()
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("updater")
  .command_async("check", permission=Updater)
  .command_async("download", permission=Updater)
  .command_async("install", permission=Updater)
  .command_async("downloadAndInstall", permission=Updater)
  .command_async("restart", permission=Updater)
  .command_event("onUpdateAvailable", permission=Updater)
}

///|
pub fn capability(name? : String = "updater") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Updater)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "updater",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn invalid_channel(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

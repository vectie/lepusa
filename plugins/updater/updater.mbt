///|
pub struct UpdaterPolicy {
  feed_url : String
  channel : String
  public_key : String?
  allow_prerelease : Bool
} derive(Debug, Eq)

///|
pub struct UpdaterState {
  mut update_available : Bool
  mut version : String?
  mut downloaded : Bool
  mut installed : Bool
  mut restart_requested : Bool
  mut last_action : String
} derive(Debug, Eq)

///|
priv struct UpdaterRequest {
  update_available : Bool?
  version : String?
}

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
pub fn UpdaterState::new(
  update_available? : Bool = false,
  version? : String,
) -> UpdaterState {
  {
    update_available,
    version,
    downloaded: false,
    installed: false,
    restart_requested: false,
    last_action: "check",
  }
}

///|
pub fn UpdaterState::update_available(self : UpdaterState) -> Bool {
  self.update_available
}

///|
pub fn UpdaterState::version(self : UpdaterState) -> String? {
  self.version
}

///|
pub fn UpdaterState::downloaded(self : UpdaterState) -> Bool {
  self.downloaded
}

///|
pub fn UpdaterState::installed(self : UpdaterState) -> Bool {
  self.installed
}

///|
pub fn UpdaterState::restart_requested(self : UpdaterState) -> Bool {
  self.restart_requested
}

///|
pub fn UpdaterState::last_action(self : UpdaterState) -> String {
  self.last_action
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
pub fn registry(
  policy? : UpdaterPolicy = UpdaterPolicy::new(
    feed_url="https://updates.example.invalid/lepusa.json",
  ),
  state? : UpdaterState = UpdaterState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : UpdaterPolicy = UpdaterPolicy::new(
    feed_url="https://updates.example.invalid/lepusa.json",
  ),
  state? : UpdaterState = UpdaterState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("updater.check", permission=Updater, handler=payload => {
    handle_check(policy, state, payload)
  })
  .register_async_fn("updater.download", permission=Updater, handler=payload => {
    handle_download(policy, state, payload)
  })
  .register_async_fn("updater.install", permission=Updater, handler=payload => {
    handle_install(policy, state, payload)
  })
  .register_async_fn("updater.downloadAndInstall", permission=Updater, handler=payload => {
    handle_download_and_install(policy, state, payload)
  })
  .register_async_fn("updater.restart", permission=Updater, handler=_ => {
    handle_restart(policy, state)
  })
}

///|
async fn handle_check(
  policy : UpdaterPolicy,
  state : UpdaterState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match validate_and_decode(policy, payload, context="updater check") {
    Ok(request) => {
      apply_request(state, request)
      state.last_action = "check"
      Ok(updater_json(policy, state, status="delegated").stringify())
    }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_download(
  policy : UpdaterPolicy,
  state : UpdaterState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match validate_and_decode(policy, payload, context="updater download") {
    Ok(request) => {
      apply_request(state, request)
      state.downloaded = true
      state.last_action = "download"
      Ok(updater_json(policy, state, status="delegated").stringify())
    }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_install(
  policy : UpdaterPolicy,
  state : UpdaterState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match validate_and_decode(policy, payload, context="updater install") {
    Ok(request) => {
      apply_request(state, request)
      state.installed = true
      state.last_action = "install"
      Ok(updater_json(policy, state, status="delegated").stringify())
    }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_download_and_install(
  policy : UpdaterPolicy,
  state : UpdaterState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match
    validate_and_decode(policy, payload, context="updater downloadAndInstall") {
    Ok(request) => {
      apply_request(state, request)
      state.downloaded = true
      state.installed = true
      state.last_action = "downloadAndInstall"
      Ok(updater_json(policy, state, status="delegated").stringify())
    }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_restart(
  policy : UpdaterPolicy,
  state : UpdaterState,
) -> Result[String, String] {
  @async.sleep(0)
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None => {
      state.restart_requested = true
      state.last_action = "restart"
      Ok(updater_json(policy, state, status="delegated").stringify())
    }
  }
}

///|
fn validate_and_decode(
  policy : UpdaterPolicy,
  payload : String,
  context~ : String,
) -> Result[UpdaterRequest, String] {
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None => decode_request_payload(payload, context~)
  }
}

///|
fn apply_request(state : UpdaterState, request : UpdaterRequest) -> Unit {
  match request.update_available {
    Some(available) => state.update_available = available
    None => ()
  }
  match request.version {
    Some(version) => {
      state.version = Some(version)
      if request.update_available is None {
        state.update_available = true
      }
    }
    None => ()
  }
}

///|
fn updater_json(
  policy : UpdaterPolicy,
  state : UpdaterState,
  status~ : String,
) -> Json {
  Json::object({
    "status": Json::string(status),
    "lastAction": Json::string(state.last_action()),
    "feedUrl": Json::string(policy.feed_url()),
    "channel": Json::string(policy.channel()),
    "publicKey": optional_string_json(policy.public_key()),
    "allowPrerelease": Json::boolean(policy.allow_prerelease()),
    "updateAvailable": Json::boolean(state.update_available()),
    "version": optional_string_json(state.version()),
    "downloaded": Json::boolean(state.downloaded()),
    "installed": Json::boolean(state.installed()),
    "restartRequested": Json::boolean(state.restart_requested()),
  })
}

///|
fn decode_request_payload(
  payload : String,
  context~ : String,
) -> Result[UpdaterRequest, String] {
  if payload == "" {
    return Ok({ update_available: None, version: None })
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(version) =>
      match validate_version(version, context~) {
        Ok(version) => Ok({ update_available: None, version: Some(version) })
        Err(problem) => Err(problem)
      }
    Object(object) => {
      let update_available = match bool_field(object, "updateAvailable") {
        Some(value) => Some(value)
        None => bool_field(object, "available")
      }
      let version = match string_field(object, "version") {
        Some(version) =>
          match validate_version(version, context~) {
            Ok(version) => Some(version)
            Err(problem) => return Err(problem)
          }
        None => None
      }
      Ok({ update_available, version })
    }
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn validate_version(
  version : String,
  context~ : String,
) -> Result[String, String] {
  if version == "" {
    Err("\{context} version is required")
  } else if invalid_version(version) {
    Err("\{context} version is invalid: \{version}")
  } else {
    Ok(version)
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn bool_field(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn first_problem(problems : Array[String]) -> String? {
  if problems.length() == 0 {
    None
  } else {
    Some(problems[0])
  }
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

///|
fn invalid_version(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains("\t") ||
  value.contains("\n")
}

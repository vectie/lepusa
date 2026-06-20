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
pub struct DeepLinkState {
  initial_urls : Array[String]
  opened_urls : Array[String]
  registered_schemes : Array[String]
}

///|
pub fn DeepLinkState::new(initial_urls? : Array[String] = []) -> DeepLinkState {
  { initial_urls: initial_urls.copy(), opened_urls: [], registered_schemes: [] }
}

///|
pub fn DeepLinkState::initial_urls(self : DeepLinkState) -> Array[String] {
  self.initial_urls.copy()
}

///|
pub fn DeepLinkState::opened_urls(self : DeepLinkState) -> Array[String] {
  self.opened_urls.copy()
}

///|
pub fn DeepLinkState::registered_schemes(self : DeepLinkState) -> Array[String] {
  self.registered_schemes.copy()
}

///|
pub fn DeepLinkState::push_initial_url(
  self : DeepLinkState,
  url : String,
) -> Unit {
  self.initial_urls.push(url)
}

///|
pub fn registry(
  policy? : DeepLinkPolicy = DeepLinkPolicy::new(),
  state? : DeepLinkState = DeepLinkState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : DeepLinkPolicy = DeepLinkPolicy::new(),
  state? : DeepLinkState = DeepLinkState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("deepLink.getInitialUrls", permission=DeepLink, handler=_ => {
    handle_get_initial_urls(state)
  })
  .register_async_fn("deepLink.register", permission=DeepLink, handler=payload => {
    handle_register(policy, state, payload)
  })
  .register_async_fn("deepLink.unregister", permission=DeepLink, handler=payload => {
    handle_unregister(policy, state, payload)
  })
  .register_async_fn("deepLink.openUrl", permission=DeepLink, handler=payload => {
    handle_open_url(policy, state, payload)
  })
}

///|
async fn handle_get_initial_urls(
  state : DeepLinkState,
) -> Result[String, String] {
  @async.sleep(0)
  Ok(
    Json::object({ "urls": string_array_json(state.initial_urls()) }).stringify(),
  )
}

///|
async fn handle_register(
  policy : DeepLinkPolicy,
  state : DeepLinkState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_scheme_payload(payload, context="deep link register") {
    Ok(scheme) =>
      if !policy.allows_scheme(scheme) {
        Err("deep link scheme is not allowed: \{scheme}")
      } else {
        if !state.registered_schemes.contains(scheme) {
          state.registered_schemes.push(scheme)
        }
        Ok(
          Json::object({
            "scheme": Json::string(scheme),
            "registered": Json::boolean(true),
            "status": Json::string("delegated"),
          }).stringify(),
        )
      }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_unregister(
  policy : DeepLinkPolicy,
  state : DeepLinkState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_scheme_payload(payload, context="deep link unregister") {
    Ok(scheme) =>
      if !policy.allows_scheme(scheme) {
        Err("deep link scheme is not allowed: \{scheme}")
      } else {
        for index in 0..<state.registered_schemes.length() {
          if state.registered_schemes[index] == scheme {
            ignore(state.registered_schemes.remove(index))
            break
          }
        }
        Ok(
          Json::object({
            "scheme": Json::string(scheme),
            "registered": Json::boolean(false),
            "status": Json::string("delegated"),
          }).stringify(),
        )
      }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_open_url(
  policy : DeepLinkPolicy,
  state : DeepLinkState,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_url_payload(payload, context="deep link openUrl") {
    Ok(url) =>
      match parse_deep_link_url(url) {
        Ok((scheme, host)) =>
          if !policy.allows_url(scheme, host) {
            Err("deep link url is not allowed: \{url}")
          } else {
            state.opened_urls.push(url)
            Ok(
              Json::object({
                "url": Json::string(url),
                "scheme": Json::string(scheme),
                "host": optional_string_json(host),
                "status": Json::string("delegated"),
              }).stringify(),
            )
          }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn DeepLinkPolicy::allows_scheme(
  self : DeepLinkPolicy,
  scheme : String,
) -> Bool {
  self.schemes.is_empty() ||
  self.schemes.any(fn(item) { item.scheme() == scheme })
}

///|
fn DeepLinkPolicy::allows_url(
  self : DeepLinkPolicy,
  scheme : String,
  host : String?,
) -> Bool {
  if self.schemes.is_empty() {
    return true
  }
  for item in self.schemes {
    if item.scheme() == scheme {
      let hosts = item.hosts()
      return hosts.is_empty() ||
        (match host {
          Some(host) => hosts.contains(host)
          None => false
        })
    }
  }
  false
}

///|
fn decode_scheme_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  let scheme = match json {
    String(value) => value
    Object(object) => string_field(object, "scheme").unwrap_or("")
    _ => return Err("\{context} payload must be a string or object")
  }
  if scheme == "" {
    Err("\{context} scheme is required")
  } else if invalid_scheme(scheme) {
    Err("\{context} scheme is invalid: \{scheme}")
  } else {
    Ok(scheme)
  }
}

///|
fn decode_url_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  let url = match json {
    String(value) => value
    Object(object) => string_field(object, "url").unwrap_or("")
    _ => return Err("\{context} payload must be a string or object")
  }
  if url == "" {
    Err("\{context} url is required")
  } else {
    Ok(url)
  }
}

///|
fn parse_deep_link_url(url : String) -> Result[(String, String?), String] {
  match url.find(":") {
    Some(index) if index > 0 => {
      let scheme = url[:index].to_owned()
      if invalid_scheme(scheme) {
        return Err("deep link url scheme is invalid: \{scheme}")
      }
      let rest = url[index + 1:]
      let host = if rest.has_prefix("//") {
        let authority = rest[2:]
        let end = first_url_delimiter(authority)
        let host = authority[:end].to_owned()
        if host == "" {
          None
        } else {
          Some(host)
        }
      } else {
        None
      }
      match host {
        Some(host) if invalid_host(host) =>
          Err("deep link url host is invalid: \{host}")
        _ => Ok((scheme, host))
      }
    }
    _ => Err("deep link url scheme is required")
  }
}

///|
fn first_url_delimiter(value : StringView) -> Int {
  let slash = value.find("/").unwrap_or(value.length())
  let query = value.find("?").unwrap_or(value.length())
  let fragment = value.find("#").unwrap_or(value.length())
  slash.min(query).min(fragment)
}

///|
fn string_array_json(values : Array[String]) -> Json {
  Json::array(values.map(fn(value) { Json::string(value) }))
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

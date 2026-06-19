///|
pub struct BundledRuntimeManifest {
  path : String
  bundle_root : String
  bundle : Map[String, Json]
  runtime : Map[String, Json]
} derive(Debug)

///|
pub fn BundledRuntimeManifest::parse(
  path : String,
  text : String,
) -> Result[BundledRuntimeManifest, String] {
  let json = @json.parse(text) catch {
    error => return Err("invalid runtime json: \{error}")
  }
  match json {
    Object(object) =>
      match optional_object(object, "runtime") {
        Some(runtime) =>
          Ok({
            path,
            bundle_root: bundle_root_for_manifest(path),
            bundle: object,
            runtime,
          })
        None => Err("runtime object is required")
      }
    _ => Err("runtime manifest must be a json object")
  }
}

///|
pub fn BundledRuntimeManifest::summary(self : BundledRuntimeManifest) -> String {
  let webviews = optional_array(self.runtime, "webviews").unwrap_or([])
  let local_services = optional_array(self.runtime, "localServices").unwrap_or([])
  let startup_actions = optional_array(self.runtime, "startupActions").unwrap_or([],
  )
  let lifecycle_hooks = optional_array(self.runtime, "lifecycleHooks").unwrap_or([],
  )
  let routes = optional_array(self.runtime, "commandRoutes").unwrap_or([])
  let registered_routes = optional_array(self.runtime, "registeredRoutes").unwrap_or([],
  )
  "Lepusa runtime\n" +
  "manifest: \{self.path}\n" +
  "identifier: \{optional_string(self.bundle, "identifier").unwrap_or("")}\n" +
  "product: \{optional_string(self.bundle, "productName").unwrap_or("")}\n" +
  "target: \{optional_string(self.bundle, "target").unwrap_or("")}\n" +
  "backend: \{optional_string(self.runtime, "backend").unwrap_or("")}\n" +
  "bridge: \{optional_string(self.runtime, "bridgeUrl").unwrap_or("")}\n" +
  "webviews: \{webviews.length()}\n" +
  "first-window-url: \{first_webview_url(webviews)}\n" +
  "local-services: \{local_services.length()}\n" +
  "startup-actions: \{startup_actions.length()}\n" +
  "lifecycle-hooks: \{lifecycle_hooks.length()}\n" +
  "command-routes: \{routes.length()}\n" +
  "registered-routes: \{registered_routes.length()}\n"
}

///|
pub fn BundledRuntimeManifest::path(self : BundledRuntimeManifest) -> String {
  self.path
}

///|
pub fn BundledRuntimeManifest::bundle_root(
  self : BundledRuntimeManifest,
) -> String {
  self.bundle_root
}

///|
fn first_webview_url(webviews : Array[Json]) -> String {
  match webviews.get(0) {
    Some(Object(webview)) => optional_string(webview, "url").unwrap_or("")
    _ => ""
  }
}

///|
fn optional_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_array(object : Map[String, Json], key : String) -> Array[Json]? {
  match object.get(key) {
    Some(Array(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn bundle_root_for_manifest(path : String) -> String {
  let dir = parent_directory(path)
  if dir == "lepusa" || dir.has_suffix("/lepusa") || dir.has_suffix("\\lepusa") {
    parent_directory(dir)
  } else {
    dir
  }
}

///|
fn parent_directory(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  let mut last = -1
  for i in 0..<trimmed.length() {
    let char = trimmed[i]
    if char == '/' || char == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    trimmed[:last].to_owned()
  }
}

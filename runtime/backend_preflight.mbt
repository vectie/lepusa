///|
pub struct NativeBackendPreflight {
  platform : String
  webview_engine : String
  dependency_name : String
  dependency_available : Bool
  webview_creation_loop : Bool
  async_bridge_drain : Bool
  dependency_message : String
  webview_creation_message : String
} derive(Debug, Eq)

///|
pub fn NativeBackendPreflight::new(
  platform~ : String,
  webview_engine~ : String,
  dependency_name~ : String,
  dependency_available~ : Bool,
  webview_creation_loop~ : Bool,
  async_bridge_drain~ : Bool,
  dependency_message? : String = "native WebView dependency is unavailable",
  webview_creation_message? : String = "native WebView creation loop is unavailable",
) -> NativeBackendPreflight {
  {
    platform,
    webview_engine,
    dependency_name,
    dependency_available,
    webview_creation_loop,
    async_bridge_drain,
    dependency_message,
    webview_creation_message,
  }
}

///|
pub fn NativeBackendPreflight::platform(
  self : NativeBackendPreflight,
) -> String {
  self.platform
}

///|
pub fn NativeBackendPreflight::webview_engine(
  self : NativeBackendPreflight,
) -> String {
  self.webview_engine
}

///|
pub fn NativeBackendPreflight::dependency_name(
  self : NativeBackendPreflight,
) -> String {
  self.dependency_name
}

///|
pub fn NativeBackendPreflight::dependency_available(
  self : NativeBackendPreflight,
) -> Bool {
  self.dependency_available
}

///|
pub fn NativeBackendPreflight::webview_creation_loop(
  self : NativeBackendPreflight,
) -> Bool {
  self.webview_creation_loop
}

///|
pub fn NativeBackendPreflight::async_bridge_drain(
  self : NativeBackendPreflight,
) -> Bool {
  self.async_bridge_drain
}

///|
pub fn NativeBackendPreflight::can_launch(
  self : NativeBackendPreflight,
) -> Bool {
  self.dependency_available && self.webview_creation_loop
}

///|
pub fn NativeBackendPreflight::problem(self : NativeBackendPreflight) -> String {
  if !self.dependency_available {
    self.dependency_message
  } else if !self.webview_creation_loop {
    self.webview_creation_message
  } else {
    ""
  }
}

///|
pub fn NativeBackendPreflight::launch_capability(
  self : NativeBackendPreflight,
) -> NativeLaunchCapability {
  NativeLaunchCapability::new(
    webview_creation=self.can_launch(),
    async_bridge_drain=self.async_bridge_drain,
    webview_creation_message=self.problem(),
  )
}

///|
pub fn NativeBackendPreflight::to_json(self : NativeBackendPreflight) -> String {
  [
    "{",
    "\"platform\":\{self.platform.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"dependencyName\":\{self.dependency_name.json_string()},",
    "\"dependencyAvailable\":\{self.dependency_available.json_bool()},",
    "\"webviewCreationLoop\":\{self.webview_creation_loop.json_bool()},",
    "\"asyncBridgeDrain\":\{self.async_bridge_drain.json_bool()},",
    "\"canLaunch\":\{self.can_launch().json_bool()},",
    "\"problem\":\{self.problem().json_string()}",
    "}",
  ].join("")
}

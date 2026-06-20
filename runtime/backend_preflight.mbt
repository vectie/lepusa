///|
pub struct NativeBackendPreflight {
  platform : String
  webview_engine : String
  dependency_name : String
  dependency_available : Bool
  webview_creation_loop : Bool
  sync_bridge_evaluate : Bool
  async_bridge_drain : Bool
  dependency_message : String
  webview_creation_message : String
  sync_bridge_evaluate_message : String
  async_bridge_drain_message : String
} derive(Debug, Eq)

///|
pub fn NativeBackendPreflight::new(
  platform~ : String,
  webview_engine~ : String,
  dependency_name~ : String,
  dependency_available~ : Bool,
  webview_creation_loop~ : Bool,
  sync_bridge_evaluate? : Bool = webview_creation_loop,
  async_bridge_drain~ : Bool,
  dependency_message? : String = "native WebView dependency is unavailable",
  webview_creation_message? : String = "native WebView creation loop is unavailable",
  sync_bridge_evaluate_message? : String = "native sync bridge response evaluation is unavailable",
  async_bridge_drain_message? : String = "native async bridge drain/evaluate support is unavailable",
) -> NativeBackendPreflight {
  {
    platform,
    webview_engine,
    dependency_name,
    dependency_available,
    webview_creation_loop,
    sync_bridge_evaluate,
    async_bridge_drain,
    dependency_message,
    webview_creation_message,
    sync_bridge_evaluate_message,
    async_bridge_drain_message,
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
pub fn NativeBackendPreflight::sync_bridge_evaluate(
  self : NativeBackendPreflight,
) -> Bool {
  self.sync_bridge_evaluate
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
pub fn NativeBackendPreflight::problem_kind(
  self : NativeBackendPreflight,
) -> String {
  if !self.dependency_available {
    "dependency"
  } else if !self.webview_creation_loop {
    "webview-creation"
  } else {
    "none"
  }
}

///|
pub fn NativeBackendPreflight::dependency_problem(
  self : NativeBackendPreflight,
) -> String? {
  if self.dependency_available {
    None
  } else {
    Some(self.dependency_message)
  }
}

///|
pub fn NativeBackendPreflight::webview_creation_problem(
  self : NativeBackendPreflight,
) -> String? {
  if self.webview_creation_loop {
    None
  } else {
    Some(self.webview_creation_message)
  }
}

///|
pub fn NativeBackendPreflight::sync_bridge_evaluate_problem(
  self : NativeBackendPreflight,
) -> String? {
  if self.sync_bridge_evaluate {
    None
  } else {
    Some(self.sync_bridge_evaluate_message)
  }
}

///|
pub fn NativeBackendPreflight::async_bridge_drain_problem(
  self : NativeBackendPreflight,
) -> String? {
  if self.async_bridge_drain {
    None
  } else {
    Some(self.async_bridge_drain_message)
  }
}

///|
pub fn NativeBackendPreflight::launch_capability(
  self : NativeBackendPreflight,
) -> NativeLaunchCapability {
  NativeLaunchCapability::new(
    webview_creation=self.can_launch(),
    sync_bridge_evaluate=self.can_launch() && self.sync_bridge_evaluate,
    async_bridge_drain=self.async_bridge_drain,
    webview_creation_message=self.problem(),
    sync_bridge_evaluate_message=self.sync_bridge_evaluate_message,
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
    "\"syncBridgeEvaluate\":\{self.sync_bridge_evaluate.json_bool()},",
    "\"asyncBridgeDrain\":\{self.async_bridge_drain.json_bool()},",
    "\"canLaunch\":\{self.can_launch().json_bool()},",
    "\"problemKind\":\{self.problem_kind().json_string()},",
    "\"problem\":\{self.problem().json_string()},",
    "\"dependencyProblem\":\{optional_json_string(self.dependency_problem())},",
    "\"webviewCreationProblem\":\{optional_json_string(self.webview_creation_problem())},",
    "\"syncBridgeEvaluateProblem\":\{optional_json_string(self.sync_bridge_evaluate_problem())},",
    "\"asyncBridgeDrainProblem\":\{optional_json_string(self.async_bridge_drain_problem())}",
    "}",
  ].join("")
}

///|
fn optional_json_string(value : String?) -> String {
  match value {
    Some(text) => text.json_string()
    None => "null"
  }
}

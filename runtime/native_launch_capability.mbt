///|
pub struct NativeLaunchCapability {
  webview_creation : Bool
  sync_bridge_evaluate : Bool
  async_bridge_drain : Bool
  max_webviews : Int
  webview_creation_message : String
  sync_bridge_evaluate_message : String
  async_bridge_drain_message : String
} derive(Debug, Eq)

///|
pub fn NativeLaunchCapability::new(
  webview_creation~ : Bool,
  sync_bridge_evaluate? : Bool = webview_creation,
  async_bridge_drain~ : Bool,
  max_webviews? : Int = 1,
  webview_creation_message? : String = "native WebView creation loop is unavailable",
  sync_bridge_evaluate_message? : String = "native sync bridge response evaluation is unavailable",
  async_bridge_drain_message? : String = "native async bridge drain/evaluate support is unavailable",
) -> NativeLaunchCapability {
  {
    webview_creation,
    sync_bridge_evaluate,
    async_bridge_drain,
    max_webviews,
    webview_creation_message,
    sync_bridge_evaluate_message,
    async_bridge_drain_message,
  }
}

///|
pub fn NativeLaunchCapability::webview_creation(
  self : NativeLaunchCapability,
) -> Bool {
  self.webview_creation
}

///|
pub fn NativeLaunchCapability::async_bridge_drain(
  self : NativeLaunchCapability,
) -> Bool {
  self.async_bridge_drain
}

///|
pub fn NativeLaunchCapability::sync_bridge_evaluate(
  self : NativeLaunchCapability,
) -> Bool {
  self.sync_bridge_evaluate
}

///|
pub fn NativeLaunchCapability::max_webviews(
  self : NativeLaunchCapability,
) -> Int {
  self.max_webviews
}

///|
pub fn NativeLaunchCapability::webview_creation_message(
  self : NativeLaunchCapability,
) -> String {
  self.webview_creation_message
}

///|
pub fn NativeLaunchCapability::sync_bridge_evaluate_message(
  self : NativeLaunchCapability,
) -> String {
  self.sync_bridge_evaluate_message
}

///|
pub fn NativeLaunchCapability::async_bridge_drain_message(
  self : NativeLaunchCapability,
) -> String {
  self.async_bridge_drain_message
}

///|
pub fn NativeLaunchCapability::bridge_mode(
  self : NativeLaunchCapability,
) -> NativeBridgeSchedulerMode {
  if self.async_bridge_drain {
    NativeBridgeAsyncCapable
  } else {
    NativeBridgeSyncOnly
  }
}

///|
pub fn NativeLaunchCapability::async_bridge_drain_strategy(
  self : NativeLaunchCapability,
) -> NativeBridgeDrainStrategy {
  self.bridge_mode().drain_strategy()
}

///|
pub fn NativeLaunchCapability::launch_blocker(
  self : NativeLaunchCapability,
  platform_name : String,
  scheduler : NativeBridgeScheduler,
) -> String? {
  if !self.webview_creation {
    Some(self.webview_creation_message)
  } else if !scheduler.sync_routes().is_empty() && !self.sync_bridge_evaluate {
    Some(self.sync_bridge_evaluate_message)
  } else if scheduler.requires_async_dispatch() && !self.async_bridge_drain {
    Some(self.async_bridge_launch_message(platform_name, scheduler))
  } else {
    None
  }
}

///|
pub fn NativeLaunchCapability::async_bridge_launch_message(
  self : NativeLaunchCapability,
  platform_name : String,
  scheduler : NativeBridgeScheduler,
) -> String {
  "\{scheduler.async_bridge_launch_message(platform_name)}: \{self.async_bridge_drain_message}"
}

///|
pub fn NativeLaunchCapability::can_launch(
  self : NativeLaunchCapability,
  scheduler : NativeBridgeScheduler,
) -> Bool {
  self.launch_blocker("", scheduler) is None
}

///|
pub fn NativeLaunchCapability::webview_count_blocker(
  self : NativeLaunchCapability,
  platform_name : String,
  webview_count : Int,
) -> String? {
  if self.max_webviews <= 0 || webview_count <= self.max_webviews {
    None
  } else {
    Some(
      "\{platform_name} native launch supports \{self.max_webviews} webview(s); plan has \{webview_count}",
    )
  }
}

///|
pub fn NativeLaunchCapability::to_json(self : NativeLaunchCapability) -> String {
  [
    "{",
    "\"webviewCreation\":\{self.webview_creation.json_bool()},",
    "\"syncBridgeEvaluate\":\{self.sync_bridge_evaluate.json_bool()},",
    "\"asyncBridgeDrain\":\{self.async_bridge_drain.json_bool()},",
    "\"asyncBridgeDrainStrategy\":\{self.async_bridge_drain_strategy().name().json_string()},",
    "\"maxWebviews\":\{self.max_webviews},",
    "\"bridgeMode\":\{self.bridge_mode().name().json_string()},",
    "\"webviewCreationMessage\":\{self.webview_creation_message.json_string()},",
    "\"syncBridgeEvaluateMessage\":\{self.sync_bridge_evaluate_message.json_string()},",
    "\"asyncBridgeDrainMessage\":\{self.async_bridge_drain_message.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeLaunchSession::launch_blocker_with_capability(
  self : NativeLaunchSession,
  platform_name : String,
  capability : NativeLaunchCapability,
) -> String? {
  match capability.launch_blocker(platform_name, self.bridge_scheduler()) {
    Some(message) => Some(message)
    None =>
      capability.webview_count_blocker(platform_name, self.webviews.length())
  }
}

///|
pub fn NativeLaunchSession::can_launch_with_capability(
  self : NativeLaunchSession,
  capability : NativeLaunchCapability,
) -> Bool {
  self.launch_blocker_with_capability("", capability) is None
}

///|
pub fn NativePreparedRunPlan::launch_session_with_capability(
  self : NativePreparedRunPlan,
  capability : NativeLaunchCapability,
) -> NativeLaunchSession {
  self.launch_session(bridge_mode=capability.bridge_mode())
}

///|
pub fn NativePreparedRunPlan::launch_blocker_with_capability(
  self : NativePreparedRunPlan,
  platform_name : String,
  capability : NativeLaunchCapability,
) -> String? {
  self
  .launch_session_with_capability(capability)
  .launch_blocker_with_capability(platform_name, capability)
}

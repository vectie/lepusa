///|
pub struct NativeLaunchCapability {
  webview_creation : Bool
  sync_bridge_evaluate : Bool
  async_bridge_drain : Bool
  webview_creation_message : String
  sync_bridge_evaluate_message : String
} derive(Debug, Eq)

///|
pub fn NativeLaunchCapability::new(
  webview_creation~ : Bool,
  sync_bridge_evaluate? : Bool = webview_creation,
  async_bridge_drain~ : Bool,
  webview_creation_message? : String = "native WebView creation loop is unavailable",
  sync_bridge_evaluate_message? : String = "native sync bridge response evaluation is unavailable",
) -> NativeLaunchCapability {
  {
    webview_creation,
    sync_bridge_evaluate,
    async_bridge_drain,
    webview_creation_message,
    sync_bridge_evaluate_message,
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
    Some(scheduler.async_bridge_launch_message(platform_name))
  } else {
    None
  }
}

///|
pub fn NativeLaunchCapability::can_launch(
  self : NativeLaunchCapability,
  scheduler : NativeBridgeScheduler,
) -> Bool {
  self.launch_blocker("", scheduler) is None
}

///|
pub fn NativeLaunchCapability::to_json(self : NativeLaunchCapability) -> String {
  [
    "{",
    "\"webviewCreation\":\{self.webview_creation.json_bool()},",
    "\"syncBridgeEvaluate\":\{self.sync_bridge_evaluate.json_bool()},",
    "\"asyncBridgeDrain\":\{self.async_bridge_drain.json_bool()},",
    "\"bridgeMode\":\{self.bridge_mode().name().json_string()},",
    "\"webviewCreationMessage\":\{self.webview_creation_message.json_string()},",
    "\"syncBridgeEvaluateMessage\":\{self.sync_bridge_evaluate_message.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeLaunchSession::launch_blocker_with_capability(
  self : NativeLaunchSession,
  platform_name : String,
  capability : NativeLaunchCapability,
) -> String? {
  capability.launch_blocker(platform_name, self.bridge_scheduler())
}

///|
pub fn NativeLaunchSession::can_launch_with_capability(
  self : NativeLaunchSession,
  capability : NativeLaunchCapability,
) -> Bool {
  capability.can_launch(self.bridge_scheduler())
}

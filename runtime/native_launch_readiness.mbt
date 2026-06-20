///|
pub struct NativeLaunchReadiness {
  target : String
  platform_name : String
  session : NativeLaunchSession
  capability : NativeLaunchCapability
  preflight : NativeBackendPreflight
  requested_bridge_mode : NativeBridgeSchedulerMode
} derive(Debug, Eq)

///|
pub fn NativeLaunchReadiness::new(
  target~ : String,
  platform_name~ : String,
  session~ : NativeLaunchSession,
  capability~ : NativeLaunchCapability,
  preflight~ : NativeBackendPreflight,
  requested_bridge_mode~ : NativeBridgeSchedulerMode,
) -> NativeLaunchReadiness {
  {
    target,
    platform_name,
    session,
    capability,
    preflight,
    requested_bridge_mode,
  }
}

///|
pub fn NativeLaunchReadiness::target(self : NativeLaunchReadiness) -> String {
  self.target
}

///|
pub fn NativeLaunchReadiness::platform_name(
  self : NativeLaunchReadiness,
) -> String {
  self.platform_name
}

///|
pub fn NativeLaunchReadiness::session(
  self : NativeLaunchReadiness,
) -> NativeLaunchSession {
  self.session
}

///|
pub fn NativeLaunchReadiness::capability(
  self : NativeLaunchReadiness,
) -> NativeLaunchCapability {
  self.capability
}

///|
pub fn NativeLaunchReadiness::preflight(
  self : NativeLaunchReadiness,
) -> NativeBackendPreflight {
  self.preflight
}

///|
pub fn NativeLaunchReadiness::requested_bridge_mode(
  self : NativeLaunchReadiness,
) -> NativeBridgeSchedulerMode {
  self.requested_bridge_mode
}

///|
pub fn NativeLaunchReadiness::effective_bridge_mode(
  self : NativeLaunchReadiness,
) -> NativeBridgeSchedulerMode {
  self.session.bridge_scheduler().mode()
}

///|
pub fn NativeLaunchReadiness::bridge_mode_granted(
  self : NativeLaunchReadiness,
) -> Bool {
  self.requested_bridge_mode == self.effective_bridge_mode()
}

///|
pub fn NativeLaunchReadiness::launch_blocker(
  self : NativeLaunchReadiness,
) -> String? {
  self.capability.launch_blocker(
    self.platform_name,
    self.session.bridge_scheduler(),
  )
}

///|
pub fn NativeLaunchReadiness::can_launch(self : NativeLaunchReadiness) -> Bool {
  self.launch_blocker() is None
}

///|
pub fn NativeLaunchReadiness::to_json(self : NativeLaunchReadiness) -> String {
  let blocker_json = match self.launch_blocker() {
    Some(problem) => problem.json_string()
    None => "null"
  }
  [
    "{",
    "\"target\":\{self.target.json_string()},",
    "\"platformName\":\{self.platform_name.json_string()},",
    "\"session\":\{self.session.to_json()},",
    "\"launchCapability\":\{self.capability.to_json()},",
    "\"backendPreflight\":\{self.preflight.to_json()},",
    "\"requestedBridgeMode\":\{self.requested_bridge_mode().name().json_string()},",
    "\"effectiveBridgeMode\":\{self.effective_bridge_mode().name().json_string()},",
    "\"bridgeModeGranted\":\{self.bridge_mode_granted().json_bool()},",
    "\"targetCanLaunch\":\{self.can_launch().json_bool()},",
    "\"targetLaunchBlocker\":\{blocker_json}",
    "}",
  ].join("")
}

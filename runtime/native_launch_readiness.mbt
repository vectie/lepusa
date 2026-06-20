///|
pub struct NativeLaunchReadiness {
  target : String
  platform_name : String
  session : NativeLaunchSession
  capability : NativeLaunchCapability
} derive(Debug, Eq)

///|
pub fn NativeLaunchReadiness::new(
  target~ : String,
  platform_name~ : String,
  session~ : NativeLaunchSession,
  capability~ : NativeLaunchCapability,
) -> NativeLaunchReadiness {
  { target, platform_name, session, capability }
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
    "\"targetCanLaunch\":\{self.can_launch().json_bool()},",
    "\"targetLaunchBlocker\":\{blocker_json}",
    "}",
  ].join("")
}

///|
pub struct ReleaseReadinessReport {
  target : BundleTarget
  files : Int
  resources : Int
  artifacts : Int
  runtime_dependencies : Int
  required_runtime_dependencies : Int
  signing_configured : Bool
  signing_prerequisites : Int
  signing_steps : Int
  runtime_webviews : Int
  command_routes : Int
  registered_routes : Int
  native_launch_session_ready : Bool
  native_launch_session_issue : String
  issues : Array[String]
} derive(Debug, Eq)

///|
pub fn BundlePlan::release_readiness(
  self : BundlePlan,
) -> Result[ReleaseReadinessReport, Array[String]] {
  match self.files() {
    Err(problems) => Err(problems)
    Ok(files) =>
      match self.runtime_manifest() {
        Err(problems) => Err(problems)
        Ok(manifest) => {
          let native_launch_session_ready = !manifest.webviews().is_empty()
          let native_launch_session_issue = if native_launch_session_ready {
            ""
          } else {
            "native launch session requires at least one webview"
          }
          let issues = release_readiness_issues(
            self, native_launch_session_ready, native_launch_session_issue,
          )
          Ok({
            target: self.target(),
            files: files.length(),
            resources: self.resources().length(),
            artifacts: self.artifacts().length(),
            runtime_dependencies: self.runtime_dependencies().length(),
            required_runtime_dependencies: self
            .runtime_dependencies()
            .filter(fn(dependency) { dependency.required() })
            .length(),
            signing_configured: self.signing().configured(),
            signing_prerequisites: self.signing_prerequisites().length(),
            signing_steps: self.signing_steps().length(),
            runtime_webviews: manifest.webviews().length(),
            command_routes: manifest.command_routes().length(),
            registered_routes: manifest.registered_routes().length(),
            native_launch_session_ready,
            native_launch_session_issue,
            issues,
          })
        }
      }
  }
}

///|
fn release_readiness_issues(
  plan : BundlePlan,
  native_launch_session_ready : Bool,
  native_launch_session_issue : String,
) -> Array[String] {
  let issues : Array[String] = []
  if !native_launch_session_ready {
    issues.push(native_launch_session_issue)
  }
  if !plan.signing().configured() {
    issues.push("signing is not configured")
  }
  if plan.target() is Windows {
    let mut has_loader_source = false
    for dependency in plan.runtime_dependencies() {
      if dependency.name() == "WebView2Loader.dll" &&
        dependency.source_path() is Some(_) {
        has_loader_source = true
      }
    }
    if !has_loader_source {
      issues.push("WebView2Loader.dll source is not configured")
    }
  }
  if plan.runtime_dependencies().any(fn(dependency) { dependency.required() }) ==
    false {
    issues.push("no required runtime dependency is declared")
  }
  issues
}

///|
pub fn ReleaseReadinessReport::target(
  self : ReleaseReadinessReport,
) -> BundleTarget {
  self.target
}

///|
pub fn ReleaseReadinessReport::files(self : ReleaseReadinessReport) -> Int {
  self.files
}

///|
pub fn ReleaseReadinessReport::resources(self : ReleaseReadinessReport) -> Int {
  self.resources
}

///|
pub fn ReleaseReadinessReport::artifacts(self : ReleaseReadinessReport) -> Int {
  self.artifacts
}

///|
pub fn ReleaseReadinessReport::runtime_dependencies(
  self : ReleaseReadinessReport,
) -> Int {
  self.runtime_dependencies
}

///|
pub fn ReleaseReadinessReport::required_runtime_dependencies(
  self : ReleaseReadinessReport,
) -> Int {
  self.required_runtime_dependencies
}

///|
pub fn ReleaseReadinessReport::signing_configured(
  self : ReleaseReadinessReport,
) -> Bool {
  self.signing_configured
}

///|
pub fn ReleaseReadinessReport::signing_prerequisites(
  self : ReleaseReadinessReport,
) -> Int {
  self.signing_prerequisites
}

///|
pub fn ReleaseReadinessReport::signing_steps(
  self : ReleaseReadinessReport,
) -> Int {
  self.signing_steps
}

///|
pub fn ReleaseReadinessReport::runtime_webviews(
  self : ReleaseReadinessReport,
) -> Int {
  self.runtime_webviews
}

///|
pub fn ReleaseReadinessReport::command_routes(
  self : ReleaseReadinessReport,
) -> Int {
  self.command_routes
}

///|
pub fn ReleaseReadinessReport::registered_routes(
  self : ReleaseReadinessReport,
) -> Int {
  self.registered_routes
}

///|
pub fn ReleaseReadinessReport::native_launch_session_ready(
  self : ReleaseReadinessReport,
) -> Bool {
  self.native_launch_session_ready
}

///|
pub fn ReleaseReadinessReport::native_launch_session_issue(
  self : ReleaseReadinessReport,
) -> String {
  self.native_launch_session_issue
}

///|
pub fn ReleaseReadinessReport::issues(
  self : ReleaseReadinessReport,
) -> Array[String] {
  self.issues.copy()
}

///|
pub fn ReleaseReadinessReport::ready(self : ReleaseReadinessReport) -> Bool {
  self.issues.is_empty()
}

///|
pub fn ReleaseReadinessReport::to_json(self : ReleaseReadinessReport) -> String {
  [
    "{",
    "\"target\":\{self.target.name().json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"files\":\{self.files},",
    "\"resources\":\{self.resources},",
    "\"artifacts\":\{self.artifacts},",
    "\"runtimeDependencies\":\{self.runtime_dependencies},",
    "\"requiredRuntimeDependencies\":\{self.required_runtime_dependencies},",
    "\"signingConfigured\":\{self.signing_configured.json_bool()},",
    "\"signingPrerequisites\":\{self.signing_prerequisites},",
    "\"signingSteps\":\{self.signing_steps},",
    "\"runtimeWebviews\":\{self.runtime_webviews},",
    "\"commandRoutes\":\{self.command_routes},",
    "\"registeredRoutes\":\{self.registered_routes},",
    "\"nativeLaunchSessionReady\":\{self.native_launch_session_ready.json_bool()},",
    "\"nativeLaunchSessionIssue\":\{self.native_launch_session_issue.json_string()},",
    "\"issues\":[\{self.issues.map(fn(issue) { issue.json_string() }).join(",")}]",
    "}",
  ].join("")
}

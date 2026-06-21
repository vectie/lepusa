///|
pub(all) enum RuntimeAuditSeverity {
  RuntimeAuditInfo
  RuntimeAuditWarning
  RuntimeAuditError
} derive(Debug, Eq)

///|
pub(all) enum RuntimeAuditKind {
  RuntimeAuditDeniedCommand
  RuntimeAuditMissingHandler
  RuntimeAuditUndeclaredHandler
  RuntimeAuditOpenOrigin
} derive(Debug, Eq)

///|
pub struct RuntimeAuditFinding {
  severity : RuntimeAuditSeverity
  kind : RuntimeAuditKind
  route : String
  message : String
} derive(Debug, Eq)

///|
pub struct RuntimeRouteExposure {
  route : String
  mode : CommandMode
  registered : Bool
  exposed : Bool
  windows : Array[String]
  reasons : Array[String]
} derive(Debug, Eq)

///|
pub struct RuntimeAudit {
  command_manifest : CommandManifest
  permission_manifest : PermissionManifest
  registered_routes : Array[String]
  route_exposures : Array[RuntimeRouteExposure]
  findings : Array[RuntimeAuditFinding]
} derive(Debug, Eq)

///|
pub fn RuntimeAuditSeverity::name(self : RuntimeAuditSeverity) -> String {
  match self {
    RuntimeAuditInfo => "info"
    RuntimeAuditWarning => "warning"
    RuntimeAuditError => "error"
  }
}

///|
pub fn RuntimeAuditKind::name(self : RuntimeAuditKind) -> String {
  match self {
    RuntimeAuditDeniedCommand => "denied-command"
    RuntimeAuditMissingHandler => "missing-handler"
    RuntimeAuditUndeclaredHandler => "undeclared-handler"
    RuntimeAuditOpenOrigin => "open-origin"
  }
}

///|
pub fn RuntimeAuditFinding::new(
  severity~ : RuntimeAuditSeverity,
  kind~ : RuntimeAuditKind,
  route~ : String,
  message~ : String,
) -> RuntimeAuditFinding {
  { severity, kind, route, message }
}

///|
pub fn RuntimeAuditFinding::severity(
  self : RuntimeAuditFinding,
) -> RuntimeAuditSeverity {
  self.severity
}

///|
pub fn RuntimeAuditFinding::kind(
  self : RuntimeAuditFinding,
) -> RuntimeAuditKind {
  self.kind
}

///|
pub fn RuntimeAuditFinding::route(self : RuntimeAuditFinding) -> String {
  self.route
}

///|
pub fn RuntimeAuditFinding::message(self : RuntimeAuditFinding) -> String {
  self.message
}

///|
pub fn RuntimeAuditFinding::to_json(self : RuntimeAuditFinding) -> String {
  [
    "{",
    "\"severity\":\{self.severity.name().json_string()},",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"message\":\{self.message.json_string()}",
    "}",
  ].join("")
}

///|
fn RuntimeRouteExposure::from_entry(
  entry : CommandManifestEntry,
  registered_routes : Array[String],
  check_handlers~ : Bool,
) -> RuntimeRouteExposure {
  let reasons : Array[String] = []
  let registered = registered_routes.contains(entry.route())
  if entry.allowed_windows().is_empty() {
    reasons.push("no-window-capability")
  }
  if !entry.mode().requires_registered_handler() {
    reasons.push("event-route")
  }
  if check_handlers && entry.mode().requires_registered_handler() && !registered {
    reasons.push("missing-handler")
  }
  let exposed = entry.mode().requires_registered_handler() &&
    !entry.allowed_windows().is_empty() &&
    (!check_handlers || registered)
  if exposed {
    reasons.push("exposed")
  }
  {
    route: entry.route(),
    mode: entry.mode(),
    registered,
    exposed,
    windows: entry.allowed_windows(),
    reasons,
  }
}

///|
pub fn RuntimeRouteExposure::route(self : RuntimeRouteExposure) -> String {
  self.route
}

///|
pub fn RuntimeRouteExposure::mode(self : RuntimeRouteExposure) -> CommandMode {
  self.mode
}

///|
pub fn RuntimeRouteExposure::registered(self : RuntimeRouteExposure) -> Bool {
  self.registered
}

///|
pub fn RuntimeRouteExposure::exposed(self : RuntimeRouteExposure) -> Bool {
  self.exposed
}

///|
pub fn RuntimeRouteExposure::windows(
  self : RuntimeRouteExposure,
) -> Array[String] {
  self.windows.copy()
}

///|
pub fn RuntimeRouteExposure::reasons(
  self : RuntimeRouteExposure,
) -> Array[String] {
  self.reasons.copy()
}

///|
pub fn RuntimeRouteExposure::to_json(self : RuntimeRouteExposure) -> String {
  [
    "{",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"registered\":\{self.registered.json_bool()},",
    "\"exposed\":\{self.exposed.json_bool()},",
    "\"windows\":[\{self.windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"reasons\":[\{self.reasons.map(fn(reason) { reason.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn RuntimeAudit::from_plan(plan : RuntimePlan) -> RuntimeAudit {
  RuntimeAudit::build(plan, registered_routes=[], check_handlers=false)
}

///|
pub fn RuntimeAudit::from_registered_routes(
  plan : RuntimePlan,
  registered_routes : Array[String],
) -> RuntimeAudit {
  RuntimeAudit::build(plan, registered_routes~, check_handlers=true)
}

///|
fn RuntimeAudit::build(
  plan : RuntimePlan,
  registered_routes~ : Array[String],
  check_handlers~ : Bool,
) -> RuntimeAudit {
  let command_manifest = plan.command_manifest()
  let permission_manifest = plan.permission_manifest()
  let registered_routes = sorted_unique_routes(registered_routes)
  let route_exposures : Array[RuntimeRouteExposure] = []
  let findings : Array[RuntimeAuditFinding] = []
  for entry in command_manifest.entries() {
    route_exposures.push(
      RuntimeRouteExposure::from_entry(
        entry,
        registered_routes,
        check_handlers~,
      ),
    )
    if entry.allowed_windows().is_empty() {
      findings.push(
        RuntimeAuditFinding::new(
          severity=RuntimeAuditError,
          kind=RuntimeAuditDeniedCommand,
          route=entry.route(),
          message="command is declared but no window capability grants access: \{entry.route()}",
        ),
      )
    } else if entry.allowed_origins().is_empty() {
      findings.push(
        RuntimeAuditFinding::new(
          severity=RuntimeAuditInfo,
          kind=RuntimeAuditOpenOrigin,
          route=entry.route(),
          message="command has no origin restriction: \{entry.route()}",
        ),
      )
    }
    if check_handlers &&
      entry.mode().requires_registered_handler() &&
      !registered_routes.contains(entry.route()) {
      findings.push(
        RuntimeAuditFinding::new(
          severity=RuntimeAuditError,
          kind=RuntimeAuditMissingHandler,
          route=entry.route(),
          message="command is declared but no native handler is registered: \{entry.route()}",
        ),
      )
    }
  }
  if check_handlers {
    let declared_routes = command_manifest.routes()
    for route in registered_routes {
      if !declared_routes.contains(route) {
        findings.push(
          RuntimeAuditFinding::new(
            severity=RuntimeAuditWarning,
            kind=RuntimeAuditUndeclaredHandler,
            route~,
            message="native handler is registered but no plugin command declares it: \{route}",
          ),
        )
      }
    }
  }
  {
    command_manifest,
    permission_manifest,
    registered_routes,
    route_exposures,
    findings,
  }
}

///|
pub fn RuntimePlan::audit(self : RuntimePlan) -> RuntimeAudit {
  RuntimeAudit::from_plan(self)
}

///|
pub fn RuntimePlan::audit_with_registered_routes(
  self : RuntimePlan,
  registered_routes : Array[String],
) -> RuntimeAudit {
  RuntimeAudit::from_registered_routes(self, registered_routes)
}

///|
pub fn RuntimeAudit::command_manifest(self : RuntimeAudit) -> CommandManifest {
  self.command_manifest
}

///|
pub fn RuntimeAudit::permission_manifest(
  self : RuntimeAudit,
) -> PermissionManifest {
  self.permission_manifest
}

///|
pub fn RuntimeAudit::registered_routes(self : RuntimeAudit) -> Array[String] {
  self.registered_routes.copy()
}

///|
pub fn RuntimeAudit::findings(
  self : RuntimeAudit,
) -> Array[RuntimeAuditFinding] {
  self.findings.copy()
}

///|
pub fn RuntimeAudit::route_exposures(
  self : RuntimeAudit,
) -> Array[RuntimeRouteExposure] {
  self.route_exposures.copy()
}

///|
pub fn RuntimeAudit::exposed_routes(self : RuntimeAudit) -> Array[String] {
  self.route_exposures
  .filter(fn(exposure) { exposure.exposed() })
  .map(fn(exposure) { exposure.route() })
}

///|
pub fn RuntimeAudit::findings_by_severity(
  self : RuntimeAudit,
  severity : RuntimeAuditSeverity,
) -> Array[RuntimeAuditFinding] {
  self.findings.filter(fn(finding) { finding.severity() == severity })
}

///|
pub fn RuntimeAudit::errors(self : RuntimeAudit) -> Array[RuntimeAuditFinding] {
  self.findings_by_severity(RuntimeAuditError)
}

///|
pub fn RuntimeAudit::warnings(
  self : RuntimeAudit,
) -> Array[RuntimeAuditFinding] {
  self.findings_by_severity(RuntimeAuditWarning)
}

///|
pub fn RuntimeAudit::infos(self : RuntimeAudit) -> Array[RuntimeAuditFinding] {
  self.findings_by_severity(RuntimeAuditInfo)
}

///|
pub fn RuntimeAudit::error_count(self : RuntimeAudit) -> Int {
  self.errors().length()
}

///|
pub fn RuntimeAudit::warning_count(self : RuntimeAudit) -> Int {
  self.warnings().length()
}

///|
pub fn RuntimeAudit::info_count(self : RuntimeAudit) -> Int {
  self.infos().length()
}

///|
pub fn RuntimeAudit::ok(self : RuntimeAudit) -> Bool {
  self.error_count() == 0
}

///|
pub fn RuntimeAudit::problems(self : RuntimeAudit) -> Array[String] {
  self.errors().map(fn(finding) { finding.message() })
}

///|
pub fn RuntimeAudit::to_json(self : RuntimeAudit) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"errorCount\":\{self.error_count()},",
    "\"warningCount\":\{self.warning_count()},",
    "\"infoCount\":\{self.info_count()},",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"exposedRoutes\":[\{self.exposed_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"routeExposures\":[\{self.route_exposures.map(fn(exposure) { exposure.to_json() }).join(",")}],",
    "\"findings\":[\{self.findings.map(fn(finding) { finding.to_json() }).join(",")}],",
    "\"commandManifest\":\{self.command_manifest.to_json()},",
    "\"permissionManifest\":\{self.permission_manifest.to_json()}",
    "}",
  ].join("")
}

///|
fn sorted_unique_routes(routes : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for route in routes {
    if !unique.contains(route) {
      unique.push(route)
    }
  }
  unique.sort()
  unique
}

///|
fn CommandMode::requires_registered_handler(self : CommandMode) -> Bool {
  match self {
    Sync | Async | Stream => true
    Event => false
  }
}

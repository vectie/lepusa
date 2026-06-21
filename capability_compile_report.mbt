///|
pub(all) enum CapabilityIssueSeverity {
  CapabilityWarning
  CapabilityError
} derive(Debug, Eq)

///|
pub fn CapabilityIssueSeverity::name(self : CapabilityIssueSeverity) -> String {
  match self {
    CapabilityWarning => "warning"
    CapabilityError => "error"
  }
}

///|
pub fn CapabilityIssueSeverity::is_error(
  self : CapabilityIssueSeverity,
) -> Bool {
  self is CapabilityError
}

///|
pub struct CapabilityCompileIssue {
  severity : CapabilityIssueSeverity
  code : String
  message : String
  plugin : String
  route : String
  permission : String
  capability : String
  window_label : String
} derive(Debug, Eq)

///|
fn CapabilityCompileIssue::new(
  severity~ : CapabilityIssueSeverity,
  code~ : String,
  message~ : String,
  plugin? : String = "",
  route? : String = "",
  permission? : String = "",
  capability? : String = "",
  window_label? : String = "",
) -> CapabilityCompileIssue {
  {
    severity,
    code,
    message,
    plugin,
    route,
    permission,
    capability,
    window_label,
  }
}

///|
pub fn CapabilityCompileIssue::severity(
  self : CapabilityCompileIssue,
) -> CapabilityIssueSeverity {
  self.severity
}

///|
pub fn CapabilityCompileIssue::code(self : CapabilityCompileIssue) -> String {
  self.code
}

///|
pub fn CapabilityCompileIssue::message(self : CapabilityCompileIssue) -> String {
  self.message
}

///|
pub fn CapabilityCompileIssue::plugin(self : CapabilityCompileIssue) -> String {
  self.plugin
}

///|
pub fn CapabilityCompileIssue::route(self : CapabilityCompileIssue) -> String {
  self.route
}

///|
pub fn CapabilityCompileIssue::permission(
  self : CapabilityCompileIssue,
) -> String {
  self.permission
}

///|
pub fn CapabilityCompileIssue::capability(
  self : CapabilityCompileIssue,
) -> String {
  self.capability
}

///|
pub fn CapabilityCompileIssue::window_label(
  self : CapabilityCompileIssue,
) -> String {
  self.window_label
}

///|
pub fn CapabilityCompileIssue::to_json(self : CapabilityCompileIssue) -> String {
  [
    "{",
    "\"severity\":\{self.severity.name().json_string()},",
    "\"code\":\{self.code.json_string()},",
    "\"message\":\{self.message.json_string()},",
    "\"plugin\":\{self.plugin.json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"permission\":\{self.permission.json_string()},",
    "\"capability\":\{self.capability.json_string()},",
    "\"windowLabel\":\{self.window_label.json_string()}",
    "}",
  ].join("")
}

///|
pub struct CapabilityCompileReport {
  plugin_contracts : Array[PluginContract]
  command_manifest : CommandManifest
  permission_manifest : PermissionManifest
  issues : Array[CapabilityCompileIssue]
} derive(Debug, Eq)

///|
pub fn CapabilityCompileReport::from_plugins(
  plugins~ : Array[Plugin],
  capabilities~ : Array[Capability],
  windows~ : Array[ResolvedWindow],
) -> CapabilityCompileReport {
  let command_manifest = CommandManifest::from_plugins(
    plugins~,
    capabilities~,
    windows~,
  )
  let permission_manifest = PermissionManifest::from_command_manifest(
    command_manifest,
    capabilities~,
  )
  let plugin_contracts = plugins.map(fn(plugin) { plugin.contract() })
  let issues = capability_compile_issues(
    plugin_contracts~,
    command_manifest,
    permission_manifest,
    capabilities~,
    windows~,
  )
  { plugin_contracts, command_manifest, permission_manifest, issues }
}

///|
pub fn RuntimePlan::capability_report(
  self : RuntimePlan,
) -> CapabilityCompileReport {
  CapabilityCompileReport::from_plugins(
    plugins=self.launch.plugins(),
    capabilities=self.capabilities(),
    windows=self.windows(),
  )
}

///|
pub fn CapabilityCompileReport::plugin_contracts(
  self : CapabilityCompileReport,
) -> Array[PluginContract] {
  self.plugin_contracts.copy()
}

///|
pub fn CapabilityCompileReport::command_manifest(
  self : CapabilityCompileReport,
) -> CommandManifest {
  self.command_manifest
}

///|
pub fn CapabilityCompileReport::permission_manifest(
  self : CapabilityCompileReport,
) -> PermissionManifest {
  self.permission_manifest
}

///|
pub fn CapabilityCompileReport::issues(
  self : CapabilityCompileReport,
) -> Array[CapabilityCompileIssue] {
  self.issues.copy()
}

///|
pub fn CapabilityCompileReport::errors(
  self : CapabilityCompileReport,
) -> Array[CapabilityCompileIssue] {
  self.issues.filter(fn(issue) { issue.severity().is_error() })
}

///|
pub fn CapabilityCompileReport::warnings(
  self : CapabilityCompileReport,
) -> Array[CapabilityCompileIssue] {
  self.issues.filter(fn(issue) { !issue.severity().is_error() })
}

///|
pub fn CapabilityCompileReport::ok(self : CapabilityCompileReport) -> Bool {
  self.errors().is_empty()
}

///|
pub fn CapabilityCompileReport::error_count(
  self : CapabilityCompileReport,
) -> Int {
  self.errors().length()
}

///|
pub fn CapabilityCompileReport::warning_count(
  self : CapabilityCompileReport,
) -> Int {
  self.warnings().length()
}

///|
pub fn CapabilityCompileReport::denied_routes(
  self : CapabilityCompileReport,
) -> Array[String] {
  self.permission_manifest.denied_routes()
}

///|
pub fn CapabilityCompileReport::unused_permissions(
  self : CapabilityCompileReport,
) -> Array[String] {
  let permissions : Array[String] = []
  for permission in self.permission_manifest.permissions() {
    if permission.commands().is_empty() && !permission.grants().is_empty() {
      permissions.push(permission.name())
    }
  }
  permissions
}

///|
pub fn CapabilityCompileReport::unknown_windows(
  self : CapabilityCompileReport,
) -> Array[String] {
  let windows : Array[String] = []
  for issue in self.issues {
    if issue.code() == "unknown-window" &&
      issue.window_label() != "" &&
      !windows.contains(issue.window_label()) {
      windows.push(issue.window_label())
    }
  }
  windows
}

///|
pub fn CapabilityCompileReport::to_json(
  self : CapabilityCompileReport,
) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"errorCount\":\{self.error_count()},",
    "\"warningCount\":\{self.warning_count()},",
    "\"pluginContracts\":[\{self.plugin_contracts.map(fn(contract) { contract.to_json() }).join(",")}],",
    "\"commandManifest\":\{self.command_manifest.to_json()},",
    "\"permissionManifest\":\{self.permission_manifest.to_json()},",
    "\"issues\":[\{self.issues.map(fn(issue) { issue.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn capability_compile_issues(
  plugin_contracts~ : Array[PluginContract],
  command_manifest : CommandManifest,
  permission_manifest : PermissionManifest,
  capabilities~ : Array[Capability],
  windows~ : Array[ResolvedWindow],
) -> Array[CapabilityCompileIssue] {
  let issues : Array[CapabilityCompileIssue] = []
  for contract in plugin_contracts {
    for problem in contract.problems() {
      issues.push(
        CapabilityCompileIssue::new(
          severity=CapabilityError,
          code="plugin-invalid",
          message=problem,
          plugin=contract.name(),
        ),
      )
    }
  }
  for problem in CapabilityPolicy::new(capabilities~).validate() {
    issues.push(
      CapabilityCompileIssue::new(
        severity=CapabilityError,
        code="capability-invalid",
        message=problem,
      ),
    )
  }
  append_unknown_window_issues(issues, capabilities, windows)
  append_unscoped_operation_issues(issues, capabilities)
  append_denied_route_issues(issues, command_manifest)
  append_unused_permission_issues(issues, permission_manifest)
  issues
}

///|
fn append_unknown_window_issues(
  issues : Array[CapabilityCompileIssue],
  capabilities : Array[Capability],
  windows : Array[ResolvedWindow],
) -> Unit {
  let labels = windows.map(fn(window) { window.label() })
  for capability in capabilities {
    for window in capability.windows() {
      if !labels.contains(window) {
        issues.push(
          CapabilityCompileIssue::new(
            severity=CapabilityError,
            code="unknown-window",
            message="capability references unknown window: \{window}",
            capability=capability.name(),
            window_label=window,
          ),
        )
      }
    }
  }
}

///|
fn append_denied_route_issues(
  issues : Array[CapabilityCompileIssue],
  manifest : CommandManifest,
) -> Unit {
  for command in manifest.entries() {
    if command.allowed_windows().is_empty() {
      issues.push(
        CapabilityCompileIssue::new(
          severity=CapabilityError,
          code="permission-ungranted",
          message="command has no capability grant for any window: \{command.route()}",
          plugin=command.plugin(),
          route=command.route(),
          permission=command.permission().name(),
        ),
      )
    }
  }
}

///|
fn append_unscoped_operation_issues(
  issues : Array[CapabilityCompileIssue],
  capabilities : Array[Capability],
) -> Unit {
  for capability in capabilities {
    for permission in capability.permissions() {
      match required_operation_scope_kind(permission) {
        Some(kind) =>
          if capability.operation_scopes_by_kind(kind).is_empty() {
            issues.push(
              CapabilityCompileIssue::new(
                severity=CapabilityWarning,
                code="operation-scope-missing",
                message="permission grant has no \{kind.name()} operation scope: \{permission.name()}",
                permission=permission.name(),
                capability=capability.name(),
              ),
            )
          }
        None => ()
      }
    }
  }
}

///|
fn required_operation_scope_kind(
  permission : Permission,
) -> OperationScopeKind? {
  match permission {
    FileSystemRead | FileSystemWrite => Some(PathOperation)
    Shell => Some(ShellOperation)
    Network => Some(UrlOperation)
    _ => None
  }
}

///|
fn append_unused_permission_issues(
  issues : Array[CapabilityCompileIssue],
  manifest : PermissionManifest,
) -> Unit {
  for permission in manifest.permissions() {
    if permission.commands().is_empty() && !permission.grants().is_empty() {
      issues.push(
        CapabilityCompileIssue::new(
          severity=CapabilityWarning,
          code="permission-unused",
          message="permission is granted but no command requires it: \{permission.name()}",
          permission=permission.name(),
        ),
      )
    }
  }
}

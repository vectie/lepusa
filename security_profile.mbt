///|
pub struct SecurityProfile {
  command_manifest : CommandManifest
  permission_manifest : PermissionManifest
  capability_policy : CapabilityPolicy
  capability_report : CapabilityCompileReport
  runtime_audit : RuntimeAudit
  registered_routes : Array[String]
  check_handlers : Bool
  platform : String
} derive(Debug, Eq)

///|
pub fn SecurityProfile::from_plan(
  plan : RuntimePlan,
  registered_routes? : Array[String] = [],
  check_handlers? : Bool = false,
) -> SecurityProfile {
  let registered_routes = security_profile_sorted_unique(registered_routes)
  let command_manifest = plan.command_manifest()
  let permission_manifest = plan.permission_manifest()
  let capability_policy = CapabilityPolicy::new(
    capabilities=plan.capabilities(),
  )
  let capability_report = plan.capability_report()
  let runtime_audit = if check_handlers {
    plan.audit_with_registered_routes(registered_routes)
  } else {
    plan.audit()
  }
  {
    command_manifest,
    permission_manifest,
    capability_policy,
    capability_report,
    runtime_audit,
    registered_routes,
    check_handlers,
    platform: plan.platform(),
  }
}

///|
pub fn RuntimePlan::security_profile(
  self : RuntimePlan,
  registered_routes? : Array[String] = [],
  check_handlers? : Bool = false,
) -> SecurityProfile {
  SecurityProfile::from_plan(self, registered_routes~, check_handlers~)
}

///|
pub fn AppManager::security_profile(self : AppManager) -> SecurityProfile {
  self
  .plan()
  .security_profile(
    registered_routes=self.registered_routes(),
    check_handlers=true,
  )
}

///|
pub fn SecurityProfile::command_manifest(
  self : SecurityProfile,
) -> CommandManifest {
  self.command_manifest
}

///|
pub fn SecurityProfile::permission_manifest(
  self : SecurityProfile,
) -> PermissionManifest {
  self.permission_manifest
}

///|
pub fn SecurityProfile::capability_policy(
  self : SecurityProfile,
) -> CapabilityPolicy {
  self.capability_policy
}

///|
pub fn SecurityProfile::capability_report(
  self : SecurityProfile,
) -> CapabilityCompileReport {
  self.capability_report
}

///|
pub fn SecurityProfile::runtime_audit(self : SecurityProfile) -> RuntimeAudit {
  self.runtime_audit
}

///|
pub fn SecurityProfile::registered_routes(
  self : SecurityProfile,
) -> Array[String] {
  self.registered_routes.copy()
}

///|
pub fn SecurityProfile::check_handlers(self : SecurityProfile) -> Bool {
  self.check_handlers
}

///|
pub fn SecurityProfile::platform(self : SecurityProfile) -> String {
  self.platform
}

///|
pub fn SecurityProfile::ok(self : SecurityProfile) -> Bool {
  self.capability_report.ok() && self.runtime_audit.ok()
}

///|
pub fn SecurityProfile::error_count(self : SecurityProfile) -> Int {
  self.capability_report.error_count() + self.runtime_audit.error_count()
}

///|
pub fn SecurityProfile::warning_count(self : SecurityProfile) -> Int {
  self.capability_report.warning_count() + self.runtime_audit.warning_count()
}

///|
pub fn SecurityProfile::info_count(self : SecurityProfile) -> Int {
  self.runtime_audit.info_count()
}

///|
pub fn SecurityProfile::problems(self : SecurityProfile) -> Array[String] {
  let problems : Array[String] = []
  for issue in self.capability_report.errors() {
    security_profile_push_unique(problems, issue.message())
  }
  for problem in self.runtime_audit.problems() {
    security_profile_push_unique(problems, problem)
  }
  problems
}

///|
pub fn SecurityProfile::exposed_routes(self : SecurityProfile) -> Array[String] {
  self.runtime_audit.exposed_routes()
}

///|
pub fn SecurityProfile::denied_routes(self : SecurityProfile) -> Array[String] {
  self.capability_report.denied_routes()
}

///|
pub fn SecurityProfile::unused_permissions(
  self : SecurityProfile,
) -> Array[String] {
  self.capability_report.unused_permissions()
}

///|
pub fn SecurityProfile::allowed_origins(
  self : SecurityProfile,
  window_label~ : String,
  permission~ : Permission,
) -> Array[String] {
  self.capability_policy.allowed_origins(
    window_label~,
    permission~,
    platform=self.platform,
  )
}

///|
pub fn SecurityProfile::allows(
  self : SecurityProfile,
  window_label~ : String,
  permission~ : Permission,
  origin? : String = "",
) -> Bool {
  self.capability_policy.allows(
    window_label~,
    permission~,
    origin~,
    platform=self.platform,
  )
}

///|
pub fn SecurityProfile::evaluate(
  self : SecurityProfile,
  window_label~ : String,
  permission~ : Permission,
  origin? : String = "",
) -> CapabilityDecision {
  self.capability_policy.evaluate(
    window_label~,
    permission~,
    origin~,
    platform=self.platform,
  )
}

///|
pub fn SecurityProfile::allows_operation(
  self : SecurityProfile,
  window_label~ : String,
  permission~ : Permission,
  scope~ : OperationScope,
  origin? : String = "",
) -> Bool {
  self.capability_policy.allows_operation(
    window_label~,
    permission~,
    scope~,
    origin~,
    platform=self.platform,
  )
}

///|
pub fn SecurityProfile::evaluate_operation(
  self : SecurityProfile,
  window_label~ : String,
  permission~ : Permission,
  scope~ : OperationScope,
  origin? : String = "",
) -> CapabilityDecision {
  self.capability_policy.evaluate_operation(
    window_label~,
    permission~,
    scope~,
    origin~,
    platform=self.platform,
  )
}

///|
pub fn SecurityProfile::authorize_invoke(
  self : SecurityProfile,
  request : InvokeRequest,
) -> RuntimeInvokeAuthorization {
  self.authorize_request(request, operation_scope=None)
}

///|
pub fn SecurityProfile::authorize_operation(
  self : SecurityProfile,
  request : InvokeRequest,
  scope : OperationScope,
) -> RuntimeInvokeAuthorization {
  self.authorize_request(request, operation_scope=Some(scope))
}

///|
pub fn SecurityProfile::to_json(self : SecurityProfile) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"errorCount\":\{self.error_count()},",
    "\"warningCount\":\{self.warning_count()},",
    "\"infoCount\":\{self.info_count()},",
    "\"checkHandlers\":\{self.check_handlers.json_bool()},",
    "\"platform\":\{self.platform.json_string()},",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"exposedRoutes\":[\{self.exposed_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"problems\":[\{self.problems().map(fn(problem) { problem.json_string() }).join(",")}],",
    "\"capabilityReport\":\{self.capability_report.to_json()},",
    "\"runtimeAudit\":\{self.runtime_audit.to_json()}",
    "}",
  ].join("")
}

///|
fn SecurityProfile::authorize_request(
  self : SecurityProfile,
  request : InvokeRequest,
  operation_scope~ : OperationScope?,
) -> RuntimeInvokeAuthorization {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return RuntimeInvokeAuthorization::invalid(
      request,
      reason=request_problems[0],
    )
  }
  let route = request.route()
  let registered = self.registered_routes.contains(route)
  match self.command_manifest.entry(route) {
    None =>
      RuntimeInvokeAuthorization::deny(
        kind=RuntimeInvokeUnknownCommand,
        request,
        platform=self.platform,
        registered~,
        reason="command is not declared: \{route}",
      )
    Some(entry) => {
      if self.check_handlers &&
        entry.mode().requires_registered_handler() &&
        !registered {
        return RuntimeInvokeAuthorization::deny(
          kind=RuntimeInvokeUnregisteredCommand,
          request,
          platform=self.platform,
          permission=entry.permission(),
          registered~,
          reason="command has no registered native handler: \{route}",
        )
      }
      let decision = match operation_scope {
        Some(scope) =>
          self.capability_policy.evaluate_operation(
            window_label=request.window_label(),
            permission=entry.permission(),
            scope~,
            origin=request.origin(),
            platform=self.platform,
          )
        None =>
          self.capability_policy.evaluate(
            window_label=request.window_label(),
            permission=entry.permission(),
            origin=request.origin(),
            platform=self.platform,
          )
      }
      if decision.allowed() {
        RuntimeInvokeAuthorization::allow(
          request,
          platform=self.platform,
          permission=entry.permission(),
          registered~,
          capability=decision.capability(),
        )
      } else {
        RuntimeInvokeAuthorization::deny(
          kind=RuntimeInvokePermissionDenied,
          request,
          platform=self.platform,
          permission=entry.permission(),
          registered~,
          reason=decision.reason(),
        )
      }
    }
  }
}

///|
fn security_profile_sorted_unique(routes : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for route in routes {
    security_profile_push_unique(unique, route)
  }
  unique.sort()
  unique
}

///|
fn security_profile_push_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
pub struct NativeEvaluationScript {
  window_label : String
  script : String
} derive(Debug, Eq)

///|
pub struct NativeNavigation {
  window_label : String
  url : String
} derive(Debug, Eq)

///|
pub struct NativeBridgeDrain {
  window_label : String
  callback : String
} derive(Debug, Eq)

///|
pub struct NativeWindowControl {
  window_label : String
  action : String
  payload : String
} derive(Debug, Eq)

///|
pub struct NativeWindowClose {
  window_label : String
} derive(Debug, Eq)

///|
pub struct NativeBridgeLoopEvaluationPlan {
  window_label : String
  operations : Array[NativeExecutableOperation]
} derive(Debug, Eq)

///|
pub(all) enum NativeExecutableOperation {
  NativeExecutableStartService(@lepusa.LocalService)
  NativeExecutableOpenWindow(RuntimeWindowOpenPlan)
  NativeExecutableCloseWindow(NativeWindowClose)
  NativeExecutableEvaluateScript(NativeEvaluationScript)
  NativeExecutableDrainBridge(NativeBridgeDrain)
  NativeExecutableRunEffect(String)
  NativeExecutableNavigate(NativeNavigation)
  NativeExecutableWindowControl(NativeWindowControl)
} derive(Debug, Eq)

///|
pub fn NativeEvaluationScript::new(
  window_label~ : String,
  script~ : String,
) -> NativeEvaluationScript {
  { window_label, script }
}

///|
pub fn NativeNavigation::new(
  window_label~ : String,
  url~ : String,
) -> NativeNavigation {
  { window_label, url }
}

///|
pub fn NativeBridgeDrain::new(
  window_label~ : String,
  callback~ : String,
) -> NativeBridgeDrain {
  { window_label, callback }
}

///|
pub fn NativeWindowControl::new(
  window_label~ : String,
  action~ : String,
  payload? : String = "",
) -> NativeWindowControl {
  { window_label, action, payload }
}

///|
pub fn NativeWindowClose::new(window_label~ : String) -> NativeWindowClose {
  { window_label, }
}

///|
pub fn NativeBridgeLoopEvaluationPlan::new(
  window_label~ : String,
  operations~ : Array[NativeExecutableOperation],
) -> NativeBridgeLoopEvaluationPlan {
  { window_label, operations }
}

///|
pub fn NativeBridgeLoopEvaluationPlan::from_scripts(
  window_label~ : String,
  scripts~ : Array[String],
) -> NativeBridgeLoopEvaluationPlan {
  NativeBridgeLoopEvaluationPlan::new(
    window_label~,
    operations=scripts.map(fn(script) {
      NativeExecutableOperation::evaluate_script(
        NativeEvaluationScript::new(window_label~, script~),
      )
    }),
  )
}

///|
pub fn NativeEvaluationScript::window_label(
  self : NativeEvaluationScript,
) -> String {
  self.window_label
}

///|
pub fn NativeEvaluationScript::script(self : NativeEvaluationScript) -> String {
  self.script
}

///|
pub fn NativeEvaluationScript::to_json(self : NativeEvaluationScript) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"script\":\{self.script.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeNavigation::window_label(self : NativeNavigation) -> String {
  self.window_label
}

///|
pub fn NativeNavigation::url(self : NativeNavigation) -> String {
  self.url
}

///|
pub fn NativeNavigation::to_json(self : NativeNavigation) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"url\":\{self.url.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeBridgeDrain::window_label(self : NativeBridgeDrain) -> String {
  self.window_label
}

///|
pub fn NativeBridgeDrain::callback(self : NativeBridgeDrain) -> String {
  self.callback
}

///|
pub fn NativeBridgeDrain::to_json(self : NativeBridgeDrain) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"callback\":\{self.callback.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeWindowControl::window_label(self : NativeWindowControl) -> String {
  self.window_label
}

///|
pub fn NativeWindowControl::action(self : NativeWindowControl) -> String {
  self.action
}

///|
pub fn NativeWindowControl::payload(self : NativeWindowControl) -> String {
  self.payload
}

///|
pub fn NativeWindowControl::to_json(self : NativeWindowControl) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"action\":\{self.action.json_string()},",
    "\"payload\":\{self.payload.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeWindowClose::window_label(self : NativeWindowClose) -> String {
  self.window_label
}

///|
pub fn NativeWindowClose::to_json(self : NativeWindowClose) -> String {
  ["{", "\"windowLabel\":\{self.window_label.json_string()}", "}"].join("")
}

///|
pub fn NativeBridgeLoopEvaluationPlan::window_label(
  self : NativeBridgeLoopEvaluationPlan,
) -> String {
  self.window_label
}

///|
pub fn NativeBridgeLoopEvaluationPlan::operations(
  self : NativeBridgeLoopEvaluationPlan,
) -> Array[NativeExecutableOperation] {
  self.operations.copy()
}

///|
pub fn NativeBridgeLoopEvaluationPlan::evaluation_scripts(
  self : NativeBridgeLoopEvaluationPlan,
) -> Array[NativeEvaluationScript] {
  let scripts : Array[NativeEvaluationScript] = []
  for operation in self.operations {
    match operation.evaluation_script() {
      Some(script) => scripts.push(script)
      None => ()
    }
  }
  scripts
}

///|
pub fn NativeBridgeLoopEvaluationPlan::is_empty(
  self : NativeBridgeLoopEvaluationPlan,
) -> Bool {
  self.operations.length() == 0
}

///|
pub fn NativeBridgeLoopEvaluationPlan::to_json(
  self : NativeBridgeLoopEvaluationPlan,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"operations\":[\{self.operations.map(fn(operation) { operation.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeExecutableOperation::start_service(
  service : @lepusa.LocalService,
) -> NativeExecutableOperation {
  NativeExecutableStartService(service)
}

///|
pub fn NativeExecutableOperation::evaluate_script(
  script : NativeEvaluationScript,
) -> NativeExecutableOperation {
  NativeExecutableEvaluateScript(script)
}

///|
pub fn NativeExecutableOperation::open_window(
  open_plan : RuntimeWindowOpenPlan,
) -> NativeExecutableOperation {
  NativeExecutableOpenWindow(open_plan)
}

///|
pub fn NativeExecutableOperation::close_window(
  close : NativeWindowClose,
) -> NativeExecutableOperation {
  NativeExecutableCloseWindow(close)
}

///|
pub fn NativeExecutableOperation::drain_bridge(
  drain : NativeBridgeDrain,
) -> NativeExecutableOperation {
  NativeExecutableDrainBridge(drain)
}

///|
pub fn NativeExecutableOperation::run_effect(
  name : String,
) -> NativeExecutableOperation {
  NativeExecutableRunEffect(name)
}

///|
pub fn NativeExecutableOperation::navigate(
  navigation : NativeNavigation,
) -> NativeExecutableOperation {
  NativeExecutableNavigate(navigation)
}

///|
pub fn NativeExecutableOperation::window_control(
  control : NativeWindowControl,
) -> NativeExecutableOperation {
  NativeExecutableWindowControl(control)
}

///|
pub fn NativeExecutableOperation::kind(
  self : NativeExecutableOperation,
) -> String {
  match self {
    NativeExecutableStartService(_) => "start-service"
    NativeExecutableOpenWindow(_) => "open-window"
    NativeExecutableCloseWindow(_) => "close-window"
    NativeExecutableEvaluateScript(_) => "evaluate-script"
    NativeExecutableDrainBridge(_) => "drain-bridge-window"
    NativeExecutableRunEffect(_) => "run-effect"
    NativeExecutableNavigate(_) => "navigate-window"
    NativeExecutableWindowControl(_) => "window-control"
  }
}

///|
pub fn NativeExecutableOperation::service(
  self : NativeExecutableOperation,
) -> @lepusa.LocalService? {
  match self {
    NativeExecutableStartService(service) => Some(service)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::open_window_plan(
  self : NativeExecutableOperation,
) -> RuntimeWindowOpenPlan? {
  match self {
    NativeExecutableOpenWindow(open_plan) => Some(open_plan)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::close_window_operation(
  self : NativeExecutableOperation,
) -> NativeWindowClose? {
  match self {
    NativeExecutableCloseWindow(close) => Some(close)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::evaluation_script(
  self : NativeExecutableOperation,
) -> NativeEvaluationScript? {
  match self {
    NativeExecutableEvaluateScript(script) => Some(script)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::bridge_drain(
  self : NativeExecutableOperation,
) -> NativeBridgeDrain? {
  match self {
    NativeExecutableDrainBridge(drain) => Some(drain)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::effect_name(
  self : NativeExecutableOperation,
) -> String? {
  match self {
    NativeExecutableRunEffect(name) => Some(name)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::navigation(
  self : NativeExecutableOperation,
) -> NativeNavigation? {
  match self {
    NativeExecutableNavigate(navigation) => Some(navigation)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::window_control_operation(
  self : NativeExecutableOperation,
) -> NativeWindowControl? {
  match self {
    NativeExecutableWindowControl(control) => Some(control)
    _ => None
  }
}

///|
pub fn NativeExecutableOperation::window_label(
  self : NativeExecutableOperation,
) -> String? {
  match self.evaluation_script() {
    Some(script) => Some(script.window_label())
    None =>
      match self.open_window_plan() {
        Some(open_plan) => Some(open_plan.label())
        None =>
          match self.close_window_operation() {
            Some(close) => Some(close.window_label())
            None =>
              match self.bridge_drain() {
                Some(drain) => Some(drain.window_label())
                None =>
                  match self.navigation() {
                    Some(navigation) => Some(navigation.window_label())
                    None =>
                      match self.window_control_operation() {
                        Some(control) => Some(control.window_label())
                        None => None
                      }
                  }
              }
          }
      }
  }
}

///|
pub fn NativeExecutableOperation::to_json(
  self : NativeExecutableOperation,
) -> String {
  match self {
    NativeExecutableStartService(service) =>
      [
        "{",
        "\"kind\":\"start-service\",",
        "\"service\":\{service.to_json()}",
        "}",
      ].join("")
    NativeExecutableOpenWindow(open_plan) =>
      [
        "{",
        "\"kind\":\"open-window\",",
        "\"window\":\{open_plan.to_json()}",
        "}",
      ].join("")
    NativeExecutableCloseWindow(close) =>
      [
        "{",
        "\"kind\":\"close-window\",",
        "\"windowLabel\":\{close.window_label().json_string()}",
        "}",
      ].join("")
    NativeExecutableEvaluateScript(script) =>
      [
        "{",
        "\"kind\":\"evaluate-script\",",
        "\"windowLabel\":\{script.window_label().json_string()},",
        "\"script\":\{script.script().json_string()}",
        "}",
      ].join("")
    NativeExecutableDrainBridge(drain) =>
      [
        "{",
        "\"kind\":\"drain-bridge-window\",",
        "\"windowLabel\":\{drain.window_label().json_string()},",
        "\"callback\":\{drain.callback().json_string()}",
        "}",
      ].join("")
    NativeExecutableRunEffect(name) =>
      ["{", "\"kind\":\"run-effect\",", "\"name\":\{name.json_string()}", "}"].join(
        "",
      )
    NativeExecutableNavigate(navigation) =>
      [
        "{",
        "\"kind\":\"navigate-window\",",
        "\"windowLabel\":\{navigation.window_label().json_string()},",
        "\"url\":\{navigation.url().json_string()}",
        "}",
      ].join("")
    NativeExecutableWindowControl(control) =>
      [
        "{",
        "\"kind\":\"window-control\",",
        "\"windowLabel\":\{control.window_label().json_string()},",
        "\"action\":\{control.action().json_string()},",
        "\"payload\":\{control.payload().json_string()}",
        "}",
      ].join("")
  }
}

///|
pub fn native_executable_operations_packet(
  operations : Array[NativeExecutableOperation],
) -> String {
  [
    "lepusa-ops-v2\n",
    "\{operations.length()}\n",
    operations.map(fn(operation) { operation.native_packet_record() }).join(""),
  ].join("")
}

///|
fn NativeExecutableOperation::native_packet_record(
  self : NativeExecutableOperation,
) -> String {
  let (
    window_label,
    action,
    url,
    title,
    width,
    height,
    x,
    y,
    fullscreen,
    bridge_source,
    native_hook,
    asset_protocol,
  ) = match self {
    NativeExecutableOpenWindow(open_plan) =>
      (
        open_plan.label(),
        "",
        open_plan.url(),
        open_plan.window().title(),
        open_plan.window().width().to_string(),
        open_plan.window().height().to_string(),
        "",
        "",
        "",
        open_plan.bridge_source(),
        open_plan.native_hook(),
        open_plan.asset_protocol(),
      )
    NativeExecutableCloseWindow(close) =>
      (close.window_label(), "", "", "", "", "", "", "", "", "", "", "")
    NativeExecutableEvaluateScript(script) =>
      (script.window_label(), "", "", "", "", "", "", "", "", "", "", "")
    NativeExecutableDrainBridge(drain) =>
      (drain.window_label(), "", "", "", "", "", "", "", "", "", "", "")
    NativeExecutableNavigate(navigation) =>
      (
        navigation.window_label(),
        "",
        navigation.url(),
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
      )
    NativeExecutableWindowControl(control) =>
      (
        control.window_label(),
        control.action(),
        "",
        control.payload_string("title"),
        control.payload_int("width"),
        control.payload_int("height"),
        control.payload_int("x"),
        control.payload_int("y"),
        control.payload_bool("fullscreen"),
        "",
        "",
        "",
      )
    NativeExecutableRunEffect(name) =>
      ("", name, "", "", "", "", "", "", "", "", "", "")
    NativeExecutableStartService(_) =>
      ("", "", "", "", "", "", "", "", "", "", "", "")
  }
  [
    packet_field(self.kind()),
    packet_field(window_label),
    packet_field(action),
    packet_field(url),
    packet_field(title),
    packet_field(width),
    packet_field(height),
    packet_field(x),
    packet_field(y),
    packet_field(fullscreen),
    packet_field(bridge_source),
    packet_field(native_hook),
    packet_field(asset_protocol),
  ].join("")
}

///|
fn packet_field(value : String) -> String {
  "\{@utf8.encode(value).length()}\n\{value}"
}

///|
fn NativeWindowControl::payload_object(
  self : NativeWindowControl,
) -> Map[String, Json]? {
  let parsed = @json.parse(self.payload) catch { _ => return None }
  match parsed {
    Object(object) => Some(object)
    _ => None
  }
}

///|
fn NativeWindowControl::payload_string(
  self : NativeWindowControl,
  key : String,
) -> String {
  match self.payload_object() {
    Some(object) =>
      match object.get(key) {
        Some(String(value)) => value
        _ => ""
      }
    None => ""
  }
}

///|
fn NativeWindowControl::payload_int(
  self : NativeWindowControl,
  key : String,
) -> String {
  match self.payload_object() {
    Some(object) =>
      match object.get(key) {
        Some(Number(value, ..)) => value.to_int().to_string()
        _ => ""
      }
    None => ""
  }
}

///|
fn NativeWindowControl::payload_bool(
  self : NativeWindowControl,
  key : String,
) -> String {
  match self.payload_object() {
    Some(object) =>
      match object.get(key) {
        Some(True) => "true"
        Some(False) => "false"
        _ => ""
      }
    None =>
      if self.payload == "true" || self.payload == "false" {
        self.payload
      } else {
        ""
      }
  }
}

///|
pub fn NativeOperation::kind(self : NativeOperation) -> String {
  match self {
    NativeStartService(_) => "start-service"
    NativeOpenWindow(_) => "open-window"
    NativeCloseWindow(_) => "close-window"
    NativeDispatchEvent(_) => "evaluate-script"
    NativeRunEffect(_) => "run-effect"
    NativeNavigateWindow(_, _) => "navigate-window"
  }
}

///|
pub fn NativeOperation::executable(
  self : NativeOperation,
) -> NativeExecutableOperation {
  match self {
    NativeStartService(service) =>
      NativeExecutableOperation::start_service(service)
    NativeOpenWindow(open_plan) =>
      NativeExecutableOperation::open_window(open_plan)
    NativeCloseWindow(label) =>
      NativeExecutableOperation::close_window(
        NativeWindowClose::new(window_label=label),
      )
    NativeDispatchEvent(dispatch) =>
      NativeExecutableOperation::evaluate_script(
        NativeEvaluationScript::new(
          window_label=dispatch.window_label(),
          script=dispatch.script(),
        ),
      )
    NativeRunEffect(name) => NativeExecutableOperation::run_effect(name)
    NativeNavigateWindow(window_label, url) =>
      NativeExecutableOperation::navigate(
        NativeNavigation::new(window_label~, url~),
      )
  }
}

///|
pub fn NativeOperation::service(
  self : NativeOperation,
) -> @lepusa.LocalService? {
  match self {
    NativeStartService(service) => Some(service)
    _ => None
  }
}

///|
pub fn NativeOperation::evaluation_script(
  self : NativeOperation,
) -> NativeEvaluationScript? {
  match self {
    NativeDispatchEvent(dispatch) =>
      Some(
        NativeEvaluationScript::new(
          window_label=dispatch.window_label(),
          script=dispatch.script(),
        ),
      )
    _ => None
  }
}

///|
pub fn NativeOperation::open_window_plan(
  self : NativeOperation,
) -> RuntimeWindowOpenPlan? {
  match self {
    NativeOpenWindow(open_plan) => Some(open_plan)
    _ => None
  }
}

///|
pub fn NativeOperation::close_window_operation(
  self : NativeOperation,
) -> NativeWindowClose? {
  match self {
    NativeCloseWindow(label) => Some(NativeWindowClose::new(window_label=label))
    _ => None
  }
}

///|
pub fn NativeOperation::effect_name(self : NativeOperation) -> String? {
  match self {
    NativeRunEffect(name) => Some(name)
    _ => None
  }
}

///|
pub fn NativeOperation::navigation(self : NativeOperation) -> NativeNavigation? {
  match self {
    NativeNavigateWindow(window_label, url) =>
      Some(NativeNavigation::new(window_label~, url~))
    _ => None
  }
}

///|
pub fn NativeOperation::window_label(self : NativeOperation) -> String? {
  match self.evaluation_script() {
    Some(script) => Some(script.window_label())
    None =>
      match self.open_window_plan() {
        Some(open_plan) => Some(open_plan.label())
        None =>
          match self.close_window_operation() {
            Some(close) => Some(close.window_label())
            None =>
              match self.navigation() {
                Some(navigation) => Some(navigation.window_label())
                None => None
              }
          }
      }
  }
}

///|
pub fn NativeRunnerPlan::startup_executable_operations(
  self : NativeRunnerPlan,
) -> Array[NativeExecutableOperation] {
  native_executable_operations(self.startup_operations())
}

///|
pub fn NativeRunnerPlan::startup_evaluation_scripts(
  self : NativeRunnerPlan,
) -> Array[NativeEvaluationScript] {
  native_evaluation_scripts(self.startup_operations())
}

///|
pub fn NativeRunnerPlan::startup_navigations(
  self : NativeRunnerPlan,
) -> Array[NativeNavigation] {
  native_navigations(self.startup_operations())
}

///|
pub fn NativeRunnerStep::executable_operations(
  self : NativeRunnerStep,
) -> Array[NativeExecutableOperation] {
  native_executable_operations(self.operations())
}

///|
pub fn NativeRunnerStep::evaluation_scripts(
  self : NativeRunnerStep,
) -> Array[NativeEvaluationScript] {
  native_evaluation_scripts(self.operations())
}

///|
pub fn NativeRunnerStep::navigations(
  self : NativeRunnerStep,
) -> Array[NativeNavigation] {
  native_navigations(self.operations())
}

///|
fn native_executable_operations(
  operations : Array[NativeOperation],
) -> Array[NativeExecutableOperation] {
  operations.map(fn(operation) { operation.executable() })
}

///|
fn native_evaluation_scripts(
  operations : Array[NativeOperation],
) -> Array[NativeEvaluationScript] {
  let scripts : Array[NativeEvaluationScript] = []
  for operation in operations {
    match operation.evaluation_script() {
      Some(script) => scripts.push(script)
      None => ()
    }
  }
  scripts
}

///|
fn native_navigations(
  operations : Array[NativeOperation],
) -> Array[NativeNavigation] {
  let navigations : Array[NativeNavigation] = []
  for operation in operations {
    match operation.navigation() {
      Some(navigation) => navigations.push(navigation)
      None => ()
    }
  }
  navigations
}

///|
fn native_executable_evaluation_scripts(
  operations : Array[NativeExecutableOperation],
) -> Array[NativeEvaluationScript] {
  let scripts : Array[NativeEvaluationScript] = []
  for operation in operations {
    match operation.evaluation_script() {
      Some(script) => scripts.push(script)
      None => ()
    }
  }
  scripts
}

///|
fn native_executable_navigations(
  operations : Array[NativeExecutableOperation],
) -> Array[NativeNavigation] {
  let navigations : Array[NativeNavigation] = []
  for operation in operations {
    match operation.navigation() {
      Some(navigation) => navigations.push(navigation)
      None => ()
    }
  }
  navigations
}

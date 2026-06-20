///|
pub type ViewDispatch[Msg] = (Msg) -> Attr

///|
pub type UiUpdate[Model, Msg] = (Msg, Model) -> (Model, @lepusa.Cmd)

///|
pub type UiView[Model, Msg] = (ViewDispatch[Msg], Model) -> @lepusa.Html

///|
pub type UiEncode[Msg] = (Msg) -> String

///|
pub type UiDecode[Msg] = (String) -> Result[Msg, String]

///|
pub struct UiProgram[Model, Msg] {
  model : Model
  update : UiUpdate[Model, Msg]
  view : UiView[Model, Msg]
  encode : UiEncode[Msg]
  decode : UiDecode[Msg]
  route : String
  render_event : String
  window_label : String
  root_id : String
}

///|
pub fn[Model, Msg] UiProgram::new(
  model~ : Model,
  update~ : UiUpdate[Model, Msg],
  view~ : UiView[Model, Msg],
  encode~ : UiEncode[Msg],
  decode~ : UiDecode[Msg],
  route? : String = "ui.dispatch",
  render_event? : String = "ui.render",
  window_label? : String = "main",
  root_id? : String = "lepusa-root",
) -> UiProgram[Model, Msg] {
  {
    model,
    update,
    view,
    encode,
    decode,
    route,
    render_event,
    window_label,
    root_id,
  }
}

///|
pub fn[Model, Msg] UiProgram::model(self : UiProgram[Model, Msg]) -> Model {
  self.model
}

///|
pub fn[Model, Msg] UiProgram::route(self : UiProgram[Model, Msg]) -> String {
  self.route
}

///|
pub fn[Model, Msg] UiProgram::render_event(
  self : UiProgram[Model, Msg],
) -> String {
  self.render_event
}

///|
pub fn[Model, Msg] UiProgram::window_label(
  self : UiProgram[Model, Msg],
) -> String {
  self.window_label
}

///|
pub fn[Model, Msg] UiProgram::root_id(self : UiProgram[Model, Msg]) -> String {
  self.root_id
}

///|
pub fn[Model, Msg] UiProgram::validate(
  self : UiProgram[Model, Msg],
) -> Array[String] {
  let problems : Array[String] = []
  if self.route == "" {
    problems.push("ui program route is required")
  } else {
    let (plugin, command) = self.route_parts()
    if plugin == "" || command == "" {
      problems.push("ui program route must be plugin.command")
    }
  }
  if self.render_event == "" {
    problems.push("ui program render event is required")
  }
  if self.window_label == "" {
    problems.push("ui program window label is required")
  }
  if self.root_id == "" {
    problems.push("ui program root id is required")
  }
  problems
}

///|
pub fn[Model, Msg] UiProgram::dispatch_attr(
  self : UiProgram[Model, Msg],
  message : Msg,
) -> Attr {
  attr("onclick", self.dispatch_script(message))
}

///|
pub fn[Model, Msg] UiProgram::plugin(
  self : UiProgram[Model, Msg],
) -> @lepusa.Plugin {
  let (plugin, command) = self.route_parts()
  @lepusa.Plugin::new(plugin).command_sync(command)
}

///|
pub fn[Model, Msg] UiProgram::capability(
  self : UiProgram[Model, Msg],
  name? : String = "ui",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name).command(self.route)
}

///|
pub fn[Model, Msg] UiProgram::capability_for_window(
  self : UiProgram[Model, Msg],
  name? : String = "ui",
) -> @lepusa.Capability {
  self.capability(name~).window(self.window_label)
}

///|
pub fn[Model, Msg] UiProgram::registry(
  self : UiProgram[Model, Msg],
) -> @lepusa.CommandRegistry {
  self.register(@lepusa.CommandRegistry::new())
}

///|
pub fn[Model, Msg] UiProgram::register(
  self : UiProgram[Model, Msg],
  registry : @lepusa.CommandRegistry,
) -> @lepusa.CommandRegistry {
  let mut current = self
  registry.register_fn(
    self.route,
    permission=@lepusa.Permission::command(self.route),
    handler=fn(payload) {
      match current.dispatch(payload) {
        Err(problem) => Err(problem)
        Ok(transition) => {
          current = transition.program()
          Ok(current.render_payload())
        }
      }
    },
  )
}

///|
pub fn[Model, Msg] UiProgram::view_html(
  self : UiProgram[Model, Msg],
) -> @lepusa.Html {
  (self.view)(fn(message) { self.dispatch_attr(message) }, self.model)
}

///|
pub fn[Model, Msg] UiProgram::html(
  self : UiProgram[Model, Msg],
) -> @lepusa.Html {
  concat([self.view_html(), self.driver_script()])
}

///|
pub fn[Model, Msg] UiProgram::cell(
  self : UiProgram[Model, Msg],
) -> @lepusa.Cell {
  @lepusa.Cell::new(id=self.root_id, html=self.html())
}

///|
pub fn[Model, Msg] UiProgram::dispatch(
  self : UiProgram[Model, Msg],
  payload : String,
) -> Result[UiTransition[Model, Msg], String] {
  match (self.decode)(payload) {
    Err(problem) => Err(problem)
    Ok(message) => {
      let (next_model, command) = (self.update)(message, self.model)
      let next_program = { ..self, model: next_model }
      Ok(
        UiTransition::new(
          program=next_program,
          message~,
          command=next_program.render_command(command),
        ),
      )
    }
  }
}

///|
fn[Model, Msg] UiProgram::driver_script(
  self : UiProgram[Model, Msg],
) -> @lepusa.Html {
  script(
    [
      "(() => {",
      "  const api = window.lepusa;",
      "  if (!api || typeof api.listen !== \"function\") { return; }",
      "  api.listen(\{self.render_event.js_string()}, (payload) => {",
      "    const root = document.getElementById(\{self.root_id.js_string()});",
      "    if (!root || !payload || typeof payload.html !== \"string\") { return; }",
      "    root.innerHTML = payload.html;",
      "  });",
      "})();",
    ].join("\n"),
  )
}

///|
fn[Model, Msg] UiProgram::dispatch_script(
  self : UiProgram[Model, Msg],
  message : Msg,
) -> String {
  [
    "window.lepusa&&window.lepusa.invoke(",
    self.route.js_string(),
    ",",
    (self.encode)(message),
    ").then((payload)=>{",
    "const root=document.getElementById(",
    self.root_id.js_string(),
    ");",
    "if(root&&payload&&typeof payload.html==='string'){root.innerHTML=payload.html;}",
    "})",
  ].join("")
}

///|
fn[Model, Msg] UiProgram::render_command(
  self : UiProgram[Model, Msg],
  command : @lepusa.Cmd,
) -> @lepusa.Cmd {
  @lepusa.Cmd::batch([
    command,
    @lepusa.Cmd::emit(
      @lepusa.Event::new(self.render_event, payload=self.render_payload()),
      target=WindowTarget(self.window_label),
    ),
  ])
}

///|
fn[Model, Msg] UiProgram::render_payload(
  self : UiProgram[Model, Msg],
) -> String {
  "{\"html\":\{self.view_html().content().json_string()}}"
}

///|
fn[Model, Msg] UiProgram::route_parts(
  self : UiProgram[Model, Msg],
) -> (String, String) {
  let parts : Array[String] = []
  for part in self.route.split(".") {
    parts.push(part.to_owned())
  }
  match parts.length() {
    0 => ("", "")
    1 => (parts[0], "")
    _ => {
      let command_parts : Array[String] = []
      for index in 1..<parts.length() {
        command_parts.push(parts[index])
      }
      (parts[0], command_parts.join("."))
    }
  }
}

///|
pub struct UiTransition[Model, Msg] {
  program : UiProgram[Model, Msg]
  message : Msg
  command : @lepusa.Cmd
}

///|
fn[Model, Msg] UiTransition::new(
  program~ : UiProgram[Model, Msg],
  message~ : Msg,
  command~ : @lepusa.Cmd,
) -> UiTransition[Model, Msg] {
  { program, message, command }
}

///|
pub fn[Model, Msg] UiTransition::program(
  self : UiTransition[Model, Msg],
) -> UiProgram[Model, Msg] {
  self.program
}

///|
pub fn[Model, Msg] UiTransition::model(
  self : UiTransition[Model, Msg],
) -> Model {
  self.program.model()
}

///|
pub fn[Model, Msg] UiTransition::message(
  self : UiTransition[Model, Msg],
) -> Msg {
  self.message
}

///|
pub fn[Model, Msg] UiTransition::command(
  self : UiTransition[Model, Msg],
) -> @lepusa.Cmd {
  self.command
}

///|
fn String::json_string(self : String) -> String {
  "\"\{self.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"").replace_all(old="\n", new="\\n").replace_all(old="\r", new="\\r").replace_all(old="\t", new="\\t")}\""
}

///|
fn String::js_string(self : String) -> String {
  self.json_string()
}

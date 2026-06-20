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
  on_click(self.route, payload=(self.encode)(message))
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

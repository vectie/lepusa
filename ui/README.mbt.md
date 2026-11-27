# Lepusa UI

`@lepusa/ui` provides Rabbita-style helpers for MoonBit-authored desktop views.
Use the lightweight HTML builders directly for static views, or `UiProgram`
when a view needs model/update/view state, message encoding, and normal Lepusa
command/event integration. `UiProgram` also declares its own plugin,
capability, and registry handler, so a small app does not need custom IPC
boilerplate for UI messages.

```mbt check
///|
test "compose a Lepusa UI view" {
  let view = @ui.main_([
    @ui.h1([@ui.text("Counter")]),
    @ui.p([@ui.text("Count: 1")], attrs=[@ui.class_name("metric")]),
    @ui.p([@ui.text("Starting")], attrs=[@ui.id("status")]),
    @ui.button("Increment", attrs=[@ui.on_click("counter.increment")]),
    @ui.text_listener("ready", "#status"),
  ])
  let cell = @lepusa.simple_cell(view)
  let app = @lepusa.new(cell)
    .with_startup(
      @lepusa.Cmd::emit(@lepusa.Event::new("ready", payload="Ready")),
    )
    .window(title="Counter")
  match app.launch_plan() {
    Ok(plan) => inspect(plan.window_count(), content="1")
    Err(_) => fail("unexpected invalid app")
  }
}
```

```mbt check
///|
#derive(Debug, Eq)
enum CounterMessage {
  Increment
}

///|
test "compose a model update view program" {
  let program = @ui.UiProgram::new(
    model=0,
    update=fn(message, count) {
      match message {
        Increment => (count + 1, @lepusa.none)
      }
    },
    view=fn(emit, count) {
      @ui.main_([
        @ui.h1([@ui.text("Counter")]),
        @ui.p([@ui.text("Count: \{count}")]),
        @ui.button("Increment", attrs=[emit(Increment)]),
      ])
    },
    encode=fn(message) {
      match message {
        Increment => "{\"kind\":\"increment\"}"
      }
    },
    decode=fn(payload) {
      match payload {
        "{\"kind\":\"increment\"}" => Ok(Increment)
        _ => Err("unknown message")
      }
    },
    route="counter.dispatch",
    render_event="counter.render",
  )
  let app = @lepusa.new(program.cell())
    .with_plugin(program.plugin())
    .with_capability(program.capability_for_window())
    .window(title="Counter")
  let registry = program.registry()
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="counter",
      command="dispatch",
      payload="{\"kind\":\"increment\"}",
    ),
    capabilities=[program.capability_for_window()],
  )
  inspect(response.payload().unwrap_or("").contains("Count: 1"), content="true")
  match app.launch_plan() {
    Ok(plan) => inspect(plan.window_count(), content="1")
    Err(_) => fail("unexpected invalid app")
  }
}
```

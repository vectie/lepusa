///|
test "ui text and attributes are escaped" {
  let html = @ui.div([@ui.text("<hello & bye>")], attrs=[
    @ui.id("root"),
    @ui.class_name("panel \"active\""),
    @ui.data("state", "ready & safe"),
  ])
  assert_eq(
    html.content(),
    "<div id=\"root\" class=\"panel &quot;active&quot;\" data-state=\"ready &amp; safe\">&lt;hello &amp; bye&gt;</div>",
  )
}

///|
test "ui helpers compose rabbita style views" {
  let view = @ui.main_([
    @ui.h1([@ui.text("Counter")]),
    @ui.p([@ui.text("Count: 3")], attrs=[@ui.class_name("metric")]),
    @ui.button("Increment", attrs=[@ui.on_click("counter.increment")]),
  ])
  assert_true(view.content().contains("<main>"))
  assert_true(view.content().contains("<h1>Counter</h1>"))
  assert_true(view.content().contains("window.lepusa"))
  assert_true(view.content().contains("counter.increment"))
}

///|
test "ui listeners bridge native emitted events" {
  let listener = @ui.text_listener("ready", "#status")
  assert_true(listener.content().contains("<script>"))
  assert_true(listener.content().contains("api.listen(\"ready\""))
  assert_true(
    listener.content().contains("document.querySelector(\"#status\")"),
  )
  let custom = @ui.listen("saved", "    console.log(payload, event);")
  assert_true(custom.content().contains("console.log(payload, event);"))
}

///|
test "ui html can back a lepusa cell" {
  let cell = @lepusa.simple_cell(@ui.section([@ui.text("Ready")]))
  let app = @lepusa.new(cell).window(title="UI App")
  match app.launch_plan() {
    Ok(plan) => {
      assert_eq(plan.window_count(), 1)
      match plan.windows()[0].resolve() {
        Ok(window) =>
          assert_eq(window.url(), "lepusa://rabbita/main/index.html")
        Err(_) => abort("unexpected invalid ui window")
      }
    }
    Err(_) => abort("unexpected invalid ui app")
  }
}

///|
#derive(Debug, Eq)
enum TestCounterMessage {
  TestIncrement
  TestDecrement
}

///|
fn encode_counter_message(message : TestCounterMessage) -> String {
  match message {
    TestIncrement => "{\"kind\":\"increment\"}"
    TestDecrement => "{\"kind\":\"decrement\"}"
  }
}

///|
fn decode_counter_message(
  payload : String,
) -> Result[TestCounterMessage, String] {
  match payload {
    "{\"kind\":\"increment\"}" => Ok(TestIncrement)
    "{\"kind\":\"decrement\"}" => Ok(TestDecrement)
    _ => Err("unknown counter message")
  }
}

///|
fn update_counter(
  message : TestCounterMessage,
  count : Int32,
) -> (Int32, @lepusa.Cmd) {
  match message {
    TestIncrement => (count + 1, @lepusa.Cmd::effect("counter.changed"))
    TestDecrement => (count - 1, @lepusa.none)
  }
}

///|
fn view_counter(
  emit : @ui.ViewEmit[TestCounterMessage],
  count : Int32,
) -> @lepusa.Html {
  @ui.main_([
    @ui.h1([@ui.text("Counter")]),
    @ui.p([@ui.text("Count: \{count}")], attrs=[@ui.id("count")]),
    @ui.button("Increment", attrs=[emit(TestIncrement)]),
    @ui.button("Decrement", attrs=[emit(TestDecrement)]),
  ])
}

///|
fn counter_program(count : Int32) -> @ui.UiProgram[Int32, TestCounterMessage] {
  @ui.UiProgram::new(
    model=count,
    update=update_counter,
    view=view_counter,
    encode=encode_counter_message,
    decode=decode_counter_message,
    route="counter.dispatch",
    render_event="counter.render",
    window_label="main",
    root_id="counter-root",
  )
}

///|
test "ui program renders model update view cell" {
  let program = counter_program(1)
  assert_true(program.validate().is_empty())
  assert_eq(program.model(), 1)
  assert_eq(program.route(), "counter.dispatch")
  let cell = program.cell()
  assert_eq(cell.id(), "counter-root")
  assert_true(cell.html().content().contains("Count: 1"))
  assert_true(cell.html().content().contains("counter.dispatch"))
  assert_true(cell.html().content().contains("counter.render"))
  assert_true(cell.html().content().contains("window.lepusa.invoke"))
  assert_true(cell.html().content().contains("counter.dispatch"))
  assert_true(cell.html().content().contains("kind&quot;:&quot;increment"))
}

///|
test "ui program validates route shape" {
  let invalid = @ui.UiProgram::new(
    model=0,
    update=update_counter,
    view=view_counter,
    encode=encode_counter_message,
    decode=decode_counter_message,
    route="counter",
  )
  assert_eq(invalid.validate()[0], "ui program route must be plugin.command")
}

///|
test "ui program dispatch advances model and emits render command" {
  let program = counter_program(1)
  match program.dispatch("{\"kind\":\"increment\"}") {
    Ok(transition) => {
      assert_eq(transition.model(), 2)
      assert_true(transition.message() is TestIncrement)
      assert_true(transition.command() is Batch(_))
      match transition.program().dispatch("{\"kind\":\"decrement\"}") {
        Ok(next) => assert_eq(next.model(), 1)
        Err(problem) => abort(problem)
      }
      match
        @lepusa.new(transition.program().cell())
        .window(label="main")
        .runtime_plan() {
        Ok(plan) =>
          match plan.actions(transition.command()) {
            Ok(actions) => {
              assert_eq(actions.length(), 2)
              assert_true(actions[0] is RuntimeEffect("counter.changed"))
              assert_true(actions[1] is RuntimeEmit(WindowTarget("main"), _))
            }
            Err(problems) => abort(problems.join("; "))
          }
        Err(problems) => abort(problems.join("; "))
      }
    }
    Err(problem) => abort(problem)
  }
  match program.dispatch("{\"kind\":\"missing\"}") {
    Ok(_) => abort("unexpected valid message")
    Err(problem) => assert_eq(problem, "unknown counter message")
  }
}

///|
test "ui program declares plugin capability and registry handler" {
  let program = counter_program(1)
  let plugin = program.plugin()
  assert_eq(plugin.name(), "counter")
  assert_eq(plugin.command_routes()[0], "counter.dispatch")
  let grant = program.capability_for_window()
  assert_true(
    grant.allows(
      window_label="main",
      permission=@lepusa.Permission::command("counter.dispatch"),
    ),
  )
  let registry = program.registry()
  assert_true(registry.contains("counter.dispatch"))
  let request = @lepusa.InvokeRequest::new(
    id="ui",
    window_label="main",
    plugin="counter",
    command="dispatch",
    payload="{\"kind\":\"increment\"}",
  )
  let response = registry.dispatch(request, capabilities=[grant])
  assert_true(response is InvokeOk("ui", _))
  assert_true(response.payload().unwrap_or("").contains("Count: 2"))
  let next = registry.dispatch(request, capabilities=[grant])
  assert_true(next.payload().unwrap_or("").contains("Count: 3"))
  let denied = registry.dispatch(request)
  assert_eq(denied.id(), "ui")
  assert_eq(
    denied.error_message().unwrap_or(""),
    "permission denied: counter.dispatch",
  )
}

///|
test "ui text and attributes are escaped" {
  let html = div([text("<hello & bye>")], attrs=[
    id("root"),
    class_name("panel \"active\""),
    data("state", "ready & safe"),
  ])
  assert_eq(
    html.content(),
    "<div id=\"root\" class=\"panel &quot;active&quot;\" data-state=\"ready &amp; safe\">&lt;hello &amp; bye&gt;</div>",
  )
}

///|
test "ui helpers compose rabbita style views" {
  let view = main_([
    h1([text("Counter")]),
    p([text("Count: 3")], attrs=[class_name("metric")]),
    button("Increment", attrs=[on_click("counter.increment")]),
  ])
  assert_true(view.content().contains("<main>"))
  assert_true(view.content().contains("<h1>Counter</h1>"))
  assert_true(view.content().contains("window.lepusa"))
  assert_true(view.content().contains("counter.increment"))
}

///|
test "ui listeners bridge native emitted events" {
  let listener = text_listener("ready", "#status")
  assert_true(listener.content().contains("<script>"))
  assert_true(listener.content().contains("api.listen(\"ready\""))
  assert_true(
    listener.content().contains("document.querySelector(\"#status\")"),
  )
  let custom = listen("saved", "    console.log(payload, event);")
  assert_true(custom.content().contains("console.log(payload, event);"))
}

///|
test "ui html can back a lepusa cell" {
  let cell = @lepusa.simple_cell(section([text("Ready")]))
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
enum TestCounterMessage {
  TestIncrement
  TestDecrement
} derive(Debug, Eq)

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
  count : Int,
) -> (Int, @lepusa.Cmd) {
  match message {
    TestIncrement => (count + 1, @lepusa.Cmd::effect("counter.changed"))
    TestDecrement => (count - 1, @lepusa.none)
  }
}

///|
fn view_counter(
  dispatch : ViewDispatch[TestCounterMessage],
  count : Int,
) -> @lepusa.Html {
  main_([
    h1([text("Counter")]),
    p([text("Count: \{count}")], attrs=[id("count")]),
    button("Increment", attrs=[dispatch(TestIncrement)]),
    button("Decrement", attrs=[dispatch(TestDecrement)]),
  ])
}

///|
fn counter_program(count : Int) -> UiProgram[Int, TestCounterMessage] {
  UiProgram::new(
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

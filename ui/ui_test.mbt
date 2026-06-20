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

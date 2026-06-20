# Lepusa UI

`@lepusa/ui` provides small Rabbita-style HTML helpers for MoonBit-authored
desktop views. The package returns `@lepusa.Html`, so apps still use the root
`@lepusa.cell_with_dispatch` and `@lepusa.new(cell)` runtime boundary.

```mbt check
///|
test "compose a Lepusa UI view" {
  let view = main_([
    h1([text("Counter")]),
    p([text("Count: 1")], attrs=[class_name("metric")]),
    p([text("Starting")], attrs=[id("status")]),
    button("Increment", attrs=[on_click("counter.increment")]),
    text_listener("ready", "#status"),
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

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
    button("Increment", attrs=[on_click("counter.increment")]),
  ])
  let cell = @lepusa.simple_cell(view)
  let app = @lepusa.new(cell).window(title="Counter")
  match app.launch_plan() {
    Ok(plan) => inspect(plan.window_count(), content="1")
    Err(_) => fail("unexpected invalid app")
  }
}
```

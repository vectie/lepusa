# Lepusa Window Plugin

`vectie/lepusa/plugins/window` declares sync-safe window open/control routes and
a deterministic registry contract for native backends. `window.open` accepts a
`WindowConfig`-shaped JSON payload with a label and source, then the runtime
bridge lowers approved dispatches to a typed `open-window` operation.

```mbt check
///|
test "window plugin usage" {
  let state = WindowControlState::new()
  let registry = registry(state~)
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="window",
      command="setTitle",
      payload="{\"windowLabel\":\"main\",\"title\":\"Dashboard\"}",
    ),
    capabilities=[capability_for_window("main")],
  )
  assert_true(response is InvokeOk("1", _))
  assert_eq(state.operations()[0].window_label(), "main")
  assert_true(state.operations()[0].action() is SetTitle)
}
```

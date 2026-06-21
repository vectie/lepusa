///|
test "event bus registers listeners and emits in order" {
  let bus = @lepusa.EventBus::new()
  match bus.listen("ready", target=WindowTarget("main")) {
    Ok(main) =>
      match bus.listen("ready", target=WindowTarget("settings")) {
        Ok(settings) => {
          assert_eq(main.id(), "listener-1")
          assert_eq(settings.id(), "listener-2")
          assert_eq(bus.listener_count(), 2)
          match bus.emit(@lepusa.Event::new("ready"), target=AppTarget) {
            Ok(deliveries) => {
              assert_eq(deliveries.length(), 2)
              assert_eq(deliveries[0].listener_id(), "listener-1")
              assert_eq(deliveries[1].listener_id(), "listener-2")
              assert_true(deliveries[0].event().name() == "ready")
            }
            Err(_) => abort("unexpected invalid event")
          }
        }
        Err(_) => abort("unexpected settings listener error")
      }
    Err(_) => abort("unexpected main listener error")
  }
}

///|
test "event bus routes targeted events through app listeners" {
  let bus = @lepusa.EventBus::new()
  ignore(bus.listen("saved"))
  ignore(bus.listen("saved", target=WindowTarget("main")))
  ignore(bus.listen("saved", target=WindowTarget("settings")))
  match
    bus.emit(
      @lepusa.Event::new("saved", payload="{\"id\":1}"),
      target=WindowTarget("main"),
    ) {
    Ok(deliveries) => {
      assert_eq(deliveries.length(), 2)
      assert_eq(deliveries[0].listener_id(), "listener-1")
      assert_eq(deliveries[1].listener_id(), "listener-2")
      assert_true(deliveries[1].target() is WindowTarget("main"))
      assert_eq(
        bus.listeners_for("saved", target=WindowTarget("main")).length(),
        2,
      )
      assert_true(deliveries[0].to_json().contains("\"name\":\"saved\""))
    }
    Err(_) => abort("unexpected invalid event")
  }
}

///|
test "event bus once listeners remove themselves after delivery" {
  let bus = @lepusa.EventBus::new()
  ignore(bus.once("ready", target=WindowTarget("main")))
  ignore(bus.listen("ready", target=WindowTarget("main")))
  match bus.emit(@lepusa.Event::new("ready"), target=WindowTarget("main")) {
    Ok(deliveries) => {
      assert_eq(deliveries.length(), 2)
      assert_eq(bus.listener_count(), 1)
      assert_true(bus.listener("listener-1") is None)
      assert_true(bus.listener("listener-2") is Some(_))
    }
    Err(_) => abort("unexpected invalid event")
  }
}

///|
test "event bus validates names targets and removes target listeners" {
  let bus = @lepusa.EventBus::new()
  match bus.listen("", target=WindowTarget("")) {
    Ok(_) => abort("unexpected valid listener")
    Err(problems) => {
      assert_eq(problems.length(), 2)
      assert_eq(problems[0], "event name is required")
      assert_eq(problems[1], "event target window label is required")
    }
  }
  ignore(bus.listen("close", target=WindowTarget("main")))
  ignore(bus.listen("close", target=WebviewTarget("main")))
  assert_eq(@lepusa.WindowTarget("main").kind(), "window")
  assert_true(@lepusa.WebviewTarget("main").label() is Some("main"))
  let removed = bus.remove_target(WindowTarget("main"))
  assert_eq(removed.length(), 1)
  assert_eq(bus.listener_count(), 1)
  match bus.unlisten("missing") {
    Ok(_) => abort("unexpected removed listener")
    Err(message) => assert_eq(message, "event listener not found: missing")
  }
  let json = bus.to_json()
  assert_true(json.contains("\"listeners\""))
  assert_true(json.contains("\"kind\":\"webview\""))
  assert_eq(bus.clear().length(), 1)
  assert_eq(bus.listener_count(), 0)
}

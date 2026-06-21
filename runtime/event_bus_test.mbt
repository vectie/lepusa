///|
fn event_session_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>main</main>"))
    .window(
      label="settings",
      source=@lepusa.Source::html("<main>settings</main>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(@lepusa.Capability::new("core").command("core.invoke"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime session owns native event listeners" {
  let host = RuntimeHost::new(event_session_plan())
  match host.snapshot() {
    Ok(session) => {
      assert_eq(session.event_listener_count(), 0)
      match session.listen_event("ready", target=WindowTarget("main")) {
        Ok(listener) => {
          assert_eq(listener.id(), "listener-1")
          assert_true(listener.target() is WindowTarget("main"))
          assert_eq(session.event_listener_count(), 1)
          assert_eq(session.event_listeners()[0].name(), "ready")
          match
            session.event_deliveries(
              @lepusa.Event::new("ready", payload="{\"ok\":true}"),
              target=WindowTarget("main"),
            ) {
            Ok(deliveries) => {
              assert_eq(deliveries.length(), 1)
              assert_eq(deliveries[0].listener_id(), "listener-1")
              assert_true(deliveries[0].target() is WindowTarget("main"))
            }
            Err(_) => abort("unexpected delivery error")
          }
          assert_true(session.to_json().contains("\"eventBus\""))
          assert_true(session.to_json().contains("\"listener-1\""))
        }
        Err(_) => abort("unexpected listener error")
      }
    }
    Err(_) => abort("unexpected runtime snapshot error")
  }
}

///|
test "runtime session supports once unlisten and target cleanup" {
  let host = RuntimeHost::new(event_session_plan())
  match host.snapshot() {
    Ok(session) => {
      ignore(session.listen_event("ready", target=WindowTarget("main")))
      ignore(session.once_event("ready", target=WindowTarget("main")))
      ignore(session.listen_event("ready", target=WindowTarget("settings")))
      assert_eq(session.event_listener_count(), 3)
      match
        session.event_deliveries(
          @lepusa.Event::new("ready"),
          target=WindowTarget("main"),
        ) {
        Ok(deliveries) => {
          assert_eq(deliveries.length(), 2)
          assert_eq(session.event_listener_count(), 2)
        }
        Err(_) => abort("unexpected delivery error")
      }
      match session.unlisten_event("listener-1") {
        Ok(listener) => assert_eq(listener.name(), "ready")
        Err(_) => abort("unexpected unlisten error")
      }
      assert_eq(session.event_listener_count(), 1)
      ignore(session.listen_event("close", target=WebviewTarget("main")))
      let removed = session.remove_event_target(WebviewTarget("main"))
      assert_eq(removed.length(), 1)
      assert_eq(session.event_listener_count(), 1)
    }
    Err(_) => abort("unexpected runtime snapshot error")
  }
}

///|
test "runtime session listener validation is surfaced" {
  let host = RuntimeHost::new(event_session_plan())
  match host.snapshot() {
    Ok(session) =>
      match session.listen_event("", target=WebviewTarget("")) {
        Ok(_) => abort("unexpected valid listener")
        Err(problems) => {
          assert_eq(problems.length(), 2)
          assert_eq(problems[0], "event name is required")
          assert_eq(problems[1], "event target webview label is required")
        }
      }
    Err(_) => abort("unexpected runtime snapshot error")
  }
}

///|
test "frontend bridge event emit becomes native dispatch operations" {
  let host = RuntimeHost::new(event_session_plan())
  let message = "{\"id\":\"evt-1\",\"window_label\":\"main\",\"plugin\":\"__lepusa\",\"command\":\"event.emit\",\"payload\":\"{\\\"target\\\":{\\\"kind\\\":\\\"window\\\",\\\"label\\\":\\\"settings\\\"},\\\"name\\\":\\\"ready\\\",\\\"payload\\\":\\\"{\\\\\\\"ok\\\\\\\":true}\\\"}\"}"
  match host.dispatch_bridge_message_sync(message) {
    Ok(dispatch) => {
      assert_true(dispatch.response_json().contains("\"id\":\"evt-1\""))
      assert_true(dispatch.response_json().contains("\\\"delivered\\\":1"))
      let operations = dispatch.operations()
      assert_eq(operations.length(), 2)
      assert_eq(operations[0].kind(), "evaluate-script")
      assert_eq(operations[1].kind(), "evaluate-script")
      assert_true(operations[1].to_json().contains("__lepusaDispatchEvent"))
      assert_true(
        operations[1].to_json().contains("\"windowLabel\":\"settings\""),
      )
      assert_true(operations[1].to_json().contains("ready"))
      assert_true(dispatch.to_json().contains("\"extraOperations\":[{"))
    }
    Err(_) => abort("unexpected frontend event bridge failure")
  }
}

///|
test "frontend bridge event emit validates targets before dispatch" {
  let host = RuntimeHost::new(event_session_plan())
  let message = "{\"id\":\"evt-2\",\"window_label\":\"main\",\"plugin\":\"__lepusa\",\"command\":\"event.emit\",\"payload\":\"{\\\"target\\\":{\\\"kind\\\":\\\"window\\\"},\\\"name\\\":\\\"ready\\\"}\"}"
  match host.dispatch_bridge_message_sync(message) {
    Ok(dispatch) => {
      assert_true(
        dispatch.response_json().contains("\"errorCode\":\"invalid-request\""),
      )
      assert_true(
        dispatch
        .response_json()
        .contains("frontend event target window label is required"),
      )
      assert_eq(dispatch.operations().length(), 1)
    }
    Err(_) => abort("unexpected frontend event bridge response failure")
  }
}

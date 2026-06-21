///|
fn manager_test_app() -> @lepusa.App {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  @lepusa.new(root)
  .window(label="main", source=@lepusa.Source::html("<main></main>"))
  .with_plugin(@lepusa.Plugin::new("core").command_sync("ping"))
  .with_capability(
    @lepusa.Capability::new("core").window("main").command("core.ping"),
  )
}

///|
test "app manager owns dispatch resources channels events and state" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.ping", handler=fn(
    payload,
  ) {
    Ok("pong:\{payload}")
  })
  let manager = match
    manager_test_app().manager(
      config=@lepusa.RuntimeConfig::headless(),
      registry~,
    ) {
    Ok(manager) => manager
    Err(_) => abort("unexpected invalid manager")
  }
  assert_eq(manager.window_count(), 1)
  assert_eq(manager.plugin_count(), 1)
  assert_eq(manager.command_routes()[0], "core.ping")
  assert_eq(manager.registered_routes()[0], "core.ping")
  let response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="core",
      command="ping",
      payload="data",
    ),
  )
  assert_true(response is InvokeOk("1", "pong:data"))
  let resource = match
    manager.open_resource(
      @lepusa.ResourceDescriptor::new(kind="watcher", owner="core"),
    ) {
    Ok(resource) => resource
    Err(_) => abort("unexpected invalid resource")
  }
  assert_eq(resource.id(), "resource-1")
  let channel = match manager.open_channel(owner="core", name="logs") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid channel")
  }
  assert_eq(channel.id(), "channel-1")
  assert_eq(manager.resource_count(), 2)
  assert_eq(manager.resource_handles().length(), 2)
  assert_eq(manager.resource_handles_by_owner("core").length(), 2)
  assert_eq(manager.resource_handles_by_kind("channel")[0].id(), "channel-1")
  match manager.resource(channel.id()) {
    Some(entry) => {
      assert_eq(entry.kind(), "channel")
      assert_eq(entry.owner(), "core")
    }
    None => abort("missing channel resource")
  }
  ignore(manager.send_channel(channel.id(), "line"))
  ignore(manager.end_channel(channel.id()))
  match manager.drain_channel(channel.id()) {
    Ok(messages) => {
      assert_eq(messages.length(), 2)
      assert_true(messages[0].kind() is ChannelData)
      assert_true(messages[1].kind() is ChannelEnd)
    }
    Err(problem) => abort(problem)
  }
  match manager.listen("ready", target=WindowTarget("main")) {
    Ok(listener) => assert_eq(listener.id(), "listener-1")
    Err(_) => abort("unexpected invalid listener")
  }
  match manager.emit(@lepusa.Event::new("ready"), target=WindowTarget("main")) {
    Ok(deliveries) => assert_eq(deliveries.length(), 1)
    Err(_) => abort("unexpected invalid event")
  }
  match manager.manage_state("session", kind="json", value="{\"ok\":true}") {
    Ok(entry) => {
      assert_eq(entry.key(), "session")
      assert_eq(entry.kind(), "json")
    }
    Err(_) => abort("unexpected invalid state")
  }
  match manager.state("session") {
    Some(entry) => assert_eq(entry.value(), "{\"ok\":true}")
    None => abort("missing managed state")
  }
  let json = manager.to_json()
  assert_true(json.contains("\"backend\":\"headless\""))
  assert_true(json.contains("\"commands\":[\"core.ping\"]"))
  assert_true(json.contains("\"registeredCommands\":[\"core.ping\"]"))
  assert_true(json.contains("\"id\":\"resource-1\""))
  assert_true(json.contains("\"id\":\"channel-1\""))
  assert_true(json.contains("\"resourceLeaks\""))
  assert_true(json.contains("\"state\""))
}

///|
test "app manager dispatches stream commands into managed channels" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_stream("events"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.events"),
    )
  let registry = @lepusa.CommandRegistry::new().register_stream_fn(
    "core.events",
    handler=fn(payload, sink) {
      ignore(sink.send("{\"payload\":\{payload}}"))
      ignore(sink.end())
      Ok(())
    },
  )
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  let response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="stream",
      window_label="main",
      plugin="core",
      command="events",
      payload="7",
    ),
  )
  match response {
    InvokeOk("stream", payload) => {
      assert_true(payload.contains("\"kind\":\"stream\""))
      assert_true(payload.contains("\"route\":\"core.events\""))
      assert_true(payload.contains("\"channelId\":\"channel-1\""))
      assert_true(payload.contains("\"kind\":\"channel\""))
    }
    _ => abort("unexpected stream response")
  }
  assert_eq(manager.channel_count(), 1)
  match manager.channel("channel-1") {
    Some(channel) => {
      let handle = channel.resource().handle()
      assert_eq(handle.kind(), "channel")
      assert_eq(handle.owner(), "core")
      assert_eq(handle.name(), "events")
      assert_eq(
        channel.resource().metadata(),
        "{\"route\":\"core.events\",\"window\":\"main\"}",
      )
    }
    None => abort("missing stream channel")
  }
  match manager.drain_channel("channel-1") {
    Ok(messages) => {
      assert_eq(messages.length(), 2)
      assert_true(messages[0].kind() is ChannelData)
      assert_eq(messages[0].payload(), "{\"payload\":7}")
      assert_true(messages[1].kind() is ChannelEnd)
    }
    Err(problem) => abort(problem)
  }
}

///|
test "app manager exposes runtime control commands for bridge primitives" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_stream("events"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.events"),
    )
  let registry = @lepusa.CommandRegistry::new().register_stream_fn(
    "core.events",
    handler=fn(payload, sink) {
      ignore(sink.send("{\"payload\":\{payload}}"))
      ignore(sink.end())
      Ok(())
    },
  )
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  ignore(manager.listen("ready", target=WindowTarget("main")))
  let event_response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="evt",
      window_label="main",
      plugin="__lepusa",
      command="event.emit",
      payload="{\"target\":{\"kind\":\"window\",\"label\":\"main\"},\"name\":\"ready\",\"payload\":\"{\\\"ok\\\":true}\"}",
    ),
  )
  assert_true(event_response is InvokeOk("evt", "{\"delivered\":1}"))
  let stream_response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="stream",
      window_label="main",
      plugin="core",
      command="events",
      payload="9",
    ),
  )
  assert_true(stream_response is InvokeOk(_, _))
  let drain_response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="drain",
      window_label="main",
      plugin="__lepusa",
      command="stream.drain",
      payload="{\"channelId\":\"channel-1\"}",
    ),
  )
  match drain_response {
    InvokeOk("drain", payload) => {
      assert_true(payload.contains("\"channelId\":\"channel-1\""))
      assert_true(payload.contains("\"kind\":\"data\""))
      assert_true(payload.contains("\"kind\":\"end\""))
    }
    _ => abort("unexpected drain response")
  }
  let close_response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="close",
      window_label="main",
      plugin="__lepusa",
      command="resource.close",
      payload="{\"id\":\"channel-1\",\"kind\":\"channel\"}",
    ),
  )
  match close_response {
    InvokeOk("close", payload) => {
      assert_true(payload.contains("\"closed\""))
      assert_true(payload.contains("\"id\":\"channel-1\""))
    }
    _ => abort("unexpected close response")
  }
  let missing = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="missing",
      window_label="main",
      plugin="__lepusa",
      command="stream.drain",
      payload="{\"channelId\":\"channel-1\"}",
    ),
  )
  assert_true(missing is InvokeError("missing", _))
}

///|
test "app manager runtime control can cancel active streams" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_stream("events"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.events"),
    )
  let registry = @lepusa.CommandRegistry::new().register_stream_fn(
    "core.events",
    handler=fn(_, sink) {
      ignore(sink.send("open"))
      Ok(())
    },
  )
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  ignore(
    manager.dispatch(
      @lepusa.InvokeRequest::new(
        id="stream",
        window_label="main",
        plugin="core",
        command="events",
      ),
    ),
  )
  match
    manager.dispatch(
      @lepusa.InvokeRequest::new(
        id="cancel",
        window_label="main",
        plugin="__lepusa",
        command="stream.cancel",
        payload="{\"channelId\":\"channel-1\"}",
      ),
    ) {
    InvokeOk("cancel", payload) =>
      assert_true(payload.contains("\"kind\":\"cancel\""))
    _ => abort("unexpected cancel response")
  }
}

///|
test "app manager runtime control denies cross-window access" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_stream("events"))
    .with_capability(
      @lepusa.Capability::new("core")
      .window("main")
      .window("settings")
      .command("core.events"),
    )
  let registry = @lepusa.CommandRegistry::new().register_stream_fn(
    "core.events",
    handler=fn(_, sink) {
      ignore(sink.send("open"))
      Ok(())
    },
  )
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  ignore(manager.listen("ready", target=WindowTarget("main")))
  ignore(
    manager.dispatch(
      @lepusa.InvokeRequest::new(
        id="stream",
        window_label="main",
        plugin="core",
        command="events",
      ),
    ),
  )
  let denied_drain = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="drain",
      window_label="settings",
      plugin="__lepusa",
      command="stream.drain",
      payload="{\"channelId\":\"channel-1\"}",
    ),
  )
  assert_true(denied_drain.error_kind() is Some(PermissionDenied))
  let denied_cancel = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="cancel",
      window_label="settings",
      plugin="__lepusa",
      command="stream.cancel",
      payload="{\"channelId\":\"channel-1\"}",
    ),
  )
  assert_true(denied_cancel.error_kind() is Some(PermissionDenied))
  let denied_close = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="close",
      window_label="settings",
      plugin="__lepusa",
      command="resource.close",
      payload="{\"id\":\"channel-1\",\"kind\":\"channel\"}",
    ),
  )
  assert_true(denied_close.error_kind() is Some(PermissionDenied))
  let denied_event = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="evt",
      window_label="settings",
      plugin="__lepusa",
      command="event.emit",
      payload="{\"target\":{\"kind\":\"window\",\"label\":\"main\"},\"name\":\"ready\"}",
    ),
  )
  assert_true(denied_event.error_kind() is Some(PermissionDenied))
  match manager.drain_channel("channel-1") {
    Ok(messages) => assert_eq(messages.length(), 1)
    Err(problem) => abort(problem)
  }
}

///|
test "app manager closes generic resources and channel resources by handle" {
  let manager = match
    manager_test_app().manager(config=@lepusa.RuntimeConfig::headless()) {
    Ok(manager) => manager
    Err(_) => abort("unexpected invalid manager")
  }
  let watcher = match
    manager.open_resource(@lepusa.ResourceDescriptor::new(kind="watcher")) {
    Ok(resource) => resource
    Err(_) => abort("unexpected invalid watcher")
  }
  let channel = match manager.open_channel() {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid channel")
  }
  match manager.close_resource_handle(watcher.handle()) {
    Ok(closed) => {
      assert_eq(closed.id(), "resource-1")
      assert_eq(closed.closed(), true)
    }
    Err(problem) => abort(problem)
  }
  match manager.close_resource_handle(channel.resource().handle()) {
    Ok(closed) => {
      assert_eq(closed.id(), "channel-1")
      assert_eq(closed.closed(), true)
    }
    Err(problem) => abort(problem)
  }
  match
    manager.close_resource_handle(
      @lepusa.ResourceHandle::new(id="missing", kind="channel"),
    ) {
    Ok(_) => abort("unexpected missing close")
    Err(problem) => assert_eq(problem, "resource not found: missing")
  }
  assert_eq(manager.resource_count(), 0)
}

///|
test "app manager reports and closes leaked resources on shutdown" {
  let manager = match
    manager_test_app().manager(config=@lepusa.RuntimeConfig::headless()) {
    Ok(manager) => manager
    Err(_) => abort("unexpected invalid manager")
  }
  ignore(
    manager.open_resource(
      @lepusa.ResourceDescriptor::new(kind="watcher", owner="core"),
    ),
  )
  let channel = match manager.open_channel(owner="core", name="logs") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid channel")
  }
  ignore(manager.end_channel(channel.id()))
  let leaks = manager.resource_leak_report()
  assert_true(leaks.leaked())
  assert_eq(leaks.count(), 2)
  assert_true(leaks.kinds().contains("watcher"))
  assert_true(leaks.kinds().contains("channel"))
  let cleanup = manager.close_all_resources()
  assert_true(cleanup.ok())
  assert_eq(cleanup.closed_count(), 2)
  assert_eq(manager.resource_count(), 0)
  assert_true(manager.resource_leak_report().ok())
}

///|
test "state store validates keys and preserves insertion order on overwrite" {
  let state = @lepusa.AppStateStore::new()
  match state.set("", value="bad") {
    Ok(_) => abort("unexpected valid state")
    Err(problems) => assert_eq(problems[0], "app state key is required")
  }
  ignore(state.set("alpha", value="1"))
  ignore(state.set("beta", value="2"))
  ignore(state.set("alpha", value="3"))
  assert_eq(state.count(), 2)
  assert_eq(state.keys()[0], "alpha")
  assert_eq(state.keys()[1], "beta")
  match state.get("alpha") {
    Some(entry) => assert_eq(entry.value(), "3")
    None => abort("missing alpha state")
  }
  match state.remove("beta") {
    Ok(entry) => assert_eq(entry.key(), "beta")
    Err(problem) => abort(problem)
  }
  assert_eq(state.contains("beta"), false)
}

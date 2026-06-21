///|
fn invoke_contract_app(include_write? : Bool = false) -> @lepusa.App {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      if include_write {
        @lepusa.Plugin::new("fs")
        .command_sync(
          "read",
          permission=FileSystemRead,
          request=@lepusa.IpcSchema::string(),
          response=@lepusa.IpcSchema::string(),
        )
        .command_async(
          "write",
          permission=FileSystemWrite,
          request=@lepusa.IpcSchema::string(),
          response=@lepusa.IpcSchema::unit(),
        )
      } else {
        @lepusa.Plugin::new("fs").command_sync(
          "read",
          permission=FileSystemRead,
          request=@lepusa.IpcSchema::string(),
          response=@lepusa.IpcSchema::string(),
        )
      },
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .permission(FileSystemRead)
      .path_scope(root="/app/data"),
    )
  if include_write {
    app.with_capability(
      @lepusa.Capability::new("main-write")
      .window("main")
      .permission(FileSystemWrite)
      .path_scope(root="/app/data", writable=true),
    )
  } else {
    app
  }
}

///|
fn invoke_contract_plan(include_write? : Bool = false) -> @lepusa.RuntimePlan {
  match
    invoke_contract_app(include_write~).runtime_plan(
      config=@lepusa.RuntimeConfig::headless(),
    ) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
fn invoke_contract_by_route(
  contracts : Array[@lepusa.InvokeContract],
  route : String,
) -> @lepusa.InvokeContract {
  for contract in contracts {
    if contract.route() == route {
      return contract
    }
  }
  abort("missing contract: \{route}")
}

///|
test "invoke contract report proves a registered scoped command dispatchable" {
  let registry = @lepusa.CommandRegistry::new().register_fn(
    "fs.read",
    permission=FileSystemRead,
    operation_scope=fn(request) {
      Ok(@lepusa.OperationScope::path(root=request.payload()))
    },
    handler=fn(payload) { Ok(payload) },
  )
  let profile = invoke_contract_plan().security_profile(
    registered_routes=registry.routes(),
    check_handlers=true,
  )
  let report = registry.invoke_contract_report(profile)
  assert_true(report.ok())
  assert_eq(report.dispatchable_routes().length(), 1)
  assert_eq(report.dispatchable_routes()[0], "fs.read")
  assert_eq(report.undeclared_routes().length(), 0)
  let contract = invoke_contract_by_route(report.contracts(), "fs.read")
  assert_true(contract.ok())
  assert_true(contract.dispatchable())
  assert_true(contract.registered())
  assert_true(contract.registered_mode() is Some(Sync))
  assert_true(contract.exposed())
  assert_true(contract.operation_scope_configured())
  assert_true(contract.operation_scope_required())
  assert_true(contract.to_json().contains("\"dispatchable\":true"))
}

///|
test "invoke contract report catches handler manifest drift" {
  let registry = @lepusa.CommandRegistry::new()
    .register_async_fn("fs.read", permission=Network, handler=fn(payload) {
      Ok(payload)
    })
    .register_fn("extra.ping", handler=fn(payload) { Ok(payload) })
    .register_fn("extra.ping", handler=fn(payload) { Ok(payload) })
  let profile = invoke_contract_plan(include_write=true).security_profile(
    registered_routes=registry.routes(),
    check_handlers=true,
  )
  let report = registry.invoke_contract_report(profile)
  assert_false(report.ok())
  assert_eq(report.undeclared_routes().length(), 1)
  assert_eq(report.undeclared_routes()[0], "extra.ping")
  assert_eq(report.duplicate_routes().length(), 1)
  assert_eq(report.duplicate_routes()[0], "extra.ping")

  let read = invoke_contract_by_route(report.contracts(), "fs.read")
  assert_false(read.ok())
  assert_true(read.registered())
  assert_true(read.registered_mode() is Some(Async))
  assert_false(read.operation_scope_required())
  assert_true(
    read.problems().any(fn(problem) { problem.contains("mode mismatch") }),
  )
  assert_true(
    read.problems().any(fn(problem) { problem.contains("permission mismatch") }),
  )
  assert_true(
    read
    .problems()
    .any(fn(problem) { problem.contains("does not resolve an operation scope") }),
  )

  let write = invoke_contract_by_route(report.contracts(), "fs.write")
  assert_false(write.ok())
  assert_false(write.registered())
  assert_true(
    write.problems().any(fn(problem) { problem.contains("no registered") }),
  )
  assert_true(
    report
    .problems()
    .any(fn(problem) { problem.contains("registered handler is not declared") }),
  )
  assert_true(report.to_json().contains("\"ok\":false"))
}

///|
test "invoke contract accepts registered stream handlers" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_stream("events"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.events"),
    )
  let plan = match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
  let registry = @lepusa.CommandRegistry::new().register_stream_fn(
    "core.events",
    handler=fn(_, sink) {
      ignore(sink.send("{\"channel\":\"events\"}"))
      Ok(())
    },
  )
  let profile = plan.security_profile(
    registered_routes=registry.routes(),
    check_handlers=true,
  )
  let report = registry.invoke_contract_report(profile)
  assert_true(report.ok())
  let contract = invoke_contract_by_route(report.contracts(), "core.events")
  assert_true(contract.registered_mode() is Some(Stream))
  assert_true(contract.dispatchable())
  let manager = @lepusa.AppManager::new(plan, registry~)
  let response = manager.dispatch(
    @lepusa.InvokeRequest::new(
      id="stream",
      window_label="main",
      plugin="core",
      command="events",
    ),
  )
  match response {
    InvokeOk("stream", payload) => {
      assert_true(payload.contains("\"kind\":\"stream\""))
      assert_true(payload.contains("\"channelId\":\"channel-1\""))
    }
    _ => abort("unexpected stream response")
  }
  match manager.drain_channel("channel-1") {
    Ok(messages) => {
      assert_eq(messages.length(), 2)
      assert_true(messages[0].kind() is ChannelData)
      assert_true(messages[1].kind() is ChannelEnd)
    }
    Err(problem) => abort(problem)
  }
}

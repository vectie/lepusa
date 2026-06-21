///|
test "resource table allocates stable resource ids" {
  let table = @lepusa.ResourceTable::new()
  match
    table.open(
      @lepusa.ResourceDescriptor::new(
        kind="process",
        owner="main",
        name="worker",
        metadata="{\"pid\":42}",
      ),
    ) {
    Ok(entry) => {
      assert_eq(entry.id(), "resource-1")
      assert_eq(entry.sequence(), 1)
      assert_eq(entry.kind(), "process")
      assert_eq(entry.owner(), "main")
      assert_eq(entry.name(), "worker")
      assert_eq(entry.metadata(), "{\"pid\":42}")
      assert_eq(entry.closed(), false)
      let handle = entry.handle()
      assert_eq(handle.id(), "resource-1")
      assert_eq(handle.kind(), "process")
      assert_eq(handle.owner(), "main")
      assert_eq(handle.name(), "worker")
      assert_true(handle.to_json().contains("\"id\":\"resource-1\""))
      assert_true(entry.descriptor().to_json().contains("\"kind\":\"process\""))
    }
    Err(_) => abort("unexpected invalid resource")
  }
  match table.open(@lepusa.ResourceDescriptor::new(kind="watcher")) {
    Ok(entry) => assert_eq(entry.id(), "resource-2")
    Err(_) => abort("unexpected invalid resource")
  }
  assert_eq(table.count(), 2)
  assert_eq(table.ids()[0], "resource-1")
  assert_eq(table.ids()[1], "resource-2")
  assert_true(table.contains("resource-1"))
  assert_true(table.to_json().contains("\"nextSequence\":3"))
  assert_true(table.to_json().contains("\"kind\":\"process\""))
}

///|
test "resource handles validate and close resources with kind checks" {
  let table = @lepusa.ResourceTable::new()
  let process = match
    table.open(@lepusa.ResourceDescriptor::new(kind="process", owner="main")) {
    Ok(entry) => entry
    Err(_) => abort("unexpected invalid process resource")
  }
  let handle = process.handle()
  assert_eq(table.handles().length(), 1)
  assert_eq(table.handles_by_kind("process")[0].id(), handle.id())
  assert_eq(table.handles_by_owner("main")[0].id(), handle.id())
  match table.handle(handle.id()) {
    Some(found) => {
      assert_eq(found.id(), handle.id())
      assert_eq(found.kind(), handle.kind())
    }
    None => abort("missing resource handle")
  }
  match
    table.close_handle(@lepusa.ResourceHandle::new(id=handle.id(), kind="tray")) {
    Ok(_) => abort("unexpected kind mismatch close")
    Err(problem) => assert_true(problem.contains("resource kind mismatch"))
  }
  match table.close_handle(handle) {
    Ok(closed) => {
      assert_eq(closed.id(), "resource-1")
      assert_true(closed.closed())
    }
    Err(problem) => abort(problem)
  }
}

///|
test "resource table rejects descriptors without a kind" {
  let table = @lepusa.ResourceTable::new()
  match table.open(@lepusa.ResourceDescriptor::new(kind="")) {
    Ok(_) => abort("unexpected valid resource")
    Err(problems) => assert_eq(problems[0], "resource kind is required")
  }
  assert_eq(table.is_empty(), true)
}

///|
test "resource table closes resources by id kind and owner" {
  let table = @lepusa.ResourceTable::new()
  let process = match
    table.open(@lepusa.ResourceDescriptor::new(kind="process", owner="main")) {
    Ok(entry) => entry
    Err(_) => abort("unexpected invalid process resource")
  }
  ignore(
    table.open(@lepusa.ResourceDescriptor::new(kind="watcher", owner="main")),
  )
  ignore(
    table.open(
      @lepusa.ResourceDescriptor::new(kind="process", owner="settings"),
    ),
  )
  match table.close(process.id()) {
    Ok(closed) => {
      assert_eq(closed.id(), "resource-1")
      assert_eq(closed.closed(), true)
    }
    Err(problem) => abort(problem)
  }
  assert_eq(table.contains(process.id()), false)
  match table.close(process.id()) {
    Ok(_) => abort("unexpected duplicate close")
    Err(problem) => assert_eq(problem, "resource not found: resource-1")
  }
  let closed_watchers = table.close_kind("watcher")
  assert_eq(closed_watchers.length(), 1)
  assert_eq(closed_watchers[0].kind(), "watcher")
  assert_eq(closed_watchers[0].closed(), true)
  let closed_settings = table.close_owner("settings")
  assert_eq(closed_settings.length(), 1)
  assert_eq(closed_settings[0].owner(), "settings")
  assert_eq(table.is_empty(), true)
}

///|
test "resource table close all drains active resources" {
  let table = @lepusa.ResourceTable::new()
  ignore(table.open(@lepusa.ResourceDescriptor::new(kind="channel")))
  ignore(table.open(@lepusa.ResourceDescriptor::new(kind="tray")))
  let closed = table.close_all()
  assert_eq(closed.length(), 2)
  assert_eq(closed[0].closed(), true)
  assert_eq(closed[1].closed(), true)
  assert_eq(table.entries().length(), 0)
}

///|
test "channel table opens channels as resources" {
  let table = @lepusa.ChannelTable::new()
  match
    table.open(owner="main", name="logs", metadata="{\"route\":\"core.run\"}") {
    Ok(channel) => {
      assert_eq(channel.id(), "channel-1")
      assert_eq(channel.resource().kind(), "channel")
      assert_eq(channel.resource().owner(), "main")
      assert_eq(channel.resource().name(), "logs")
      assert_eq(channel.pending_count(), 0)
      assert_eq(channel.closed(), false)
      assert_eq(channel.cancelled(), false)
    }
    Err(_) => abort("unexpected invalid channel")
  }
  assert_eq(table.count(), 1)
  assert_eq(table.ids()[0], "channel-1")
  assert_true(table.to_json().contains("\"kind\":\"channel\""))
}

///|
test "channel table emits and drains ordered messages" {
  let table = @lepusa.ChannelTable::new()
  let channel = match table.open(owner="main") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid channel")
  }
  match table.send(channel.id(), "{\"line\":\"one\"}") {
    Ok(message) => {
      assert_eq(message.channel_id(), channel.id())
      assert_eq(message.sequence(), 1)
      assert_true(message.kind() is ChannelData)
      assert_eq(message.payload(), "{\"line\":\"one\"}")
      assert_true(message.to_json().contains("\"kind\":\"data\""))
    }
    Err(problem) => abort(problem)
  }
  match table.fail(channel.id(), "stderr") {
    Ok(message) => {
      assert_eq(message.sequence(), 2)
      assert_true(message.kind() is ChannelError)
    }
    Err(problem) => abort(problem)
  }
  match table.drain(channel.id()) {
    Ok(messages) => {
      assert_eq(messages.length(), 2)
      assert_eq(messages[0].sequence(), 1)
      assert_eq(messages[1].sequence(), 2)
    }
    Err(problem) => abort(problem)
  }
  match table.drain(channel.id()) {
    Ok(messages) => assert_eq(messages.length(), 0)
    Err(problem) => abort(problem)
  }
}

///|
test "channel terminal messages prevent further sends" {
  let table = @lepusa.ChannelTable::new()
  let channel = match table.open() {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid channel")
  }
  match table.end(channel.id()) {
    Ok(message) => {
      assert_eq(message.sequence(), 1)
      assert_true(message.kind() is ChannelEnd)
    }
    Err(problem) => abort(problem)
  }
  match table.get(channel.id()) {
    Some(channel) => assert_eq(channel.closed(), true)
    None => abort("missing channel")
  }
  match table.send(channel.id(), "late") {
    Ok(_) => abort("unexpected send after end")
    Err(problem) => assert_eq(problem, "channel is closed: channel-1")
  }
  match table.drain(channel.id()) {
    Ok(messages) => {
      assert_eq(messages.length(), 1)
      assert_true(messages[0].kind() is ChannelEnd)
    }
    Err(problem) => abort(problem)
  }
}

///|
test "channel cancellation and close clean up resources" {
  let table = @lepusa.ChannelTable::new()
  let first = match table.open(owner="main") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid first channel")
  }
  let second = match table.open(owner="settings") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid second channel")
  }
  match table.cancel(first.id()) {
    Ok(message) => assert_true(message.kind() is ChannelCancel)
    Err(problem) => abort(problem)
  }
  match table.get(first.id()) {
    Some(channel) => assert_eq(channel.cancelled(), true)
    None => abort("missing cancelled channel")
  }
  match table.close(first.id()) {
    Ok(resource) => {
      assert_eq(resource.id(), first.id())
      assert_eq(resource.closed(), true)
    }
    Err(problem) => abort(problem)
  }
  match table.close(first.id()) {
    Ok(_) => abort("unexpected duplicate channel close")
    Err(problem) => assert_eq(problem, "channel not found: channel-1")
  }
  assert_eq(table.contains(first.id()), false)
  assert_eq(table.contains(second.id()), true)
  let closed = table.close_all()
  assert_eq(closed.length(), 1)
  assert_eq(closed[0].id(), second.id())
  assert_eq(table.count(), 0)
}

///|
test "channel table reports leaked channels and cleanup" {
  let table = @lepusa.ChannelTable::new()
  let first = match table.open(owner="core", name="logs") {
    Ok(channel) => channel
    Err(_) => abort("unexpected invalid first channel")
  }
  ignore(table.open(owner="core", name="events"))
  ignore(table.end(first.id()))
  let report = table.leak_report()
  assert_true(report.leaked())
  assert_eq(report.count(), 2)
  assert_eq(report.resources()[0].kind(), "channel")
  assert_true(report.messages()[0].contains("owned by core"))
  let cleanup = table.cleanup_report()
  assert_true(cleanup.ok())
  assert_eq(cleanup.closed_count(), 2)
  assert_eq(table.count(), 0)
}

///|
test "file dialog plugin declares async dialog commands" {
  let declared = plugin()
  assert_eq(declared.name(), "fileDialog")
  assert_eq(declared.command_routes().length(), 4)
  assert_true(declared.command_routes().contains("fileDialog.openFile"))
  assert_true(declared.command_routes().contains("fileDialog.openFiles"))
  assert_true(declared.command_routes().contains("fileDialog.openDirectory"))
  assert_true(declared.command_routes().contains("fileDialog.saveFile"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is FileDialog)
}

///|
test "file dialog capabilities grant file dialog permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=FileDialog))
  assert_false(grant.allows(window_label="settings", permission=FileDialog))
  assert_false(grant.allows(window_label="main", permission=Dialog))
}

///|
test "file dialog policy validates scoped default directories" {
  let policy = FileDialogPolicy::new()
    .default_directory(
      FileDialogDefaultDirectory::new(
        name="documents",
        scope_name="docs",
        path="exports",
      ),
    )
    .default_directory(
      FileDialogDefaultDirectory::new(name="downloads", scope_name="downloads"),
    )
  assert_eq(policy.validate().length(), 0)
  let scopes = [
    @lepusa.FileSystemScope::new(name="docs", root="/app/docs"),
    @lepusa.FileSystemScope::new(name="downloads", root="/app/downloads"),
  ]
  assert_eq(policy.validate_scopes(scopes).length(), 0)
  let problems = policy.validate_scopes([
    @lepusa.FileSystemScope::new(name="docs", root="/app/docs"),
  ])
  assert_true(
    problems.contains("unknown file dialog default directory scope: downloads"),
  )
}

///|
test "file dialog policy rejects duplicate and unsafe defaults" {
  let policy = FileDialogPolicy::new()
    .default_directory(
      FileDialogDefaultDirectory::new(name="docs", scope_name="docs"),
    )
    .default_directory(
      FileDialogDefaultDirectory::new(
        name="docs",
        scope_name="docs",
        path="../escape",
      ),
    )
  let problems = policy.validate()
  assert_true(
    problems.contains("file dialog default directory must be unique: docs"),
  )
  assert_true(
    problems.contains("unsafe file dialog default directory path: ../escape"),
  )
}

///|
async test "file dialog registry validates scoped picker contracts" {
  let policy = FileDialogPolicy::new().default_directory(
    FileDialogDefaultDirectory::new(
      name="documents",
      scope_name="docs",
      path="exports",
    ),
  )
  let registry = registry(policy~, scopes=[
    @lepusa.FileSystemScope::new(name="docs", root="/app/docs", writable=true),
  ])
  let grant = capability_for_window("main")
  assert_true(registry.contains("fileDialog.openFile"))
  assert_true(registry.contains("fileDialog.openFiles"))
  assert_true(registry.contains("fileDialog.openDirectory"))
  assert_true(registry.contains("fileDialog.saveFile"))
  assert_eq(registry.async_routes().length(), 4)
  let open_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="fileDialog",
    command="openFile",
    payload="{\"defaultDirectory\":\"documents\",\"path\":\"draft.txt\"}",
  )
  let opened = registry.dispatch_async(open_request, capabilities=[grant])
  assert_true(
    opened.payload().unwrap_or("").contains("\"status\":\"delegated\""),
  )
  assert_true(
    opened
    .payload()
    .unwrap_or("")
    .contains("\"resolvedPath\":\"/app/docs/exports\""),
  )
  assert_true(opened.payload().unwrap_or("").contains("\"path\":\"draft.txt\""))
  let save_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="fileDialog",
    command="saveFile",
    payload="{\"defaultDirectory\":\"documents\",\"suggestedName\":\"report.txt\"}",
  )
  let saved = registry.dispatch_async(save_request, capabilities=[grant])
  assert_true(saved.payload().unwrap_or("").contains("\"save\":true"))
  assert_true(
    saved.payload().unwrap_or("").contains("\"suggestedName\":\"report.txt\""),
  )
  let unsafe_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="fileDialog",
    command="openFile",
    payload="{\"path\":\"../escape\"}",
  )
  let unsafe_result = registry.dispatch_async(unsafe_request, capabilities=[
    grant,
  ])
  assert_true(
    unsafe_result
    is InvokeError(
      "3",
      "file dialog openFile path: unsafe file dialog default directory path: ../escape"
    ),
  )
}

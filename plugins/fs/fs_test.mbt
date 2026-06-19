///|
test "fs plugin declares permissioned async commands" {
  let declared = plugin()
  assert_eq(declared.name(), "fs")
  assert_eq(declared.command_routes().length(), 9)
  assert_true(declared.command_routes().contains("fs.readText"))
  assert_true(declared.command_routes().contains("fs.writeText"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is FileSystemRead)
  assert_true(commands[5].permission() is FileSystemWrite)
}

///|
test "fs capabilities split read write and scoped window grants" {
  let read = read_capability_for_window("main")
  assert_true(read.allows(window_label="main", permission=FileSystemRead))
  assert_false(read.allows(window_label="main", permission=FileSystemWrite))
  assert_false(read.allows(window_label="other", permission=FileSystemRead))
  let both = read_write_capability()
  assert_true(both.allows(window_label="any", permission=FileSystemRead))
  assert_true(both.allows(window_label="any", permission=FileSystemWrite))
}

///|
test "fs policy validates scopes and resolves safe relative paths" {
  let policy = FsPolicy::new()
    .scope(@lepusa.FileSystemScope::new(name="assets", root="/app/assets"))
    .scope(
      @lepusa.FileSystemScope::new(
        name="data",
        root="/app/data/",
        writable=true,
      ),
    )
  assert_eq(policy.validate().length(), 0)
  assert_true(policy.scopes()[1].writable())
  assert_eq(
    policy.resolve(scope_name="assets", path="icons/main.png").unwrap(),
    "/app/assets/icons/main.png",
  )
  assert_eq(
    policy.resolve(scope_name="data", path="config.json", write=true).unwrap(),
    "/app/data/config.json",
  )
}

///|
test "fs policy rejects unsafe paths and read-only writes" {
  let policy = FsPolicy::new().scope(
    @lepusa.FileSystemScope::new(name="assets", root="/app/assets"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="../secret")
    is Err("unsafe filesystem path: ../secret"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="/etc/passwd")
    is Err("filesystem path must be relative"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="a\\b")
    is Err("unsafe filesystem path: a\\b"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="config.json", write=true)
    is Err("filesystem scope is read-only: assets"),
  )
  assert_true(
    policy.resolve(scope_name="missing", path="config.json")
    is Err("unknown filesystem scope: missing"),
  )
}

///|
test "fs policy reports invalid and duplicate scopes" {
  let problems = FsPolicy::new()
    .scope(@lepusa.FileSystemScope::new(name="", root=""))
    .scope(@lepusa.FileSystemScope::new(name="bad/name", root="/tmp"))
    .scope(@lepusa.FileSystemScope::new(name="bad/name", root="/tmp2"))
    .validate()
  assert_true(problems.contains("filesystem scope name is required"))
  assert_true(problems.contains("filesystem scope root is required"))
  assert_true(
    problems.contains("filesystem scope name must not contain path separators"),
  )
  assert_true(problems.contains("filesystem scope must be unique: bad/name"))
}

///|
fn fs_request(command : String, payload : String) -> @lepusa.InvokeRequest {
  @lepusa.InvokeRequest::new(
    id=command,
    window_label="main",
    plugin="fs",
    command~,
    payload~,
  )
}

///|
async test "fs registry handles scoped text operations" {
  let root = "/tmp/lepusa-fs-plugin-test"
  @xfs.create_dir(root) catch {
    _ => ()
  }
  let policy = FsPolicy::new().scope(
    @lepusa.FileSystemScope::new(name="data", root~, writable=true),
  )
  let registry = register(@lepusa.CommandRegistry::new(), policy~)
  let grant = read_write_capability_for_window("main")
  let create = registry.dispatch_async(
    fs_request("createDir", "{\"scope\":\"data\",\"path\":\"nested\"}"),
    capabilities=[grant],
  )
  assert_true(create is InvokeOk(_, _))
  let write = registry.dispatch_async(
    fs_request(
      "writeText", "{\"scope\":\"data\",\"path\":\"nested/file.txt\",\"content\":\"hello\"}",
    ),
    capabilities=[grant],
  )
  assert_true(write is InvokeOk(_, _))
  let exists = registry.dispatch_async(
    fs_request("exists", "{\"scope\":\"data\",\"path\":\"nested/file.txt\"}"),
    capabilities=[grant],
  )
  assert_true(exists.payload().unwrap_or("").contains("\"exists\":true"))
  let read = registry.dispatch_async(
    fs_request("readText", "{\"scope\":\"data\",\"path\":\"nested/file.txt\"}"),
    capabilities=[grant],
  )
  assert_true(read.payload().unwrap_or("").contains("\"content\":\"hello\""))
  let denied = registry.dispatch_async(
    fs_request("readText", "{\"scope\":\"data\",\"path\":\"nested/file.txt\"}"),
  )
  assert_true(
    denied is InvokeError("readText", "permission denied: fs.readText"),
  )
}

///|
async test "fs registry handles bytes list metadata and delete" {
  let root = "/tmp/lepusa-fs-plugin-test"
  @xfs.create_dir(root) catch {
    _ => ()
  }
  @xfs.create_dir(root + "/binary") catch {
    _ => ()
  }
  let policy = FsPolicy::new().scope(
    @lepusa.FileSystemScope::new(name="data", root~, writable=true),
  )
  let registry = register(@lepusa.CommandRegistry::new(), policy~)
  let grant = read_write_capability_for_window("main")
  let write = registry.dispatch_async(
    fs_request(
      "writeBytes", "{\"scope\":\"data\",\"path\":\"binary/data.bin\",\"base64\":\"aGVsbG8=\"}",
    ),
    capabilities=[grant],
  )
  assert_true(write.payload().unwrap_or("").contains("\"bytes\":5"))
  let read = registry.dispatch_async(
    fs_request("readBytes", "{\"scope\":\"data\",\"path\":\"binary/data.bin\"}"),
    capabilities=[grant],
  )
  assert_true(read.payload().unwrap_or("").contains("\"base64\":\"aGVsbG8=\""))
  let list = registry.dispatch_async(
    fs_request("list", "{\"scope\":\"data\",\"path\":\"binary\"}"),
    capabilities=[grant],
  )
  assert_true(
    list.payload().unwrap_or("").contains("\"entries\":[\"data.bin\"]"),
  )
  let metadata = registry.dispatch_async(
    fs_request("metadata", "{\"scope\":\"data\",\"path\":\"binary/data.bin\"}"),
    capabilities=[grant],
  )
  assert_true(metadata.payload().unwrap_or("").contains("\"exists\":true"))
  assert_true(metadata.payload().unwrap_or("").contains("\"isFile\":true"))
  assert_true(metadata.payload().unwrap_or("").contains("\"bytes\":5"))
  let deleted = registry.dispatch_async(
    fs_request("delete", "{\"scope\":\"data\",\"path\":\"binary/data.bin\"}"),
    capabilities=[grant],
  )
  assert_true(deleted.payload().unwrap_or("").contains("\"deleted\":true"))
  let missing = registry.dispatch_async(
    fs_request("delete", "{\"scope\":\"data\",\"path\":\"binary/data.bin\"}"),
    capabilities=[grant],
  )
  assert_true(missing.payload().unwrap_or("").contains("\"deleted\":false"))
}

///|
async test "fs registry enforces scope policy" {
  let policy = FsPolicy::new().scope(
    @lepusa.FileSystemScope::new(name="assets", root="/tmp/lepusa-assets"),
  )
  let registry = register(@lepusa.CommandRegistry::new(), policy~)
  let grant = read_write_capability_for_window("main")
  let unsafe_read = registry.dispatch_async(
    fs_request("readText", "{\"scope\":\"assets\",\"path\":\"../secret\"}"),
    capabilities=[grant],
  )
  assert_true(
    unsafe_read is InvokeError("readText", "unsafe filesystem path: ../secret"),
  )
  let write = registry.dispatch_async(
    fs_request(
      "writeText", "{\"scope\":\"assets\",\"path\":\"file.txt\",\"content\":\"no\"}",
    ),
    capabilities=[grant],
  )
  assert_true(
    write is InvokeError("writeText", "filesystem scope is read-only: assets"),
  )
  let invalid_bytes = registry.dispatch_async(
    fs_request(
      "writeBytes", "{\"scope\":\"assets\",\"path\":\"file.bin\",\"base64\":\"%%%\"}",
    ),
    capabilities=[grant],
  )
  assert_true(
    invalid_bytes
    is InvokeError("writeBytes", "invalid filesystem base64 content"),
  )
}

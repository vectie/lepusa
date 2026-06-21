///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("shell")
  .command_async("execute", permission=Shell, affinity=WorkerThread)
  .command_async("spawn", permission=Shell, affinity=WorkerThread)
  .command_async("kill", permission=Shell, affinity=WorkerThread)
  .command_async("stdinWrite", permission=Shell, affinity=WorkerThread)
}

///|
pub fn capability(name? : String = "shell") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Shell)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "shell",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct ShellPolicy {
  allowed_commands : Array[String]
} derive(Debug, Eq)

///|
pub fn ShellPolicy::new(allowed_commands? : Array[String] = []) -> ShellPolicy {
  { allowed_commands: allowed_commands.copy() }
}

///|
pub fn ShellPolicy::allowed_commands(self : ShellPolicy) -> Array[String] {
  self.allowed_commands.copy()
}

///|
pub fn ShellPolicy::allow(self : ShellPolicy, command : String) -> ShellPolicy {
  let allowed_commands = self.allowed_commands.copy()
  allowed_commands.push(command)
  { allowed_commands, }
}

///|
pub fn ShellPolicy::validate(self : ShellPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for command in self.allowed_commands {
    if command == "" {
      problems.push("shell allowed command is required")
    } else if seen.contains(command) {
      problems.push("shell allowed command must be unique: \{command}")
    } else {
      seen.push(command)
    }
  }
  problems
}

///|
fn ShellPolicy::allows(self : ShellPolicy, command : String) -> Bool {
  self.allowed_commands.is_empty() || self.allowed_commands.contains(command)
}

///|
priv struct ShellCommandSpec {
  command : String
  args : Array[String]
  cwd : String?
  stdin : String
}

///|
pub struct ShellProcess {
  id : String
  command : String
  args : Array[String]
  cwd : String?
  status : String
  stdin_chunks : Array[String]
}

///|
pub fn ShellProcess::id(self : ShellProcess) -> String {
  self.id
}

///|
pub fn ShellProcess::command(self : ShellProcess) -> String {
  self.command
}

///|
pub fn ShellProcess::args(self : ShellProcess) -> Array[String] {
  self.args.copy()
}

///|
pub fn ShellProcess::cwd(self : ShellProcess) -> String? {
  self.cwd
}

///|
pub fn ShellProcess::status(self : ShellProcess) -> String {
  self.status
}

///|
pub fn ShellProcess::stdin_chunks(self : ShellProcess) -> Array[String] {
  self.stdin_chunks.copy()
}

///|
pub struct ShellProcessTable {
  mut next_id : Int
  processes : Map[String, ShellProcess]
}

///|
pub fn ShellProcessTable::new() -> ShellProcessTable {
  { next_id: 1, processes: {} }
}

///|
pub fn ShellProcessTable::processes(
  self : ShellProcessTable,
) -> Array[ShellProcess] {
  let processes : Array[ShellProcess] = []
  self.processes.each(fn(_, process) { processes.push(process) })
  processes
}

///|
pub fn ShellProcessTable::get(
  self : ShellProcessTable,
  id : String,
) -> ShellProcess? {
  self.processes.get(id)
}

///|
fn ShellProcessTable::spawn(
  self : ShellProcessTable,
  spec : ShellCommandSpec,
) -> ShellProcess {
  let id = "shell-\{self.next_id}"
  self.next_id += 1
  let process = {
    id,
    command: spec.command,
    args: spec.args.copy(),
    cwd: spec.cwd,
    status: "running",
    stdin_chunks: [],
  }
  self.processes[id] = process
  process
}

///|
pub fn ShellProcessTable::kill(self : ShellProcessTable, id : String) -> Bool {
  match self.processes.get(id) {
    Some(process) => {
      self.processes[id] = { ..process, status: "killed" }
      true
    }
    None => false
  }
}

///|
pub fn ShellProcessTable::write_stdin(
  self : ShellProcessTable,
  id : String,
  text : String,
) -> Bool {
  match self.processes.get(id) {
    Some(process) => {
      let stdin_chunks = process.stdin_chunks.copy()
      stdin_chunks.push(text)
      self.processes[id] = { ..process, stdin_chunks, }
      true
    }
    None => false
  }
}

///|
pub fn registry(
  policy? : ShellPolicy = ShellPolicy::new(),
  table? : ShellProcessTable = ShellProcessTable::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, table~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : ShellPolicy = ShellPolicy::new(),
  table? : ShellProcessTable = ShellProcessTable::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("shell.execute", permission=Shell, handler=payload => {
    handle_execute(policy, payload)
  })
  .register_async_fn("shell.spawn", permission=Shell, handler=payload => {
    handle_spawn(policy, table, payload)
  })
  .register_async_fn("shell.kill", permission=Shell, handler=payload => {
    handle_kill(table, payload)
  })
  .register_async_fn("shell.stdinWrite", permission=Shell, handler=payload => {
    handle_stdin_write(table, payload)
  })
}

///|
async fn handle_execute(
  policy : ShellPolicy,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_command_payload(payload, context="shell execute") {
    Ok(spec) =>
      if !policy.allows(spec.command) {
        Err("shell command is not allowed: \{spec.command}")
      } else {
        Ok(
          Json::object({
            "command": Json::string(spec.command),
            "args": string_array_json(spec.args),
            "cwd": optional_string_json(spec.cwd),
            "stdin": Json::string(spec.stdin),
            "status": Json::string("delegated"),
          }).stringify(),
        )
      }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_spawn(
  policy : ShellPolicy,
  table : ShellProcessTable,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_command_payload(payload, context="shell spawn") {
    Ok(spec) =>
      if !policy.allows(spec.command) {
        Err("shell command is not allowed: \{spec.command}")
      } else {
        let process = table.spawn(spec)
        Ok(shell_process_json(process).stringify())
      }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_kill(
  table : ShellProcessTable,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_id_payload(payload, context="shell kill") {
    Ok(id) =>
      if table.kill(id) {
        Ok(
          Json::object({ "id": Json::string(id), "killed": Json::boolean(true) }).stringify(),
        )
      } else {
        Err("shell process not found: \{id}")
      }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_stdin_write(
  table : ShellProcessTable,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_stdin_payload(payload) {
    Ok((id, text)) =>
      if table.write_stdin(id, text) {
        Ok(
          Json::object({
            "id": Json::string(id),
            "written": Json::boolean(true),
          }).stringify(),
        )
      } else {
        Err("shell process not found: \{id}")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_command_payload(
  payload : String,
  context~ : String,
) -> Result[ShellCommandSpec, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(command) =>
      command_spec(command, args=[], cwd=None, stdin="", context~)
    Object(object) =>
      match array_string_field(object, "args", context~) {
        Ok(args) =>
          command_spec(
            string_field(object, "command").unwrap_or(""),
            args~,
            cwd=string_field(object, "cwd"),
            stdin=string_field(object, "stdin").unwrap_or(""),
            context~,
          )
        Err(problem) => Err(problem)
      }
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn command_spec(
  command : String,
  args~ : Array[String],
  cwd~ : String?,
  stdin~ : String,
  context~ : String,
) -> Result[ShellCommandSpec, String] {
  if command == "" {
    Err("\{context} command is required")
  } else {
    Ok({ command, args: args.copy(), cwd, stdin })
  }
}

///|
fn decode_id_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  let id = match json {
    String(value) => value
    Object(object) => string_field(object, "id").unwrap_or("")
    _ => return Err("\{context} payload must be a string or object")
  }
  if id == "" {
    Err("\{context} id is required")
  } else {
    Ok(id)
  }
}

///|
fn decode_stdin_payload(payload : String) -> Result[(String, String), String] {
  if payload == "" {
    return Err("shell stdinWrite payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid shell stdinWrite payload: \{error}")
  }
  match json {
    Object(object) => {
      let id = string_field(object, "id").unwrap_or("")
      let text = string_field(object, "text").unwrap_or("")
      if id == "" {
        Err("shell stdinWrite id is required")
      } else {
        Ok((id, text))
      }
    }
    _ => Err("shell stdinWrite payload must be an object")
  }
}

///|
fn shell_process_json(process : ShellProcess) -> Json {
  Json::object({
    "id": Json::string(process.id()),
    "command": Json::string(process.command()),
    "args": string_array_json(process.args()),
    "cwd": optional_string_json(process.cwd()),
    "status": Json::string(process.status()),
    "stdinChunks": string_array_json(process.stdin_chunks()),
  })
}

///|
fn string_array_json(values : Array[String]) -> Json {
  Json::array(values.map(fn(value) { Json::string(value) }))
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn array_string_field(
  object : Map[String, Json],
  key : String,
  context~ : String,
) -> Result[Array[String], String] {
  match object.get(key) {
    Some(Array(items)) => {
      let values : Array[String] = []
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => return Err("\{context} \{key} entries must be strings")
        }
      }
      Ok(values)
    }
    Some(_) => Err("\{context} \{key} must be an array")
    None => Ok([])
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

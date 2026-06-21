///|
fn drop_program(argv : Array[String]) -> Array[String] {
  let args : Array[String] = []
  for i in 1..<argv.length() {
    args.push(argv[i])
  }
  args
}

///|
fn Array::with_first(self : Array[String], value : String) -> Array[String] {
  let args : Array[String] = [value]
  for i in 1..<self.length() {
    args.push(self[i])
  }
  args
}

///|
fn project_path_arg(args : Array[String]) -> String? {
  option_arg(args, "--project")
}

///|
fn project_flag_missing_value(args : Array[String]) -> Bool {
  option_flag_missing_value(args, "--project")
}

///|
fn workspace_path_arg(args : Array[String]) -> String? {
  option_arg(args, "--workspace")
}

///|
fn workspace_flag_missing_value(args : Array[String]) -> Bool {
  option_flag_missing_value(args, "--workspace")
}

///|
fn option_arg(args : Array[String], flag : String) -> String? {
  for i in 0..<args.length() {
    if args[i] == flag {
      match args.get(i + 1) {
        Some(value) =>
          if value.has_prefix("--") {
            return None
          } else {
            return Some(value)
          }
        None => return None
      }
    }
  }
  None
}

///|
fn option_flag_missing_value(args : Array[String], flag : String) -> Bool {
  for i in 0..<args.length() {
    if args[i] == flag {
      match args.get(i + 1) {
        Some(value) => if value.has_prefix("--") { return true }
        None => return true
      }
    }
  }
  false
}

///|
async fn project_config_path(args : Array[String]) -> String? {
  match project_path_arg(args) {
    Some(path) => Some(path)
    None => {
      let found = @fs.exists("lepusa.json") catch { _ => false }
      if found {
        Some("lepusa.json")
      } else {
        None
      }
    }
  }
}

///|
fn positional_args(args : Array[String]) -> Array[String] {
  let values : Array[String] = []
  let mut skip_next = false
  for i in 1..<args.length() {
    if skip_next {
      skip_next = false
    } else if args[i] == "--project" ||
      args[i] == "--workspace" ||
      args[i] == "--global" ||
      args[i] == "--module" {
      skip_next = true
    } else if is_boolean_flag(args[i]) {
      continue
    } else {
      values.push(args[i])
    }
  }
  values
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  for arg in args {
    if arg == flag {
      return true
    }
  }
  false
}

///|
fn is_boolean_flag(arg : String) -> Bool {
  arg == "--launch" ||
  arg == "--json" ||
  arg == "--async-bridge" ||
  arg == "--strict"
}

///|
async fn ensure_directory(path : String, problems : Array[String]) -> Unit {
  let exists = @fs.exists(path) catch { _ => false }
  if path == "" || path == "." || exists {
    return
  }
  @fs.mkdir(path, recursive=true, permission=0o755) catch {
    error => problems.push("could not create directory \{path}: \{error}")
  }
}

///|
fn join_path(base : String, path : String) -> String {
  if base == "" || base == "." {
    path
  } else if path == "" {
    base
  } else {
    "\{base}/\{path}"
  }
}

///|
fn parent_directory(path : String) -> String {
  let normalized = path.trim_end(chars="/\\").to_owned()
  match normalized.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { normalized[:index].to_owned() }
    None => "."
  }
}

///|
fn moon_work_string(value : String) -> String {
  let mut out = "\""
  for char in value {
    match char {
      '"' => out += "\\\""
      '\\' => out += "\\\\"
      '\n' => out += "\\n"
      '\r' => out += "\\r"
      '\t' => out += "\\t"
      _ => out += char.to_string()
    }
  }
  out + "\""
}

///|
pub(all) enum OperationScopeKind {
  PathOperation
  ShellOperation
  UrlOperation
} derive(Debug, Eq)

///|
pub fn OperationScopeKind::name(self : OperationScopeKind) -> String {
  match self {
    PathOperation => "path"
    ShellOperation => "shell"
    UrlOperation => "url"
  }
}

///|
pub struct OperationScope {
  kind : OperationScopeKind
  value : String
  writable : Bool
} derive(Debug, Eq)

///|
pub fn OperationScope::path(
  root~ : String,
  writable? : Bool = false,
) -> OperationScope {
  { kind: PathOperation, value: root, writable }
}

///|
pub fn OperationScope::shell(command : String) -> OperationScope {
  { kind: ShellOperation, value: command, writable: false }
}

///|
pub fn OperationScope::url(origin : String) -> OperationScope {
  { kind: UrlOperation, value: origin, writable: false }
}

///|
pub fn OperationScope::kind(self : OperationScope) -> OperationScopeKind {
  self.kind
}

///|
pub fn OperationScope::value(self : OperationScope) -> String {
  self.value
}

///|
pub fn OperationScope::root(self : OperationScope) -> String {
  if self.kind is PathOperation {
    self.value
  } else {
    ""
  }
}

///|
pub fn OperationScope::command(self : OperationScope) -> String {
  if self.kind is ShellOperation {
    self.value
  } else {
    ""
  }
}

///|
pub fn OperationScope::origin(self : OperationScope) -> String {
  if self.kind is UrlOperation {
    self.value
  } else {
    ""
  }
}

///|
pub fn OperationScope::writable(self : OperationScope) -> Bool {
  self.writable
}

///|
pub fn OperationScope::allows(
  self : OperationScope,
  requested : OperationScope,
) -> Bool {
  if self.kind != requested.kind {
    return false
  }
  match self.kind {
    PathOperation =>
      (!requested.writable || self.writable) &&
      path_inside_scope(self.value, requested.value)
    ShellOperation => self.value == requested.value
    UrlOperation => self.value == requested.value
  }
}

///|
pub fn OperationScope::validate(self : OperationScope) -> Array[String] {
  let problems : Array[String] = []
  if self.value == "" {
    problems.push("\{self.kind.name()} operation scope value is required")
  }
  match self.kind {
    PathOperation =>
      if self.value.contains("\u{0000}") {
        problems.push("path operation scope must not contain null bytes")
      }
    ShellOperation =>
      if contains_ascii_space(self.value) ||
        self.value.contains("\n") ||
        self.value.contains("\r") {
        problems.push(
          "shell operation scope command must be a single executable",
        )
      }
    UrlOperation =>
      if !valid_url_origin(self.value) {
        problems.push(
          "url operation scope origin must be http(s): \{self.value}",
        )
      }
  }
  problems
}

///|
pub fn OperationScope::to_json(self : OperationScope) -> String {
  let field = match self.kind {
    PathOperation => "root"
    ShellOperation => "command"
    UrlOperation => "origin"
  }
  let writable = if self.kind is PathOperation {
    ",\"writable\":\{self.writable.json_bool()}"
  } else {
    ""
  }
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"\{field}\":\{self.value.json_string()}",
    writable,
    "}",
  ].join("")
}

///|
fn OperationScope::fingerprint(self : OperationScope) -> String {
  "\{self.kind.name()}:\{self.value}:\{self.writable}"
}

///|
fn path_inside_scope(root : String, target : String) -> Bool {
  let root = normalize_scope_path(root)
  let target = normalize_scope_path(target)
  target == root ||
  target.has_prefix(root + "/") ||
  target.has_prefix(root + "\\")
}

///|
fn normalize_scope_path(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  if trimmed == "" {
    path
  } else {
    trimmed
  }
}

///|
fn contains_ascii_space(value : String) -> Bool {
  value.contains(" ") || value.contains("\t")
}

///|
fn valid_url_origin(origin : String) -> Bool {
  if !(origin.has_prefix("https://") || origin.has_prefix("http://")) {
    return false
  }
  let without_scheme = if origin.has_prefix("https://") {
    origin[8:]
  } else {
    origin[7:]
  }
  without_scheme != "" &&
  !without_scheme.contains("/") &&
  !without_scheme.contains("?") &&
  !without_scheme.contains("#")
}

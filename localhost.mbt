///|
pub struct LocalhostSource {
  host : String
  port : Int
  path : String
  readiness_path : String?
  command : Array[String]
} derive(Debug, Eq)

///|
pub fn LocalhostSource::new(
  port~ : Int,
  host? : String = "127.0.0.1",
  path? : String = "/",
  readiness_path? : String,
  command? : Array[String] = [],
) -> LocalhostSource {
  {
    host,
    port,
    path: normalize_localhost_path(path),
    readiness_path: readiness_path.map(normalize_localhost_path),
    command: command.copy(),
  }
}

///|
pub fn LocalhostSource::host(self : LocalhostSource) -> String {
  self.host
}

///|
pub fn LocalhostSource::port(self : LocalhostSource) -> Int {
  self.port
}

///|
pub fn LocalhostSource::path(self : LocalhostSource) -> String {
  self.path
}

///|
pub fn LocalhostSource::readiness_path(self : LocalhostSource) -> String? {
  self.readiness_path
}

///|
pub fn LocalhostSource::command(self : LocalhostSource) -> Array[String] {
  self.command.copy()
}

///|
pub fn LocalhostSource::url(self : LocalhostSource) -> String {
  "http://\{self.host}:\{self.port}\{self.path}"
}

///|
pub fn LocalhostSource::readiness_url(self : LocalhostSource) -> String {
  let path = self.readiness_path.unwrap_or(self.path)
  "http://\{self.host}:\{self.port}\{path}"
}

///|
pub fn LocalhostSource::local_service(
  self : LocalhostSource,
  name : String,
) -> LocalService? {
  if self.command.is_empty() {
    None
  } else {
    Some(
      LocalService::new(
        name~,
        command=self.command,
        readiness_url=self.readiness_url(),
      ),
    )
  }
}

///|
pub fn LocalhostSource::validate(self : LocalhostSource) -> Array[String] {
  let problems : Array[String] = []
  if self.host == "" {
    problems.push("localhost host is required")
  }
  if self.port <= 0 || self.port > 65535 {
    problems.push("localhost port must be between 1 and 65535")
  }
  if !self.path.has_prefix("/") {
    problems.push("localhost path must start with /")
  }
  match self.readiness_path {
    Some(path) =>
      if !path.has_prefix("/") {
        problems.push("localhost readiness path must start with /")
      }
    None => ()
  }
  for part in self.command {
    if part == "" {
      problems.push("localhost command entries must not be empty")
    }
  }
  problems
}

///|
fn normalize_localhost_path(path : String) -> String {
  if path == "" {
    "/"
  } else if path.has_prefix("/") {
    path
  } else {
    "/" + path
  }
}

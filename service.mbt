///|
pub struct LocalService {
  name : String
  command : Array[String]
  readiness_url : String
} derive(Debug, Eq)

///|
pub fn LocalService::new(
  name~ : String,
  command~ : Array[String],
  readiness_url~ : String,
) -> LocalService {
  { name, command: command.copy(), readiness_url }
}

///|
pub fn LocalService::name(self : LocalService) -> String {
  self.name
}

///|
pub fn LocalService::command(self : LocalService) -> Array[String] {
  self.command.copy()
}

///|
pub fn LocalService::readiness_url(self : LocalService) -> String {
  self.readiness_url
}

///|
pub fn LocalService::validate(self : LocalService) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("local service name is required")
  }
  if self.command.is_empty() {
    problems.push("local service command is required")
  }
  for part in self.command {
    if part == "" {
      problems.push("local service command entries must not be empty")
    }
  }
  if self.readiness_url == "" {
    problems.push("local service readiness url is required")
  }
  problems
}

///|
pub fn LocalService::to_json(self : LocalService) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"command\":[\{self.command.map(fn(part) { part.json_string() }).join(",")}],",
    "\"readinessUrl\":\{self.readiness_url.json_string()}",
    "}",
  ].join("")
}

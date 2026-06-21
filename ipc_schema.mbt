///|
pub struct IpcSchema {
  name : String
  typescript : String
  description : String
} derive(Debug, Eq)

///|
pub fn IpcSchema::new(
  name~ : String,
  typescript? : String = "unknown",
  description? : String = "",
) -> IpcSchema {
  { name, typescript, description }
}

///|
pub fn IpcSchema::any() -> IpcSchema {
  IpcSchema::new(name="any", typescript="unknown")
}

///|
pub fn IpcSchema::unit() -> IpcSchema {
  IpcSchema::new(name="unit", typescript="void")
}

///|
pub fn IpcSchema::json() -> IpcSchema {
  IpcSchema::new(name="json", typescript="unknown")
}

///|
pub fn IpcSchema::string() -> IpcSchema {
  IpcSchema::new(name="string", typescript="string")
}

///|
pub fn IpcSchema::boolean() -> IpcSchema {
  IpcSchema::new(name="boolean", typescript="boolean")
}

///|
pub fn IpcSchema::number() -> IpcSchema {
  IpcSchema::new(name="number", typescript="number")
}

///|
pub fn IpcSchema::object(
  name : String,
  typescript : String,
  description? : String = "",
) -> IpcSchema {
  IpcSchema::new(name~, typescript~, description~)
}

///|
pub fn IpcSchema::array(item : IpcSchema) -> IpcSchema {
  IpcSchema::new(
    name="\{item.name()}[]",
    typescript="ReadonlyArray<\{item.typescript()}>",
    description=item.description(),
  )
}

///|
pub fn IpcSchema::name(self : IpcSchema) -> String {
  self.name
}

///|
pub fn IpcSchema::typescript(self : IpcSchema) -> String {
  self.typescript
}

///|
pub fn IpcSchema::description(self : IpcSchema) -> String {
  self.description
}

///|
pub fn IpcSchema::validate(self : IpcSchema) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("ipc schema name is required")
  }
  if self.typescript == "" {
    problems.push("ipc schema TypeScript type is required")
  }
  problems
}

///|
pub fn IpcSchema::to_json(self : IpcSchema) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"typescript\":\{self.typescript.json_string()},",
    "\"description\":\{self.description.json_string()}",
    "}",
  ].join("")
}

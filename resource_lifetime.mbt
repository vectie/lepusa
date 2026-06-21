///|
pub struct ResourceLeakReport {
  resources : Array[ResourceEntry]
} derive(Debug, Eq)

///|
pub fn ResourceLeakReport::new(
  resources? : Array[ResourceEntry] = [],
) -> ResourceLeakReport {
  { resources: resources.copy() }
}

///|
pub fn ResourceLeakReport::resources(
  self : ResourceLeakReport,
) -> Array[ResourceEntry] {
  self.resources.copy()
}

///|
pub fn ResourceLeakReport::handles(
  self : ResourceLeakReport,
) -> Array[ResourceHandle] {
  self.resources.map(fn(resource) { resource.handle() })
}

///|
pub fn ResourceLeakReport::count(self : ResourceLeakReport) -> Int {
  self.resources.length()
}

///|
pub fn ResourceLeakReport::ok(self : ResourceLeakReport) -> Bool {
  self.resources.is_empty()
}

///|
pub fn ResourceLeakReport::leaked(self : ResourceLeakReport) -> Bool {
  !self.ok()
}

///|
pub fn ResourceLeakReport::kinds(self : ResourceLeakReport) -> Array[String] {
  let kinds : Array[String] = []
  for resource in self.resources {
    if !kinds.contains(resource.kind()) {
      kinds.push(resource.kind())
    }
  }
  kinds
}

///|
pub fn ResourceLeakReport::owners(self : ResourceLeakReport) -> Array[String] {
  let owners : Array[String] = []
  for resource in self.resources {
    if resource.owner() != "" && !owners.contains(resource.owner()) {
      owners.push(resource.owner())
    }
  }
  owners
}

///|
pub fn ResourceLeakReport::messages(self : ResourceLeakReport) -> Array[String] {
  self.resources.map(fn(resource) {
    if resource.owner() == "" {
      "resource still open: \{resource.id()} \{resource.kind()}"
    } else {
      "resource still open: \{resource.id()} \{resource.kind()} owned by \{resource.owner()}"
    }
  })
}

///|
pub fn ResourceLeakReport::to_json(self : ResourceLeakReport) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"count\":\{self.count()},",
    "\"resources\":[\{self.resources.map(fn(resource) { resource.to_json() }).join(",")}],",
    "\"messages\":[\{self.messages().map(fn(message) { message.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub struct ResourceCleanupReport {
  closed : Array[ResourceEntry]
  remaining : Array[ResourceEntry]
} derive(Debug, Eq)

///|
pub fn ResourceCleanupReport::new(
  closed? : Array[ResourceEntry] = [],
  remaining? : Array[ResourceEntry] = [],
) -> ResourceCleanupReport {
  { closed: closed.copy(), remaining: remaining.copy() }
}

///|
pub fn ResourceCleanupReport::closed(
  self : ResourceCleanupReport,
) -> Array[ResourceEntry] {
  self.closed.copy()
}

///|
pub fn ResourceCleanupReport::remaining(
  self : ResourceCleanupReport,
) -> Array[ResourceEntry] {
  self.remaining.copy()
}

///|
pub fn ResourceCleanupReport::closed_count(self : ResourceCleanupReport) -> Int {
  self.closed.length()
}

///|
pub fn ResourceCleanupReport::remaining_count(
  self : ResourceCleanupReport,
) -> Int {
  self.remaining.length()
}

///|
pub fn ResourceCleanupReport::ok(self : ResourceCleanupReport) -> Bool {
  self.remaining.is_empty()
}

///|
pub fn ResourceCleanupReport::leak_report(
  self : ResourceCleanupReport,
) -> ResourceLeakReport {
  ResourceLeakReport::new(resources=self.remaining)
}

///|
pub fn ResourceCleanupReport::to_json(self : ResourceCleanupReport) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"closedCount\":\{self.closed_count()},",
    "\"remainingCount\":\{self.remaining_count()},",
    "\"closed\":[\{self.closed.map(fn(resource) { resource.to_json() }).join(",")}],",
    "\"remaining\":[\{self.remaining.map(fn(resource) { resource.to_json() }).join(",")}]",
    "}",
  ].join("")
}

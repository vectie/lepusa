///|
pub fn Capability::with_file_system_scopes(
  self : Capability,
  scopes : Array[FileSystemScope],
) -> Capability {
  let mut capability = self
  if self.permissions().contains(FileSystemRead) {
    for scope in scopes {
      capability = capability.add_file_system_scope_once(
        OperationScope::path(root=scope.root()),
      )
    }
  }
  if self.permissions().contains(FileSystemWrite) {
    for scope in scopes {
      if scope.writable() {
        capability = capability.add_file_system_scope_once(
          OperationScope::path(root=scope.root(), writable=true),
        )
      }
    }
  }
  capability
}

///|
pub fn capabilities_with_file_system_scopes(
  capabilities~ : Array[Capability],
  scopes~ : Array[FileSystemScope],
) -> Array[Capability] {
  capabilities.map(fn(capability) { capability.with_file_system_scopes(scopes) })
}

///|
fn Capability::add_file_system_scope_once(
  self : Capability,
  scope : OperationScope,
) -> Capability {
  if self.has_operation_scope(scope) {
    self
  } else {
    self.operation_scope(scope)
  }
}

///|
fn Capability::has_operation_scope(
  self : Capability,
  candidate : OperationScope,
) -> Bool {
  self
  .operation_scopes()
  .any(fn(scope) {
    scope.kind() == candidate.kind() &&
    scope.value() == candidate.value() &&
    scope.writable() == candidate.writable()
  })
}

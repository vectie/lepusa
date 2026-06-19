///|
pub struct BundleWriteResult {
  root : String
  files : Array[String]
  resources : Array[String]
} derive(Debug, Eq)

///|
pub fn BundleWriteResult::root(self : BundleWriteResult) -> String {
  self.root
}

///|
pub fn BundleWriteResult::files(self : BundleWriteResult) -> Array[String] {
  self.files
}

///|
pub fn BundleWriteResult::resources(self : BundleWriteResult) -> Array[String] {
  self.resources
}

///|
pub async fn write_plan(
  plan : @lepusa.BundlePlan,
  out_dir : String,
) -> Result[BundleWriteResult, Array[String]] {
  match plan.files() {
    Ok(files) => {
      let root = normalize_output_root(out_dir)
      let problems : Array[String] = []
      let written : Array[String] = []
      let copied_resources : Array[String] = []
      ensure_directory(root, problems)
      for file in files {
        let path = join_path(root, file.path())
        ensure_directory(parent_directory(path), problems)
        if problems.is_empty() {
          let problem_count = problems.length()
          @fs.write_file(
            path,
            file.content(),
            create_mode=CreateOrTruncate,
            permission=0o644,
          ) catch {
            error => problems.push("could not write \{path}: \{error}")
          }
          if file.executable() {
            @fs.chmod(path, 0o755) catch {
              error =>
                problems.push("could not mark executable \{path}: \{error}")
            }
          }
          if problems.length() == problem_count {
            written.push(path)
          }
        }
      }
      for resource in plan.resources() {
        let path = join_path(root, resource.path())
        ensure_directory(parent_directory(path), problems)
        if problems.is_empty() {
          let problem_count = problems.length()
          copy_bundle_resource(resource, path, problems)
          if problems.length() == problem_count {
            copied_resources.push(path)
          }
        }
      }
      if problems.is_empty() {
        Ok({ root, files: written, resources: copied_resources })
      } else {
        Err(problems)
      }
    }
    Err(problems) => Err(problems)
  }
}

///|
async fn copy_bundle_resource(
  resource : @lepusa.BundleResource,
  destination : String,
  problems : Array[String],
) -> Unit {
  if resource.kind() is AssetResource {
    copy_bundle_asset_directory(resource.source_path(), destination, problems)
    return
  }
  let content = @fs.read_file(resource.source_path()) catch {
    error => {
      problems.push(
        "could not read bundle resource \{resource.source_path()}: \{error}",
      )
      return
    }
  }
  @fs.write_file(
    destination,
    content,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    error =>
      problems.push("could not write bundle resource \{destination}: \{error}")
  }
}

///|
async fn copy_bundle_asset_directory(
  source : String,
  destination : String,
  problems : Array[String],
) -> Unit {
  let is_dir = @xfs.is_dir(source) catch {
    _ => {
      problems.push("could not inspect bundle asset \{source}")
      return
    }
  }
  if !is_dir {
    copy_bundle_file(source, destination, problems)
    return
  }
  ensure_directory(destination, problems)
  if !problems.is_empty() {
    return
  }
  let entries = @xfs.read_dir(source) catch {
    _ => {
      problems.push("could not read bundle asset directory \{source}")
      return
    }
  }
  for entry in entries {
    copy_bundle_asset_directory(
      join_path(source, entry),
      join_path(destination, entry),
      problems,
    )
  }
}

///|
async fn copy_bundle_file(
  source : String,
  destination : String,
  problems : Array[String],
) -> Unit {
  let content = @fs.read_file(source) catch {
    error => {
      problems.push("could not read bundle resource \{source}: \{error}")
      return
    }
  }
  ensure_directory(parent_directory(destination), problems)
  if !problems.is_empty() {
    return
  }
  @fs.write_file(
    destination,
    content,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    error =>
      problems.push("could not write bundle resource \{destination}: \{error}")
  }
}

///|
fn normalize_output_root(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  if trimmed.is_empty() {
    "_build/lepusa-bundle"
  } else {
    trimmed
  }
}

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

///|
struct BundleWriteResult {
  root : String
  files : Array[String]
} derive(Debug, Eq)

///|
async fn write_bundle_plan(
  plan : @lepusa.BundlePlan,
  out_dir : String,
) -> Result[BundleWriteResult, Array[String]] {
  match plan.files() {
    Ok(files) => {
      let root = normalize_output_root(out_dir)
      let problems : Array[String] = []
      let written : Array[String] = []
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
      if problems.is_empty() {
        Ok({ root, files: written })
      } else {
        Err(problems)
      }
    }
    Err(problems) => Err(problems)
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

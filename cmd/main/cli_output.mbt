///|
fn render_problems(title : String, problems : Array[String]) -> String {
  let lines : Array[String] = [title]
  for problem in problems {
    lines.push("[fail] \{problem}")
  }
  lines.join("\n") + "\n"
}

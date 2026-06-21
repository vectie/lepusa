///|
test "windows launch exit codes report concrete webview2 blockers" {
  let cases = [
    (2, "host platform"),
    (20, "WebView2Loader.dll is missing"),
    (21, "required WebView2 factory APIs"),
    (22, "WebView2 Runtime is not installed"),
    (23, "Ole32.dll is not available"),
    (24, "required COM stream APIs"),
  ]
  for item in cases {
    let (code, message) = item
    match windows_status_from_exit_code(code) {
      RunUnsupported(problem) => assert_true(problem.contains(message))
      _ => abort("expected unsupported Windows WebView2 blocker")
    }
  }
  match windows_status_from_exit_code(3) {
    RunFailed(problem) => assert_true(problem.contains("COM apartment"))
    _ => abort("expected Windows COM initialization failure")
  }
  match windows_status_from_exit_code(4) {
    RunFailed(problem) => assert_true(problem.contains("class registration"))
    _ => abort("expected Windows class registration failure")
  }
  match windows_status_from_exit_code(5) {
    RunFailed(problem) => assert_true(problem.contains("environment or window"))
    _ => abort("expected Windows WebView2 creation failure")
  }
}

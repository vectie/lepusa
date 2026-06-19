///|
test "macos backend links Cocoa and WebKit" {
  match MacOSBackend::new() {
    Ok(backend) => {
      assert_eq(backend.name(), "macos")
      assert_eq(backend.webview_engine(), "WKWebView")
    }
    Err(problem) => abort(problem)
  }
}

///|
test "macos backend lowers runtime host to launch plan" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    title="macOS",
    source=@lepusa.Source::html("<main>macOS</main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(runtime_plan) =>
      match MacOSBackend::new() {
        Ok(backend) =>
          match backend.plan(@runtime.RuntimeHost::new(runtime_plan)) {
            Ok(plan) => {
              assert_eq(plan.backend_name(), "macos")
              assert_eq(plan.webview_engine(), "WKWebView")
              let webviews = plan.webviews()
              assert_eq(webviews.length(), 1)
              assert_eq(webviews[0].title(), "macOS")
              assert_eq(webviews[0].url(), "lepusa://inline/main/index.html")
              assert_true(
                webviews[0].initialization_scripts()[0].contains(
                  "__lepusaInvoke",
                ),
              )
              assert_eq(
                plan.runtime_manifest().bridge_url(),
                "lepusa://runtime/bridge.js",
              )
              let json = plan.manifest_json()
              assert_true(json.contains("\"nativeBackend\":\"macos\""))
              assert_true(json.contains("\"webviewEngine\":\"WKWebView\""))
              assert_true(json.contains("\"runtime\""))
              assert_true(json.contains("\"label\":\"main\""))
            }
            Err(_) => abort("unexpected invalid macOS launch plan")
          }
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

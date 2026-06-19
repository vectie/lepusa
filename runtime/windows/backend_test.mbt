///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      title="Windows",
      source=@lepusa.Source::html("<main>Windows</main>"),
    )
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "windows backend exposes webview2 descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "windows")
  assert_eq(descriptor.webview_engine(), "WebView2")
}

///|
test "windows backend reports host availability" {
  match detect() {
    Ok(descriptor) => assert_eq(descriptor.name(), "windows")
    Err(problem) =>
      assert_eq(problem, "Windows WebView2 backend is not available")
  }
}

///|
test "windows backend lowers runtime host to native runner contract" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "windows")
      assert_eq(plan.webview_engine(), "WebView2")
      assert_eq(plan.webviews().length(), 1)
      assert_true(plan.startup_operations()[0] is NativeRunEffect("boot"))
      assert_true(
        plan.bootstrap_json().contains("\"nativeBackend\":\"windows\""),
      )
    }
    Err(_) => abort("unexpected invalid Windows runner plan")
  }
}

///|
test "windows backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "windows")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"windows\""),
      )
    }
    Err(_) => abort("unexpected invalid Windows native runtime")
  }
}

///|
test "windows backend prepares run plan and reports unsupported launch" {
  match runtime(test_host()) {
    Ok(runtime) => {
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is WindowsPrepared)
          assert_eq(result.plan().webview_count(), 1)
          assert_eq(
            result.plan().first_webview_url(),
            "lepusa://inline/main/index.html",
          )
          assert_eq(result.plan().startup_operation_count(), 1)
        }
        Err(_) => abort("unexpected invalid Windows dry run")
      }
      match launch(runtime) {
        Ok(result) =>
          match result.status() {
            WindowsLaunchUnsupported(message) =>
              assert_true(message.contains("WebView2 launch loop"))
            _ => abort("unexpected Windows launch status")
          }
        Err(_) => abort("unexpected invalid Windows launch plan")
      }
    }
    Err(_) => abort("unexpected invalid Windows native runtime")
  }
}

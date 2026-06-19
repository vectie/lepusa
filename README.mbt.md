# Lepusa

Lepusa is a standalone MoonBit desktop application framework.

The core decision is to build a MoonBit-owned, Tauri-shaped framework on top of
system WebViews, with an app-authoring style close to Rabbita. Tauri and Lepus
are references to learn from, not runtime layers that app authors must carry.

Start with:

- [Research Decision](docs/DESKTOP_FRAMEWORK_RESEARCH.md)
- [Architecture Plan](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)

## Intended Shape

```text
MoonBit app code
  -> Rabbita-style Lepusa app syntax
  -> typed command + event IPC
  -> capability-scoped platform plugins
  -> system WebView runtime
  -> platform bundles for macOS, Windows, and Linux
```

The first implementation slice already owns the public MoonBit foundation:

- Rabbita-style `cell_with_dispatch` and `new(cell)` app construction
- `WindowConfig`, `Source`, `Plugin`, `Capability`, `Cmd`, `Event`, and typed
  IPC request/response contracts
- `ProjectManifest` validation plus `LaunchPlan`, `RuntimePlan`, and
  `BundlePlan` generation as the boundaries native runtime and platform
  bundler code will consume next

The common authoring path is intentionally small:

```moonbit nocheck
///|
fn main {
  let (dispatch, cell) = @lepusa.cell_with_dispatch(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
  )
  let app = @lepusa.new(cell)
  app.with_startup(load_initial_state(dispatch))
  app.window(
    title="Hello Lepusa",
    width=1000,
    height=720,
    source=@lepusa.Source::local_path("dist"),
  )
  match app.launch_plan() {
    Ok(plan) => boot_native_runtime(plan)
    Err(problems) => fail_fast(problems)
  }
}
```

For backend and packaging work, the app model can be lowered without pulling in
product-specific code:

```moonbit nocheck
///|
let runtime = app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview())

///|
let bundle = @lepusa.BundleConfig::new(
  @lepusa.AppMetadata::new(
    identifier="dev.example.app",
    product_name="Example App",
    version="0.1.0",
  ),
)
```

For reusable project configuration, use `ProjectManifest`:

```moonbit nocheck
///|
let manifest = @lepusa.ProjectManifest::new(metadata)
  .with_window(
    @lepusa.WindowConfig::new(source=@lepusa.Source::local_path("dist")),
  )
  .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
  .with_capability(@lepusa.Capability::new("main").command("core.invoke"))

///|
let runtime = manifest.runtime_plan(root)

///|
let bundle = manifest.bundle_plan(root, target=@lepusa.MacOS)
```

## CLI

The native CLI is intentionally small while the runtime backend is being built:

```bash
moon run cmd/main --target native -- doctor
moon run cmd/main --target native -- plan
moon run cmd/main --target native -- bridge
moon run cmd/main --target native -- bundle-plan macos
moon run cmd/main --target native -- bundle-write linux _build/lepusa-bundle
```

These commands exercise the public planning contracts and give the native
runtime and bundler work concrete outputs to consume.

`lepusa plan` includes resolved WebView load URLs, so backend work can consume
`RuntimePlan::windows()` directly.

`lepusa bridge` emits the JavaScript bridge that frontends load as
`window.lepusa`, including `invoke(route, payload)` and route namespaces such as
`lepusa.core.invoke(payload)`.

`lepusa bundle-plan` now also validates concrete bundle artifact plans through
`BundlePlan::files()`: platform metadata plus `lepusa/runtime.json` and
`lepusa/bridge.js`.

`lepusa bundle-write` materializes those planned files under an output
directory. This keeps the reusable framework boundary pure while giving native
runtime and installer work real platform bundle artifacts to consume.

## Boundary

Lepusa owns the reusable desktop framework:

- native window and WebView runtime
- frontend-to-MoonBit command bridge
- app capabilities and permissions
- official platform plugins
- dev/build/bundle CLI

Consumer projects own product behavior, backend services, schemas, routes,
workspaces, dashboards, and domain-specific adapters.

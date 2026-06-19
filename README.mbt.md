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
- `@lepusa/runtime` host/session snapshots that native WebView backends can
  consume without reinterpreting app configuration

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
    .with_startup(load_initial_state(dispatch))
    .on_shutdown(persist_state(dispatch))
    .window(title="Hello Lepusa", width=1000, height=720)
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
  .with_capability(
    @lepusa.Capability::new("main").window("main").command("core.invoke"),
  )

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
moon run cmd/main --target native -- manifest
moon run cmd/main --target native -- bridge
moon run cmd/main --target native -- dev
moon run cmd/main --target native -- init _build/lepusa-app
moon run cmd/main --target native -- plan --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- manifest --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- dev --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- plugin new file-dialog _build/lepusa-plugin-file-dialog
moon run cmd/main --target native -- bundle-plan macos
moon run cmd/main --target native -- bundle-write linux _build/lepusa-bundle --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- build macos _build/lepusa-build --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bundle windows _build/lepusa-bundle-win
```

These commands exercise the public planning contracts and give the native
runtime and bundler work concrete outputs to consume.

`lepusa plan` includes resolved WebView load URLs, so backend work can consume
`RuntimePlan::windows()` directly.

Generated bridges only expose command routes granted to the current window by
capabilities. `RuntimePlan::command_routes()` still reports all declared plugin
routes for metadata and bundling.

Lifecycle hooks lower to the same backend action model as startup commands, so
platform backends can handle shutdown and window-close events without reading
application construction state.

When a window omits `source`, `App` lowers the root `Cell` into a generated
Rabbita-style HTML document served from the runtime manifest as a virtual file.

`lepusa init` writes a standalone MoonBit project skeleton that imports
`vectie/lepusa` directly. It is intentionally small: `moon.mod`, `moon.pkg`,
`lepusa.json`, `main.mbt`, and `README.mbt.md`.

`lepusa.json` is the app-neutral project boundary. It describes metadata,
runtime backend, windows, plugin command routes, and capability grants. Native
CLI commands consume the nearest `lepusa.json` from the current directory, or a
file passed with `--project`.

`lepusa plugin new` writes a standalone plugin skeleton with plugin metadata,
native command registration, and a scoped capability helper.

`lepusa manifest` emits the portable native-runner JSON from
`RuntimePlan::launch_manifest()`: WebView boot data, bridge hook names,
document-start scripts, protocol mappings, inline virtual files with MIME
types, and command routes.

`@lepusa/runtime` turns a `RuntimePlan` into a `RuntimeSession`: resolved
window frames, protocol mappings, virtual files, generated bridge source, and
command dispatch through the declared capabilities.

`RuntimeSession::resolve_asset(url)` is the pure custom-protocol boundary for
native WebViews. It resolves `lepusa://runtime/bridge.js`, inline/Rabbita
virtual files, and safe local asset paths without doing platform file IO.

`RuntimeHost::dispatch_json(input)` is the native hook boundary for WebView IPC.
It decodes the bridge request object, checks capabilities through the command
registry, and returns the JSON response shape expected by `window.lepusa`.

The generated bridge also exposes `window.lepusa.listen(name, handler)` and
installs `globalThis.__lepusaDispatchEvent(event)` for native-to-frontend
events.

`RuntimePlan::actions(cmd)` lowers `Cmd::emit`, `Cmd::navigate`, and
`Cmd::effect` into backend-executable `RuntimeAction` values. Startup actions
are included in `RuntimePlan::launch_manifest()`.

`RuntimeHost::webviews()` produces per-window boot specs for native backends:
window frame data, load URL, asset protocol, native hook name, and document
start scripts.

`@lepusa/runtime/macos` is the first platform backend package. It validates the
native WebKit runtime is present and lowers a `RuntimeHost` into a macOS launch
plan backed by `WKWebView` boot specs.

`lepusa bridge` emits the JavaScript bridge that frontends load as
`window.lepusa`, including `invoke(route, payload)` and route namespaces such as
`lepusa.core.invoke(payload)`.

`lepusa dev` lowers the current project into a runtime development plan:
resolved WebViews, asset protocol, capability-filtered routes, runtime session,
and startup operations. This is the stable boundary the platform-specific
window loops will execute.

`lepusa bundle-plan` now also validates concrete bundle artifact plans through
`BundlePlan::files()`: platform metadata plus `lepusa/runtime.json`, with
per-window bridge initialization scripts embedded in the runtime manifest.

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

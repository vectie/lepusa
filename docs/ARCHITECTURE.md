# Lepusa Architecture

## Goal

Make native desktop app creation easy for MoonBit projects on macOS, Windows,
and Linux without each application writing its own native launcher, WebView
bridge, IPC, permission model, plugin system, and bundler.

Lepusa is a foundation project. It must stay app-neutral.

## Layers

```text
consumer apps
  product code, domain state, backend routes, frontend views

lepusa
  stable MoonBit facade and CLI

lepusa/ui
  Rabbita-compatible app/cell helpers for MoonBit-authored desktop UI

lepusa/runtime
  WebView windows, event loop, custom protocols, asset loading, IPC transport

lepusa/plugins/*
  dialog, opener, fs, file-dialog, process, shell, clipboard, notification,
  log, store, localhost, single-instance, deep-link, tray, auto-launch,
  window-state, updater, service-discovery

shared native utility packages
  filesystem, paths, process, OS, time, UUID, C helpers
```

## Authoring Model

Lepusa should mirror Rabbita's application style for MoonBit UI:

```moonbit nocheck
let (dispatch, cell) = @lepusa.cell_with_dispatch(
  model=init_model(),
  update~,
  view=(dispatch, model) => render_app(dispatch, model),
)
let app = @lepusa.new(cell)
  .with_startup(load_initial_state(dispatch))
  .window(
    title="Example",
    width=1000,
    height=720,
    source=@lepusa.Source::local_path("dist"),
  )
let plan = app.launch_plan()
```

Equivalent lower-level hosting should remain available:

```moonbit nocheck
@lepusa.WindowConfig::new(
  title="Example",
  source=@lepusa.Source::local_path("dist"),
)
```

This gives MoonBit UI authors the familiar model/update/view flow while still
supporting arbitrary built frontend assets.

## Process Model

Lepusa should follow a Tauri-style split:

- Core process: MoonBit native executable with OS authority.
- WebView process: system WebView rendering frontend assets.
- IPC: all privileged work crosses a typed command/event bridge.
- Permissions: a window only gets the commands listed in its capabilities.

The implementation is MoonBit-native. Tauri is a reference design, not a
runtime dependency.

## Public API Ownership

The stable facade owns public types. Early implementation can reuse ideas or
code from existing experiments, but users should import `@lepusa` and
`@lepusa/*` packages.

Initial public surface:

```moonbit nocheck
pub type App
pub type Window
pub type WindowConfig
pub type Source
pub type Plugin
pub type Capability
pub type Cmd
pub type Event
pub type InvokeRequest
pub type InvokeResponse
pub type RuntimeConfig
pub type RuntimePlan
pub type BundleConfig
pub type BundlePlan
pub type ProjectManifest
pub type Html
pub type Dispatch

pub fn cell_with_dispatch(...) -> (Dispatch[Msg], Cell)
pub fn new(root : Cell) -> App
pub fn App::with_startup(self : App, cmd : Cmd) -> App
pub fn App::window(self : App, ...) -> App
pub fn App::launch_plan(self : App) -> Result[LaunchPlan, Array[String]]
pub fn App::runtime_plan(self : App, config? : RuntimeConfig) -> Result[
  RuntimePlan,
  Array[String],
]

pub fn Source::html(html : String) -> Source
pub fn Source::local_path(path : String) -> Source
pub fn Source::url(url : String) -> Source
```

## IPC

Command handlers should be typed MoonBit functions:

```moonbit nocheck
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("dialog", plugin => {
    plugin.command_sync("show", (payload : DialogRequest) => {
      show_dialog(payload)
    })
  })
}
```

Frontend bindings should be generated or exposed consistently:

```javascript
await window.lepusa.invoke("dialog.show", { message: "Hello" })
await window.lepusa.dialog.show({ message: "Hello" })
```

Command rules:

- JSON schema generated from MoonBit `ToJson`/`FromJson` types where possible.
- Every command belongs to a plugin namespace.
- Every command declares whether it is sync, async, streaming, or event-only.
- Every command is denied by default unless a capability grants it.

## Capabilities

Use a small manifest format before inventing a large policy engine:

```json
{
  "identifier": "main-window",
  "windows": ["main"],
  "permissions": [
    "dialog:show",
    "opener:open",
    "fs:read:workspace"
  ]
}
```

Permissions should be checked in the core process, not only in frontend
bindings. File access should prefer scoped roots and persisted scopes over broad
filesystem access.

## Sources And Assets

Support first-class source modes:

- `Source::html`: embedded memory source for examples and tests.
- `Source::local_path`: local static directory or entry HTML.
- `Source::url`: development server or app-owned local server.
- `Source::rabbita`: MoonBit-authored UI mounted into a generated shell.

Production builds should prefer packaged assets served through a custom
protocol. Loopback localhost should be available for apps that truly own a
local service.

## Local Services

Some apps are gateway-first instead of static-asset-first. Lepusa should
support that shape without absorbing the product service:

```text
Lepusa window
  -> loads http://127.0.0.1:<bound-port>/ or packaged fallback assets
  -> grants runtime plugins through capabilities
  -> supervises optional sidecar/local service startup
  -> records discoverable service status

App service
  -> owns routes, state, auth, persistence, and product contracts
```

Framework support needed for this mode:

- localhost source with readiness probe and retry screen
- optional sidecar process lifecycle
- tray and restart actions
- deep-link registration and dispatch
- external open, clipboard, file dialogs, auto-launch, and updater plugins
- service discovery/status files

## Bundling

Lepusa's bundler should own platform templates:

- macOS: `.app`, Info.plist, icon, optional DMG, signing/notarization hooks.
- Windows: executable metadata, icon, WebView2 handling, installer path.
- Linux: executable, desktop file, icons, AppImage/deb/rpm-oriented manifests.

Consumer apps should provide metadata, assets, capabilities, sidecars, and
signing configuration. They should not need to maintain native launcher code.

## CLI Boundary

The CLI should be thin over public framework contracts. Early commands should
exercise planning without reaching into private structs:

```text
lepusa doctor
  -> validates app/runtime planning

lepusa plan
  -> prints runtime backend, windows, plugins, capabilities, command routes

lepusa bundle-plan <target>
  -> prints platform bundle name, executable name, and app identifier
```

Native run/build/bundle commands should consume the same `RuntimePlan` and
`BundlePlan` objects rather than maintaining parallel configuration paths.

## Manifest Boundary

`ProjectManifest` owns reusable app-neutral configuration:

- app metadata
- windows and sources
- plugins and command routes
- capabilities
- startup command
- runtime config

It intentionally does not own product routes, schemas, persistent state, or
frontend component code. It lowers into `App`, `LaunchPlan`, `RuntimePlan`, and
`BundlePlan`.

## Non-Goals

- Do not require Rust/Tauri glue in each MoonBit app.
- Do not depend on Tauri as the normal runtime.
- Do not be a compatibility-only wrapper over an existing experiment.
- Do not move app domain logic, backend routes, schemas, or product adapters
  into Lepusa.
- Do not make Rabbita mandatory for non-MoonBit frontend assets.
- Do not expose broad filesystem or shell access by default.

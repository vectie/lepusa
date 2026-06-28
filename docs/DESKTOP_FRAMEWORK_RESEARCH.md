# Desktop Framework Research

## Decision

Build Lepusa as a standalone MoonBit desktop framework: a native MoonBit
implementation of the proven Tauri-shaped architecture, with a Rabbita-like
authoring style for MoonBit UI apps.

Lepusa should not be a thin compatibility layer over Tauri, and it should not
be a thin wrapper over the current Lepus package. Tauri and Lepus are reference
implementations to study, harvest ideas from, and replace with a cohesive
MoonBit-owned codebase.

## Confirmed UI Direction

The existing substantial MoonBit UI surfaces in the local sibling projects are
Rabbita-based. The repeated pattern is:

```moonbit nocheck
let (emit, cell) = @rabbita.cell_with_emit(
  model=init_model(),
  update~,
  view=(emit, model) => render_app(emit, model),
)
let app = @rabbita.new(cell)
app.with_init(load_initial_state(emit))
app.mount("app")
```

Lepusa should feel familiar to that style:

```moonbit nocheck
let (emit, cell) = @lepusa.cell_with_emit(
  model=init_model(),
  update~,
  view=(emit, model) => render_app(emit, model),
)
let app = @lepusa.new(cell)
app.with_startup(load_initial_state(emit))
app.window(
  title="Example",
  width=1000,
  height=720,
  source=@lepusa.Source::local_path("dist"),
)
app.launch_plan()
```

The goal is similar syntax and mental model, not forcing all apps to use
Rabbita. Plain HTML/CSS/JS, generated static assets, and other frontend systems
should remain supported.

## Tauri Lessons To Port

Tauri is the right architectural reference:

- system WebViews instead of bundling a browser engine
- a privileged native core process separated from frontend WebViews
- explicit frontend-to-core command IPC
- backend-to-frontend events and streaming channels
- capability/permission manifests
- official plugins for platform features
- production bundling, signing, updater, and installer workflows

The implementation should be MoonBit-native:

- no required Rust command handlers
- no required `src-tauri`
- no required Cargo project in app repositories
- no Tauri runtime dependency in the normal app build path

## Lepus Lessons To Port

The current Lepus project already sketches much of the desired shape:

- `App`, `Window`, `WindowConfig`, and `Source`
- memory, local file, and URL sources
- a plugin model with typed command handlers
- examples for common desktop features
- CLI commands for init, dev, build, setup, and doctor
- native linker helper logic for macOS, Linux, and Windows WebView stacks

Lepusa should use this as seed material, but the foundation should live in this
project:

- public package names should be `lepusa/*`
- public types should be owned by Lepusa packages
- command/capability/plugin APIs should be stabilized here
- platform bundling should become a Lepusa responsibility

## Framework Boundary

Lepusa should stay product-agnostic.

It owns:

- desktop application lifecycle
- windows and WebViews
- source loading and asset protocols
- typed IPC
- capability checks
- platform plugins
- app metadata
- dev/build/bundle/release tooling

It does not own:

- any app's domain model
- any app's backend service routes
- any app's workspace schema
- any app's dashboard layout
- any app's product-specific adapters

Consumer projects should use Lepusa as infrastructure, not shape Lepusa's core
around their product workflows.

## Recommendation

The right foundation is:

```text
MoonBit app
  -> Rabbita-like Lepusa app syntax
  -> typed desktop commands/events
  -> capability-scoped plugins
  -> MoonBit-native WebView runtime
  -> platform bundler
```

The first implementation should own the app-neutral API, validation, typed
commands/events, IPC route model, capabilities, plugins, and launch plan. The
next slice should make a native runtime consume that launch plan.

## Sources

- Local sibling UI scan: Rabbita-based `ui/rabbita-*` packages and vendored
  Rabbita APIs.
- Local Lepus scan: app/window/source/plugin/CLI/native-linker code.
- Local custom desktop-shell scan: app bundling, WebView hosting, and localhost
  serving patterns.
- Tauri docs: <https://v2.tauri.app/concept/process-model/>
- Tauri docs: <https://v2.tauri.app/develop/calling-rust/>
- Tauri docs: <https://v2.tauri.app/security/capabilities/>
- Tauri docs: <https://v2.tauri.app/plugin/>
- Tauri docs: <https://v2.tauri.app/distribute/>

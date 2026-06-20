# Lepusa Roadmap

## Milestone 0: Standalone Foundation

- Publish `lepusa` as the public framework name.
- Own public concrete API types in `lepusa` or non-internal `lepusa/*`
  packages.
- Own `LaunchPlan`, `RuntimePlan`, and `BundlePlan` as the first native backend
  boundaries.
- Own `ProjectManifest` as the app-neutral configuration boundary.
- Import useful runtime ideas from existing experiments without making Lepusa a
  wrapper layer over them.
- Keep product-specific requirements out of core packages.

## Milestone 1: Rabbita-Style Desktop App

- Add `cell_with_dispatch`, `new`, `with_startup`, `window`, validation, and
  `launch_plan` APIs with syntax close to Rabbita.
- Add `@lepusa/ui` HTML node and attribute helpers plus `UiProgram`
  model/update/view state flow for compact MoonBit-authored desktop views.
- Add `@lepusa/desktop.DesktopKit` as the official desktop API kit that keeps
  plugin declarations, capability grants, catalog registries, and runtime hosts
  aligned for app authors, and add `DesktopProject` as the concise app-level
  boundary for deriving runtime hosts and bundle plans from the same desktop
  configuration.
- Lower source-less `App` windows into generated Rabbita-style HTML from the
  root `Cell`.
- Add native `run` once the first runtime backend is wired: macOS now has an
  explicit `lepusa run macos --launch` path.
- Run a desktop counter app authored in MoonBit model/update/view style:
  `UiProgram` now provides the framework boundary; the remaining proof is a
  native-window smoke test around a packaged counter.
- Support direct `WindowConfig::new(..., source=...)` hosting for non-Rabbita
  assets.
- Add a smoke test that proves the WebView is nonblank: `lepusa verify` now
  checks resolvable initial WebView assets for nonblank content; a real
  native-window screenshot smoke remains future platform validation.

## Milestone 2: Native Runtime

- Add `@lepusa/runtime` host/session boundary over `RuntimePlan`.
- Add pure custom-protocol asset resolution for bridge, inline, Rabbita, and
  local assets: typed and JSON protocol-handler envelopes exist
- Add the native hook JSON codec from generated bridge requests to capability
  checked `CommandRegistry` dispatch.
- Add async command registry dispatch for native plugin handlers.
- Add per-window WebView boot specs for platform backends.
- Add a portable runtime launch manifest for WebViews, bridge hooks, protocol
  mappings, command routes, and capability grants.
- Lower `Cmd` startup trees into backend-executable runtime actions.
- Add runtime lifecycle hooks for startup, shutdown, and window close events:
  initial generic and native runner lowering exists, and source plus packaged
  prepared run plans now embed startup frontend event scripts into the matching
  WebView initialization script.
- Add shared `@lepusa/runtime` native backend lowering over portable runtime
  operations.
- Add `RuntimeServicePlan` as the service-specific runtime handoff for
  localhost sidecars, start order, validation, supervisor requirements, and a
  shared start/readiness/shutdown supervisor handoff with native execution
  reports, backend executor hooks, and macOS/Linux/Windows native
  process/readiness execution. Open-window launch paths now execute service
  startup before WebView creation and service shutdown after the window loop.
- Add `NativeRuntime` as the single platform-loop facade for backend bootstrap,
  protocol asset resolution, bridge dispatch, service supervisor
  plans/reports/executors, and lifecycle steps.
- Add a portable bridge dispatch envelope for source and bundled runtimes:
  response JSON plus the WebView callback script now flow through reusable
  runtime APIs and no-window CLI probes.
- Add a portable bridge handoff envelope for source and bundled runtimes:
  sync routes carry an immediate callback script, while async routes return a
  deferred task that platform event loops can schedule without re-decoding.
- Add `@lepusa/runtime/bundled` for packaged `lepusa/runtime.json` parsing,
  asset lookup, lifecycle action selection, and bundled service plans.
- Add `@lepusa/runtime/macos`, `@lepusa/runtime/windows`, and
  `@lepusa/runtime/linux` backend descriptor packages with host availability
  checks for WKWebView, WebView2, and WebKitGTK.
- Add `lepusa verify --strict` as the release gate over the no-write verifier:
  missing concrete handlers and known target launch blockers fail CI, while the
  default verifier stays useful for framework contract proofing.
- Implement or port WebView window creation for macOS, Windows, and Linux:
  first macOS WKWebView launch path and document-start bridge injection exist;
  packaged macOS `lepusa-runtime launch` consumes `lepusa/runtime.json`;
  MoonBit-side macOS bridge message dispatch exists; Objective-C
  WKScriptMessageHandler wiring for sync command responses exists; macOS
  WKURLSchemeHandler wiring for Lepusa assets exists; macOS run plans now
  expose sync versus async bridge route metadata; runtime-owned bridge message
  preparation separates native capture from sync/async dispatch and shares hook
  bootstrap plus callback script generation across macOS, Linux, and Windows;
  source and bundled runtime bridge tasks now expose route-level sync/async
  scheduling metadata for backend event loops;
  bundled runtime bridge transport now preserves packaged plugin registry state
  across repeated bridge calls; open-window macOS launches now report
  unsupported when async routes require native scheduling; Linux now has a
  first WebKitGTK source-window loop
  for resolved HTML/file/remote URLs plus sync WebKitGTK script-message bridge
  dispatch and package-owned URI scheme asset resolution for packaged manifests;
  Windows now prepares typed WebView2 boot plans, bridge bootstrap scripts, and
  the final native launch ABI for source and packaged manifests, with that ABI
  reporting unsupported until the COM creation loop lands; source and bundled
  launch-session JSON can now advertise async-capable bridge scheduling for
  native loops that wire deferred completion, including the reusable async
  bridge executor descriptor over
  `NativeRuntime::bridge_async_dispatch_callback`; source and bundled bridge
  handoffs now expose typed deferred completion envelopes plus FIFO work queues;
  queue-backed handoff callbacks now give native message handlers a sync entry
  point that captures async work for later drain; source and bundled bridge
  loop adapters now package the runtime, queue, callback, pending diagnostics,
  and drain operation for platform event loops, with async message-turn results
  that normalize immediate scripts and drained completions; launch-session JSON
  now advertises that adapter/delivery/drain boundary as a `bridgeLoop`
  contract; native launch packets now carry the target window label, and source
  plus bundled bridge-loop callback bundles bind queue-backed handoff, async
  drain delivery, and executable drain-script payloads to that launched window
  for platform runners;
  WebView launch contexts now carry the byte packet plus scheduler, executor,
  and bridge-loop contracts into platform runner code; platform packages now
  declare `NativeLaunchCapability` for WebView creation and async bridge
  drain/evaluate support, and open-window runners pass the queue-backed handoff
  callback into native message handlers only after that gate passes;
  `NativeOperationExecutor` now gives platform loops one typed execution report
  boundary for startup, lifecycle, and bridge-drain operations, and canonical
  `RunReport` values expose those execution counts for source and packaged
  native plans; native async bridge drain/evaluate scheduling in the C/WebView
  loops and the Windows WebView creation loop remain.
- Support `Source::html`, `Source::local_path`, `Source::packaged`,
  `Source::url`, and `Source::localhost` source modes.
- Validate native link behavior on each supported platform.

## Milestone 3: Typed IPC And Capabilities

- Stabilize `Plugin::command`, `command_sync`, async command behavior, and
  backend-to-frontend events.
- Stabilize the app-facing official plugin kit so desktop APIs can be enabled
  without hand-syncing manifest routes, capabilities, and native handlers.
- Add capability manifests and runtime permission checks: launch and bundled
  runtime manifests now carry capability grants, and dispatch already enforces
  those permissions.
- Generate a small JavaScript bridge under `window.lepusa`.
- Keep denied-command, malformed-payload, and plugin namespace collision tests
  in the IPC boundary suite as the bridge grows.

## Milestone 4: CLI

- Implement:
  - `lepusa doctor [--json]`: validates public planning boundaries and reports
    target native launch gate, signing prerequisites, and backend preflight
    diagnostics, with one machine-readable health report for tooling.
  - `lepusa plan`: prints a runtime plan summary.
  - `lepusa manifest`: prints the native-runner launch manifest JSON.
  - `lepusa native-plan`: prints backend bootstrap JSON for platform runners.
  - `lepusa run [--json]`: prints a no-window native runner smoke summary with target launch readiness and the canonical `RunReport` for tooling.
  - `lepusa bridge`: prints the generated frontend IPC bridge.
  - `lepusa asset`: prints the runtime asset protocol JSON envelope.
  - `lepusa lifecycle`: prints runtime lifecycle step JSON.
  - `lepusa bridge-task`: reports source bridge task scheduling metadata.
  - `lepusa bridge-handoff`: reports source immediate/deferred native bridge handoff.
  - `lepusa bridge-complete`: executes source deferred bridge completion and reports the native completion envelope.
  - `lepusa bridge-dispatch`: executes source bridge messages and reports the native callback envelope.
  - `lepusa bridge-loop`: feeds one source bridge message through the adapter loop and reports the window delivery envelope with immediate scripts, async completions, evaluation scripts, and executable evaluation operations. Runtime adapters also expose `drain_window` for async work captured by native message-handler callbacks.
  - `lepusa bridge-drain`: probes the source split native path by running the handoff callback before draining pending async bridge work into a window delivery envelope.
  - `lepusa launch-session [--async-bridge]`: emits a target-aware source launch readiness envelope with session JSON, backend preflight, launch capability, requested versus effective bridge mode, and optional async-capable bridge scheduler metadata.
  - `lepusa verify [macos|windows|linux] [--json]`: runs the no-write project proof across runtime plan, dev plan, manifest assets, handler coverage, native launch session, and bundle contracts, with machine-readable output for CI.
  - `lepusa bundle-plan [--json]`: prints a target bundle plan, with a machine-readable artifact/resource/signing/file report for tooling.
  - `lepusa bundle-inspect [--json]`: parses packaged `lepusa/distribution.json` and reports installer-facing artifact, resource, dependency, runtime executable, and signing metadata.
  - `lepusa bundle-release-plan [--json]`: lowers packaged distribution metadata into ordered release steps for dependency validation, resource staging, signing, and artifact collection.
  - `lepusa bundle-write`: writes planned platform bundle files.
  - `lepusa init`: writes a standalone MoonBit project skeleton, with `--workspace <lepusa-root>` for local pre-publish development against a checkout.
  - `lepusa build`: alias for materializing the current bundle plan.
  - `lepusa bundle`: alias for materializing the current bundle plan.
  - `lepusa plugin new`: writes a standalone plugin package skeleton, with `--workspace <lepusa-root>` for local pre-publish development against a checkout.
  - `lepusa dev [--json]`: lowers the project to a runtime development plan, with JSON output for native runners and tooling.
  - `lepusa-runtime --manifest`: summarizes bundled runtime data for diagnostics.
  - `lepusa-runtime run`: prepares target-aware bundled runtime launch plans and reports launch readiness without opening windows.
  - `lepusa-runtime launch`: opens the first bundled macOS WKWebView from `lepusa/runtime.json`, opens bundled Linux WebKitGTK windows when GTK3/WebKit2GTK are available, and sends Windows bundled manifests through the package-owned WebView2 launch ABI until its COM loop lands.
  - `lepusa-runtime bootstrap`: emits target-aware bundled bootstrap JSON for native loops.
  - `lepusa-runtime asset`: resolves bundled runtime assets for protocol handlers.
  - `lepusa-runtime lifecycle`: selects bundled lifecycle services and actions.
  - `lepusa-runtime bridge-task`: reports packaged bridge task scheduling metadata.
  - `lepusa-runtime bridge-handoff`: reports packaged immediate/deferred native bridge handoff.
  - `lepusa-runtime bridge-complete`: executes packaged deferred bridge completion and reports the native completion envelope.
  - `lepusa-runtime bridge-dispatch`: executes packaged bridge messages and reports the native callback envelope.
  - `lepusa-runtime bridge-loop`: feeds one packaged bridge message through the adapter loop and reports the window delivery envelope with immediate scripts, async completions, evaluation scripts, and executable evaluation operations. Bundled runtime adapters also expose `drain_window` for async work captured by native message-handler callbacks.
  - `lepusa-runtime bridge-drain`: probes the packaged split native path by running the handoff callback before draining pending async bridge work into a window delivery envelope.
  - `lepusa-runtime launch-session [--async-bridge]`: emits a packaged native-loop launch readiness envelope with session JSON, backend preflight, launch capability, requested versus effective bridge mode, and optional async-capable bridge scheduler metadata.
  - `lepusa-runtime invoke`: dispatches packaged bridge calls through registered official native handlers.
- Consume standalone `lepusa.json` project manifests for planning, manifest
  generation, and bundle materialization.
- Extract `@lepusa/project` as the reusable parser for standalone
  `lepusa.json` manifests, keeping CLI file loading separate from project
  semantics.
- Extract `@lepusa/bundle` as the reusable native bundle writer over
  `BundlePlan`, keeping filesystem materialization separate from CLI commands.
- Extract `@lepusa/scaffold` as reusable app/plugin skeleton generation,
  keeping ecosystem project creation separate from CLI commands: reusable app
  and plugin writers now support both publish-ready registry dependencies and
  local `moon.work` manifests for pre-publish development, and app scaffolds
  now start from the routable `UiProgram` plus `DesktopProject` source-app
  pattern.
- Lower `lepusa.json` startup and lifecycle command trees into runtime actions.
- Support MoonBit-authored UI apps and prebuilt frontend assets.
- Make `doctor` report platform WebView dependencies, target launch gate, and
  signing prerequisites.

## Milestone 5: Official Plugins

Stabilize the cross-platform core set first:

- dialog: initial platform-neutral command contract and portable async handlers
  exist
- opener: platform-neutral command contract plus native open/reveal handlers
  exist for macOS, Linux, and Windows
- fs: scoped permission contract, runtime scope manifest, and async scoped
  text/bytes/list/metadata/delete/exists/create-directory handlers exist
- fileDialog: initial scoped default-directory contract and delegated picker
  handlers exist
- shell: initial platform-neutral command contract and delegated process-table
  handlers exist
- process: initial explicit process permission contract exists
- clipboard: platform-neutral command contract, native system clipboard stubs,
  and in-process sync text handlers for deterministic tests exist
- notification: platform-neutral command contract, macOS/Linux native delivery,
  and in-process sync permission/show handlers for deterministic tests exist
- log: initial pure command-registry package exists
- store: initial pure command-registry package exists
- localhost: initial local service lifecycle contract and portable metadata
  handlers exist
- deepLink: initial app URL scheme contract and portable sync URL state handlers
  exist
- singleInstance: initial app lock/launch handoff contract and portable
  sync primary-state handlers exist
- tray: initial status icon/menu contract and delegated sync tray state handlers
  exist
- autoLaunch: launch-at-login contract, portable enablement state handlers, and
  native macOS/Linux/Windows registration handlers exist
- windowState: initial window geometry persistence contract, sync runtime state
  handlers, and durable file-backed storage exist
- updater: initial update lifecycle contract and delegated lifecycle handlers
  exist
- serviceDiscovery: initial service lookup/status contract and portable
  metadata handlers exist

Plugins with mobile-only or platform-specific behavior can follow after the
desktop core is reliable.

## Milestone 6: Bundling

- macOS `.app` and DMG artifact paths are represented in `BundlePlan`.
- Windows command launcher and installer artifact paths are represented in
  `BundlePlan`; a native `.exe` wrapper remains future packaging work.
- Linux desktop integration and portable bundle artifact paths are represented
  in `BundlePlan`.
- `BundlePlan::files()` emits platform metadata, launcher stubs, one runtime
  manifest with per-window bridge initialization scripts, and one distribution
  manifest for installer-facing artifact, dependency, resource, and signing
  metadata.
- `BundlePlan::resources()` emits target resource mappings for app icons and
  packaged asset directories.
- `BundlePlan::runtime_dependencies()` emits target WebView/runtime loader
  requirements, including Windows WebView2 Runtime plus `WebView2Loader.dll`
  placement beside the packaged Lepusa runtime; file-backed dependencies can
  declare source paths that `bundle-write` copies before verification, and
  standalone `lepusa.json` projects can override those sources through
  `runtimeDependencies`.
- `BundlePlan::signing_prerequisites()` emits target signing, notarization, and
  package validation requirements.
- App metadata manifest: id, product name, version, icons, capabilities,
  assets, sidecars, typed signing options, and target-aware signing steps now
  flow into bundle manifests.
- `@lepusa/bundle` verifies materialized bundle files, resources, runtime
  manifests, runtime dependencies, nonblank initial WebView content,
  host-compatible runtime executable copies, and target launch capability after
  `bundle-write` as the pre-install smoke boundary, with `bundle-write --json`
  exposing the same checks as a machine-readable CI report.
- Clean-machine install tests per platform.

## Milestone 7: Foundation Proof

- Build at least three example apps:
  - MoonBit-authored Rabbita-style UI app exists under `examples/rabbita`.
  - Static asset app from a local `dist/` directory exists under
    `examples/static`.
  - Localhost gateway app with sidecar/service readiness exists under
    `examples/gateway`.
- Verify each example can run in dev mode and bundle mode: CLI smoke tests
  cover dev, verify, and bundle mode for the foundation examples.
- Document how third-party MoonBit projects create, bundle, sign, and publish
  desktop apps.

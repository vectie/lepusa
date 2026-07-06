# Lepusa Documentation Guide

Lepusa is the MoonBit-owned desktop application framework for MoonSuite. It
lowers typed app configuration, command bridges, capabilities, plugins, and
packaging plans into native WebView runtimes without making each product own
platform-specific desktop code.

## Scope And Boundary

Lepusa owns:

- app, window, command, event, capability, plugin, and project-manifest
  contracts
- native runtime planning and session snapshots
- localhost service supervision for desktop apps
- system WebView bridge contracts
- bundle and release planning for macOS, Windows, and Linux targets
- official platform plugin contracts

Consumer products own product behavior, domain routes, schemas, state, service
APIs, and user-facing workflows. Lepusa should not know what Moondesk,
MoonStat, MoonRobo, or any other product means; it should know how to host and
package them.

## Reading Order

1. [DESKTOP_FRAMEWORK_RESEARCH.md](DESKTOP_FRAMEWORK_RESEARCH.md): framework
   decision and why MoonBit owns the layer.
2. [ARCHITECTURE.md](ARCHITECTURE.md): runtime, command bridge, manifest,
   service, bundle, and CLI boundaries.
3. [ROADMAP.md](ROADMAP.md): implemented slices and remaining platform work.
4. [README.mbt.md](../README.mbt.md): current public API examples and CLI
   commands.

## Implementation Map

- root package: app authoring primitives, command/event contracts, launch plans.
- `ui/`: optional view helpers for compact MoonBit-authored desktop views.
- `project/`: `lepusa.json` parsing and manifest lowering.
- `desktop/`: official app-facing plugin kit.
- `plugins/*`: platform capability contracts.
- runtime packages: backend-neutral launch/session/native-operation contracts.
- bundle packages: target-aware bundle files, resources, signing prerequisites,
  and distribution manifests.
- `cmd/main`: CLI for doctor, plan, manifest, run, verify, init, dev, and
  bundle-related operations.

## Testing Guidance

Use package-level tests for pure contracts and native smoke tests for runtime
boundaries.

```sh
moon check
moon test
moon test --target native
```

For product-facing changes, run at least one manifest plan, one runtime/session
command, and one bundle/write path against the examples. Native UI changes need
macOS and Linux smoke coverage when both backends are affected.

## Worth Noticing

- `RuntimePlan`, `RuntimeSession`, `NativeRunnerPlan`, and `BundlePlan` are
  product-neutral contracts. Do not duplicate their decisions in CLI glue.
- Capability checks should happen before bridge execution, not only in UI code.
- Packaged assets should be served through the Lepusa asset protocol rather
  than raw filesystem paths.
- Product desktop manifests should depend on published Lepusa interfaces, not
  local sibling worktrees.

## Future Plan

- Keep shrinking platform-specific stubs so MoonBit owns the runtime contract.
- Add stronger clean-machine bundle/install smoke coverage.
- Make official plugin docs and examples consistent across filesystem,
  localhost, opener, tray, notification, service discovery, and window APIs.
- Keep Windows and Linux packaging on the same typed plan shape as macOS.

# Lepusa Examples

These examples exercise the three foundation app shapes Lepusa should support:

- `rabbita`: MoonBit-authored UI lowered from `rootHtml` into the default root cell.
- `static`: prebuilt frontend assets served through `Source::packaged`.
- `gateway`: localhost WebView source with sidecar command and readiness metadata.

```bash
moon run cmd/main --target native -- dev --project examples/rabbita/lepusa.json
moon run cmd/main --target native -- bundle-write linux _build/examples/static --project examples/static/lepusa.json
moon run cmd/main --target native -- bundle-write linux _build/examples/gateway --project examples/gateway/lepusa.json
```
